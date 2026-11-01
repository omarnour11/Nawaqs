using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Common.Models;
using Nawakes.Domain.Common;

namespace Nawakes.Infrastructure.NLP;

/// <summary>
/// Dedicated Clinical Prescription Resolution Service.
/// Encapsulates all doctor handwriting error-correction, Egyptian phonetic mapping,
/// consonant skeleton compression, and the official EDA Dosage Feasibility Gate.
///
/// Performance:
/// - The EDA catalog (37,000 records) and brand strength map are loaded from SQL Server
///   exactly ONCE per process lifetime (or after a 4-hour sliding window) and held in
///   IMemoryCache. All subsequent search requests pay zero database I/O for catalog access.
/// - Uses IServiceScopeFactory to safely resolve a scoped IApplicationDbContext from within
///   this Singleton service (the standard ASP.NET Core pattern for singleton ↔ scoped access).
/// </summary>
public sealed class ClinicalPrescriptionMatcher : IClinicalPrescriptionMatcher
{
    private const string CatalogCacheKey = "clinical:catalog:v1";
    private static readonly TimeSpan CatalogCacheTtl = TimeSpan.FromHours(4);

    private readonly IServiceScopeFactory? _scopeFactory;
    private readonly IApplicationDbContext? _directContext;
    private readonly IEgyptianDialectNormalizer _dialectNormalizer;
    private readonly IMemoryCache _memoryCache;
    private readonly ILogger<ClinicalPrescriptionMatcher> _logger;
    private readonly ClinicalMatchingOptions _options;

    [ActivatorUtilitiesConstructor]
    public ClinicalPrescriptionMatcher(
        IServiceScopeFactory scopeFactory,
        IEgyptianDialectNormalizer dialectNormalizer,
        IMemoryCache memoryCache,
        ILogger<ClinicalPrescriptionMatcher> logger,
        ClinicalMatchingOptions? options = null)
    {
        _scopeFactory = scopeFactory;
        _dialectNormalizer = dialectNormalizer;
        _memoryCache = memoryCache;
        _logger = logger;
        _options = options ?? new ClinicalMatchingOptions();
    }

    /// <summary>
    /// Direct-context constructor (primarily for unit tests and local execution).
    /// </summary>
    public ClinicalPrescriptionMatcher(
        IApplicationDbContext context,
        IEgyptianDialectNormalizer dialectNormalizer,
        IMemoryCache? memoryCache = null,
        ClinicalMatchingOptions? options = null)
    {
        _directContext = context;
        _scopeFactory = null;
        _dialectNormalizer = dialectNormalizer;
        _memoryCache = memoryCache ?? new MemoryCache(new MemoryCacheOptions());
        _logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<ClinicalPrescriptionMatcher>.Instance;
        _options = options ?? new ClinicalMatchingOptions();
    }

    /// <inheritdoc />
    public async Task<ClinicalMatchResolution> MatchPrescriptionAsync(
        string rawText,
        string? targetStrength = null,
        string? targetDosageForm = null,
        CancellationToken cancellationToken = default)
    {
        var raw = rawText?.Trim() ?? string.Empty;
        if (raw.Length == 0)
        {
            return new ClinicalMatchResolution(string.Empty, null, null, 0m, true, []);
        }

        // 1. Isolate strength and dosage form before stripping prescription noise
        var extractedStrength = targetStrength ?? DrugNameNormalizer.ExtractStrength(raw);
        var extractedForm = targetDosageForm ?? DrugNameNormalizer.ExtractDosageForm(raw);

        // 2. Clean doctor prescription noise (R/, 1-, bid, 1x1, Arabic frequencies)
        var cleaned = DrugNameNormalizer.CleanPrescriptionLine(raw);

        // ── Arabic-First Catalog Lookup Invariant ──────────────────────────
        // When handling Arabic characters, search CommercialNameArNormalized in the 37k official EDA catalog FIRST
        // before calling dialect normalizer or phonetic transforms.
        var cached = await GetOrLoadCatalogAsync(cancellationToken);
        if (ContainsArabic(cleaned) || ContainsArabic(raw))
        {
            var arabicCandidates = MatchArabicCatalog(cleaned, raw, extractedStrength, extractedForm, cached);
            if (arabicCandidates.Count > 0 && arabicCandidates[0].Confidence >= 0.90m)
            {
                var bestArabic = arabicCandidates[0];
                var requiresDisambigArabic = arabicCandidates.Count > 1 && bestArabic.Confidence < _options.ConfidentThreshold;
                return new ClinicalMatchResolution(
                    bestArabic.TradeName,
                    bestArabic.Strength ?? extractedStrength,
                    bestArabic.DosageForm ?? extractedForm,
                    bestArabic.Confidence,
                    requiresDisambigArabic,
                    arabicCandidates,
                    bestArabic.ActiveIngredient);
            }
        }

        // 3. Evaluate colloquial Egyptian dialect rule table (e.g. كونكور -> Concor)
        var normalized = await _dialectNormalizer.NormalizeAsync(cleaned, cancellationToken);
        var effectiveTrade = normalized?.TradeName ?? cleaned;
        var effectiveStrength = extractedStrength ?? normalized?.Strength;
        var effectiveForm = extractedForm ?? normalized?.DosageForm;

        // 4. Generate candidate medications through the multi-tier fuzzy & feasibility engine
        var candidates = GenerateCandidatesInternal(
            effectiveTrade, effectiveStrength, effectiveForm, cached);

        if (candidates.Count == 0 && cleaned != raw)
        {
            // Fallback: try raw uncleaned string in case cleaning stripped an essential token
            candidates = GenerateCandidatesInternal(
                raw, effectiveStrength, effectiveForm, cached);
        }

        if (candidates.Count == 0)
        {
            return new ClinicalMatchResolution(string.Empty, null, null, 0m, true, []);
        }

        var best = candidates[0];
        var requiresDisambiguation = candidates.Count > 1 && best.Confidence < _options.ConfidentThreshold;

        return new ClinicalMatchResolution(
            best.TradeName,
            best.Strength ?? effectiveStrength,
            best.DosageForm ?? effectiveForm,
            best.Confidence,
            requiresDisambiguation,
            candidates,
            best.ActiveIngredient);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<ClinicalCandidateDto>> GenerateCandidatesAsync(
        string query,
        string? targetStrength,
        string? targetDosageForm,
        CancellationToken cancellationToken = default)
    {
        var cached = await GetOrLoadCatalogAsync(cancellationToken);
        return GenerateCandidatesInternal(query, targetStrength, targetDosageForm, cached);
    }

    private IReadOnlyList<ClinicalCandidateDto> GenerateCandidatesInternal(
        string query,
        string? targetStrength,
        string? targetDosageForm,
        CachedCatalog cached)
    {
        if (ContainsArabic(query))
        {
            var arabicCandidates = MatchArabicCatalog(query, query, targetStrength, targetDosageForm, cached);
            if (arabicCandidates.Count > 0)
            {
                return arabicCandidates;
            }
        }

        var queryNorm = DrugNameNormalizer.NormalizeName(query);
        if (queryNorm.Length == 0) return [];

        var queryPhonetic = _options.EnableEgyptianPhonetics
            ? DrugNameNormalizer.ApplyEgyptianPhonetics(query)
            : queryNorm;

        if (cached.Entries.Count == 0) return [];

        // Pass 1: Exact normalized trade name match
        var exactMatches = cached.Entries
            .Where(d => d.TradeNameNormalized == queryNorm ||
                        d.TradeNameNormalized.StartsWith(queryNorm + " ", StringComparison.Ordinal))
            .Select(d => ScoreCandidate(d, _options.ExactMatchBaseScore, targetStrength, targetDosageForm, cached.BrandStrengthMap))
            .OrderByDescending(m => m.Confidence)
            .ToList();

        if (exactMatches.Count > 0 && exactMatches[0].Confidence >= 0.95m)
        {
            return exactMatches.Take(_options.MaxCandidatesReturned).ToList();
        }

        // Pass 2: Fuzzy & Phonetic Multi-Tier Matching
        var queryTokens = queryNorm.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var firstQueryToken = queryTokens.Length > 0 ? queryTokens[0] : queryNorm;
        var firstQuerySkeleton = DrugNameNormalizer.ConsonantSkeleton(firstQueryToken);
        var firstQueryPhonetic = _options.EnableEgyptianPhonetics
            ? DrugNameNormalizer.ApplyEgyptianPhonetics(firstQueryToken)
            : firstQueryToken;

        var scored = new List<ClinicalCandidateDto>();

        foreach (var entry in cached.Entries)
        {
            var entryTokens = entry.TradeNameNormalized.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (entryTokens.Length == 0) continue;

            var firstEntryToken = entryTokens[0];
            var firstEntrySkeleton = DrugNameNormalizer.ConsonantSkeleton(firstEntryToken);
            var firstEntryPhonetic = _options.EnableEgyptianPhonetics
                ? DrugNameNormalizer.ApplyEgyptianPhonetics(firstEntryToken)
                : firstEntryToken;

            var baseScore = 0m;

            // 2a. Exact token or prefix match
            if (firstEntryToken.Equals(firstQueryToken, StringComparison.Ordinal))
            {
                baseScore = _options.ExactPrefixBaseScore;
            }
            else if (firstEntryToken.StartsWith(firstQueryToken, StringComparison.Ordinal) && firstQueryToken.Length >= 4)
            {
                baseScore = 0.90m;
            }
            // 2b. Egyptian phonetic equivalence (e.g. Banadol == Panadol, Libitor == Lipitor)
            else if (_options.EnableEgyptianPhonetics &&
                     firstEntryPhonetic.Length >= 4 &&
                     firstQueryPhonetic.Length >= 4 &&
                     firstEntryPhonetic.Equals(firstQueryPhonetic, StringComparison.Ordinal))
            {
                baseScore = 0.92m;
            }
            // 2c. Consonant skeleton match (recovering doctor handwritten vowel drops: Concr -> Concor)
            else if (firstQuerySkeleton.Length >= 3 &&
                     (firstEntrySkeleton == firstQuerySkeleton ||
                      firstEntrySkeleton.StartsWith(firstQuerySkeleton, StringComparison.Ordinal)))
            {
                baseScore = _options.PhoneticSkeletonBaseScore;
            }
            // 2d. Bounded Damerau-Levenshtein distance (swapped / mistyped OCR characters)
            else
            {
                var distance = DrugNameNormalizer.DamerauLevenshteinDistance(firstQueryToken, firstEntryToken);
                var maxLen = Math.Max(firstQueryToken.Length, firstEntryToken.Length);

                if (distance <= _options.MaxDamerauDistance && maxLen >= 4)
                {
                    baseScore = 1.0m - ((decimal)distance / maxLen);
                }
                else if (queryTokens.Length > 1 && entry.TradeNameNormalized.Contains(firstQueryToken, StringComparison.Ordinal))
                {
                    baseScore = 0.75m;
                }
            }

            if (baseScore >= 0.60m)
            {
                scored.Add(ScoreCandidate(
                    entry, baseScore, targetStrength, targetDosageForm, cached.BrandStrengthMap));
            }
        }

        return scored
            .OrderByDescending(m => m.Confidence)
            .Take(_options.MaxCandidatesReturned)
            .ToList();
    }

    // ── Private Helpers ──────────────────────────────────────────────────────────

    /// <summary>
    /// Returns the catalog from IMemoryCache. On a cache miss, creates a short-lived
    /// DI scope to resolve the scoped IApplicationDbContext, loads the catalog once,
    /// builds the brand strength map, and caches both together for 4 hours.
    /// </summary>
    private async Task<CachedCatalog> GetOrLoadCatalogAsync(CancellationToken cancellationToken)
    {
        if (_memoryCache.TryGetValue(CatalogCacheKey, out CachedCatalog? cached) && cached is not null)
        {
            return cached;
        }

        _logger.LogInformation(
            "ClinicalPrescriptionMatcher: catalog cache MISS — loading {Key} from database.", CatalogCacheKey);

        List<CatalogEntry> entries;
        if (_directContext != null)
        {
            entries = await _directContext.EgyptianDrugRegistry
                .AsNoTracking()
                .Select(d => new CatalogEntry(
                    d.TradeName,
                    d.TradeNameNormalized,
                    d.CommercialNameAr,
                    d.CommercialNameArNormalized,
                    d.ActiveIngredient,
                    d.Strength,
                    d.DosageForm))
                .ToListAsync(cancellationToken);
        }
        else if (_scopeFactory != null)
        {
            await using var scope = _scopeFactory.CreateAsyncScope();
            var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
            entries = await context.EgyptianDrugRegistry
                .AsNoTracking()
                .Select(d => new CatalogEntry(
                    d.TradeName,
                    d.TradeNameNormalized,
                    d.CommercialNameAr,
                    d.CommercialNameArNormalized,
                    d.ActiveIngredient,
                    d.Strength,
                    d.DosageForm))
                .ToListAsync(cancellationToken);
        }
        else
        {
            entries = [];
        }

        var brandMap = BuildBrandStrengthMap(entries);

        var result = new CachedCatalog(entries, brandMap);

        var cacheOptions = new MemoryCacheEntryOptions()
            .SetSlidingExpiration(CatalogCacheTtl)
            .SetPriority(CacheItemPriority.High);

        _memoryCache.Set(CatalogCacheKey, result, cacheOptions);

        _logger.LogInformation(
            "ClinicalPrescriptionMatcher: catalog loaded — {Count} entries, {Brands} brand roots cached for {Ttl}.",
            entries.Count, brandMap.Count, CatalogCacheTtl);

        return result;
    }

    private ClinicalCandidateDto ScoreCandidate(
        CatalogEntry entry,
        decimal baseScore,
        string? targetStrength,
        string? targetDosageForm,
        IReadOnlyDictionary<string, HashSet<string>> registeredStrengthsByBrand)
    {
        var confidence = baseScore;
        var isDosageFeasible = true;

        var brandRoot = ExtractBrandRoot(entry.TradeNameNormalized);

        // ── Dosage Feasibility Gate ──────────────────────────────────────────
        if (_options.EnableDosageFeasibilityGate && !string.IsNullOrWhiteSpace(targetStrength))
        {
            var normTargetStrength = DrugNameNormalizer.ExtractStrength(targetStrength) ??
                                     DrugNameNormalizer.NormalizeName(targetStrength);

            if (registeredStrengthsByBrand.TryGetValue(brandRoot, out var validStrengths) && validStrengths.Count > 0)
            {
                // Check if target strength matches any legally registered strength for this brand
                var matchesBrandStrength = validStrengths.Any(vs =>
                    vs.Equals(normTargetStrength, StringComparison.OrdinalIgnoreCase) ||
                    vs.Contains(normTargetStrength, StringComparison.OrdinalIgnoreCase) ||
                    normTargetStrength.Contains(vs, StringComparison.OrdinalIgnoreCase));

                if (matchesBrandStrength)
                {
                    isDosageFeasible = true;
                    // Contextual bonus for matching registered strength
                    confidence = Math.Min(1.0m, confidence + _options.DosageFeasibleBonus);
                }
                else
                {
                    // Look-Alike Sound-Alike (LASA) safety protection:
                    // Candidate brand does NOT exist in this dosage in Egypt. Apply penalty!
                    isDosageFeasible = false;
                    confidence = Math.Max(0.0m, confidence - _options.DosageMismatchPenalty);
                }
            }
        }

        // ── Dosage Form Alignment Bonus ──────────────────────────────────────
        if (!string.IsNullOrWhiteSpace(targetDosageForm) &&
            !string.IsNullOrWhiteSpace(entry.DosageForm) &&
            entry.DosageForm.Equals(targetDosageForm, StringComparison.OrdinalIgnoreCase))
        {
            confidence = Math.Min(1.0m, confidence + _options.FormMatchBonus);
        }

        return new ClinicalCandidateDto(
            entry.TradeName,
            entry.Strength,
            entry.DosageForm,
            Math.Round(confidence, 2),
            isDosageFeasible,
            entry.ActiveIngredient);
    }

    private static bool ContainsArabic(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return false;
        foreach (var c in text)
        {
            if (c is >= '\u0600' and <= '\u06FF' or >= '\u0750' and <= '\u077F' or >= '\uFB50' and <= '\uFDFF' or >= '\uFE70' and <= '\uFEFF')
                return true;
        }
        return false;
    }

    private List<ClinicalCandidateDto> MatchArabicCatalog(
        string cleaned,
        string raw,
        string? targetStrength,
        string? targetDosageForm,
        CachedCatalog cached)
    {
        var normQuery = DrugNameNormalizer.NormalizeName(cleaned);
        if (normQuery.Length == 0)
        {
            normQuery = DrugNameNormalizer.NormalizeName(raw);
        }
        if (normQuery.Length == 0) return [];

        var tokens = normQuery.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var firstToken = tokens.Length > 0 ? tokens[0] : normQuery;

        var scored = new List<ClinicalCandidateDto>();

        foreach (var entry in cached.Entries)
        {
            if (string.IsNullOrWhiteSpace(entry.CommercialNameArNormalized)) continue;

            var entryAr = entry.CommercialNameArNormalized;
            var baseScore = 0m;

            // 1. Exact match on full normalized Arabic name
            if (entryAr.Equals(normQuery, StringComparison.OrdinalIgnoreCase))
            {
                baseScore = 1.0m;
            }
            // 2. StartsWith or Contains full query
            else if (entryAr.StartsWith(normQuery + " ", StringComparison.OrdinalIgnoreCase) ||
                     normQuery.StartsWith(entryAr + " ", StringComparison.OrdinalIgnoreCase))
            {
                baseScore = 0.95m;
            }
            // 3. First Arabic token exact match (e.g. "كونكور" matches "كونكور ٥ مجم")
            else
            {
                var entryTokens = entryAr.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                var firstEntryToken = entryTokens.Length > 0 ? entryTokens[0] : entryAr;

                if (firstEntryToken.Equals(firstToken, StringComparison.OrdinalIgnoreCase) && firstToken.Length >= 3)
                {
                    baseScore = 0.93m;
                }
                else if (firstToken.Length >= 4 && (entryAr.Contains(firstToken, StringComparison.OrdinalIgnoreCase) ||
                                                    firstToken.Contains(firstEntryToken, StringComparison.OrdinalIgnoreCase)))
                {
                    baseScore = 0.85m;
                }
                else if (firstToken.Length >= 4 && firstEntryToken.Length >= 4)
                {
                    var dist = DrugNameNormalizer.DamerauLevenshteinDistance(firstToken, firstEntryToken);
                    if (dist <= 1)
                    {
                        baseScore = 0.80m;
                    }
                }
            }

            if (baseScore >= 0.70m)
            {
                scored.Add(ScoreCandidate(
                    entry, baseScore, targetStrength, targetDosageForm, cached.BrandStrengthMap));
            }
        }

        return scored
            .OrderByDescending(m => m.Confidence)
            .Take(_options.MaxCandidatesReturned)
            .ToList();
    }

    private static Dictionary<string, HashSet<string>> BuildBrandStrengthMap(IEnumerable<CatalogEntry> catalog)
    {
        var map = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);

        foreach (var entry in catalog)
        {
            var brandRoot = ExtractBrandRoot(entry.TradeNameNormalized);
            if (string.IsNullOrWhiteSpace(brandRoot)) continue;

            if (!map.TryGetValue(brandRoot, out var set))
            {
                set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                map[brandRoot] = set;
            }

            if (!string.IsNullOrWhiteSpace(entry.Strength))
            {
                var canonical = DrugNameNormalizer.ExtractStrength(entry.Strength) ??
                                DrugNameNormalizer.NormalizeName(entry.Strength);
                if (!string.IsNullOrWhiteSpace(canonical))
                {
                    set.Add(canonical);
                }
            }
        }

        return map;
    }

    private static string ExtractBrandRoot(string normalizedTradeName)
    {
        if (string.IsNullOrWhiteSpace(normalizedTradeName)) return string.Empty;
        var tokens = normalizedTradeName.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        return tokens.Length > 0 ? tokens[0] : normalizedTradeName;
    }

    private sealed record CatalogEntry(
        string TradeName,
        string TradeNameNormalized,
        string? CommercialNameAr,
        string? CommercialNameArNormalized,
        string? ActiveIngredient,
        string? Strength,
        string? DosageForm);

    /// <summary>
    /// Bundles the full catalog entry list with its pre-built brand strength map
    /// in a single cache entry — so both are always consistent and evicted together.
    /// </summary>
    private sealed record CachedCatalog(
        List<CatalogEntry> Entries,
        IReadOnlyDictionary<string, HashSet<string>> BrandStrengthMap);
}
