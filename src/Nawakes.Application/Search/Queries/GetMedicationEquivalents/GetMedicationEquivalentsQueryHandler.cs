using System.Text.RegularExpressions;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Common;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using NetTopologySuite.Geometries;

namespace Nawakes.Application.Search.Queries.GetMedicationEquivalents;

/// <summary>
/// Bioequivalent substitution & generic active ingredient search (Phase 4).
/// Matching is strictly deterministic: same active ingredient + same strength + same dosage form.
/// Supports both:
/// 1. Trade Name search: finds exact bioequivalents and dosage alternatives for a given brand.
/// 2. Active Scientific Ingredient (INN) search: finds all registered Egyptian brands containing that molecule.
/// Joins nearby in-stock inventory and computes price savings vs. the official EDA compulsory price.
/// </summary>
public sealed class GetMedicationEquivalentsQueryHandler(
    IApplicationDbContext context)
    : IRequestHandler<GetMedicationEquivalentsQuery, MedicationEquivalentsResponse>
{
    public const string LegalDisclaimerText =
        "⚠️ تنبيه طبي: هذا بديل متطابق بنفس المادة الفعالة والتركيز. استشر الصيدلي أو الطبيب دائماً قبل الاستبدال طبقاً لتعليمات هيئة الدواء المصرية.";

    private static readonly Dictionary<string, string> ArabicToEnglishActiveIngredients = new(StringComparer.OrdinalIgnoreCase)
    {
        ["باراسيتامول"] = "PARACETAMOL",
        ["بيسوبرولول"] = "BISOPROLOL",
        ["بيسوبرولول فيومارات"] = "BISOPROLOL FUMARATE",
        ["اموكسيسيلين"] = "AMOXICILLIN",
        ["أموكسيسيلين"] = "AMOXICILLIN",
        ["أموكسيسيللين"] = "AMOXICILLIN",
        ["ديكلوفيناك"] = "DICLOFENAC",
        ["ديكلوفيناك بوتاسيوم"] = "DICLOFENAC POTASSIUM",
        ["ديكلوفيناك صوديوم"] = "DICLOFENAC SODIUM",
        ["ايبوبروفين"] = "IBUPROFEN",
        ["إيبوبروفين"] = "IBUPROFEN",
        ["اوميبرازول"] = "OMEPRAZOLE",
        ["أوميبرازول"] = "OMEPRAZOLE",
        ["ايزوميبرازول"] = "ESOMEPRAZOLE",
        ["إيزوميبرازول"] = "ESOMEPRAZOLE",
        ["بانتوبرازول"] = "PANTOPRAZOLE",
        ["ازيثروميسين"] = "AZITHROMYCIN",
        ["أزيثروميسين"] = "AZITHROMYCIN",
        ["سيتريزين"] = "CETIRIZINE",
        ["لوراتادين"] = "LORATADINE",
        ["ميتفورمين"] = "METFORMIN",
        ["اتورفاستاتين"] = "ATORVASTATIN",
        ["أتورفاستاتين"] = "ATORVASTATIN",
        ["روسوفاستاتين"] = "ROSUVASTATIN",
        ["سيلدينافيل"] = "SILDENAFIL",
        ["سيبروفلوكساسين"] = "CIPROFLOXACIN",
        ["ليفوفلوكساسين"] = "LEVOFLOXACIN",
        ["املوديبين"] = "AMLODIPINE",
        ["أملوديبين"] = "AMLODIPINE",
        ["فالسارتان"] = "VALSARTAN",
        ["إيتوبريد"] = "ITOPRIDE",
        ["ايتوبريد"] = "ITOPRIDE",
        ["بريدنيزولون"] = "PREDNISOLONE",
        ["بنتوكسيفيرين"] = "PENTOXYVERINE",
        ["كلوفاج"] = "METFORMIN"
    };

    private static readonly Dictionary<string, string> EnglishToArabicActiveIngredients = new(StringComparer.OrdinalIgnoreCase)
    {
        ["PARACETAMOL"] = "باراسيتامول",
        ["BISOPROLOL"] = "بيسوبرولول",
        ["BISOPROLOL FUMARATE"] = "بيسوبرولول فيومارات",
        ["AMOXICILLIN"] = "أموكسيسيلين",
        ["AMOXICILLIN / CLAVULANIC ACID"] = "أموكسيسيلين + حمض الكلافولانيك",
        ["DICLOFENAC"] = "ديكلوفيناك",
        ["DICLOFENAC POTASSIUM"] = "ديكلوفيناك بوتاسيوم",
        ["DICLOFENAC SODIUM"] = "ديكلوفيناك صوديوم",
        ["IBUPROFEN"] = "إيبوبروفين",
        ["OMEPRAZOLE"] = "أوميبرازول",
        ["ESOMEPRAZOLE"] = "إيزوميبرازول",
        ["PANTOPRAZOLE"] = "بانتوبرازول",
        ["ITOPRIDE"] = "إيتوبريد",
        ["PREDNISOLONE"] = "بريدنيزولون",
        ["PENTOXYVERINE"] = "بنتوكسيفيرين",
        ["AZITHROMYCIN"] = "أزيثروميسين",
        ["CETIRIZINE"] = "سيتريزين",
        ["LORATADINE"] = "لوراتادين",
        ["METFORMIN"] = "ميتفورمين",
        ["ATORVASTATIN"] = "أتورفاستاتين",
        ["ROSUVASTATIN"] = "روسوفاستاتين",
        ["SILDENAFIL"] = "سيلدينافيل",
        ["CIPROFLOXACIN"] = "سيبروفلوكساسين",
        ["LEVOFLOXACIN"] = "ليفوفلوكساسين",
        ["AMLODIPINE"] = "أملوديبين",
        ["VALSARTAN"] = "فالسارتان"
    };

    public async Task<MedicationEquivalentsResponse> Handle(
        GetMedicationEquivalentsQuery request, CancellationToken cancellationToken)
    {
        var rawInput = request.MedicationName?.Trim() ?? string.Empty;
        if (rawInput.Length < 2)
        {
            return new MedicationEquivalentsResponse(null, [], LegalDisclaimerText);
        }

        var sourceNorm = DrugNameNormalizer.NormalizeName(rawInput);
        var sourceLookup = DrugNameNormalizer.NormalizeLookup(rawInput);
        var searcherLocation = new Point(request.Lng, request.Lat) { SRID = 4326 };
        var radiusMeters = (double)request.RadiusKm * 1000;

        // Check if query directly specifies an active ingredient (in Arabic or English)
        string? activeIngredientMatch = null;
        if (ArabicToEnglishActiveIngredients.TryGetValue(rawInput, out var mappedEnglish))
        {
            activeIngredientMatch = mappedEnglish;
        }
        else if (ArabicToEnglishActiveIngredients.TryGetValue(sourceNorm, out var mappedNorm))
        {
            activeIngredientMatch = mappedNorm;
        }

        // 1. Check if the query is an Active Scientific Ingredient (INN)
        var isDirectActiveIngredient = activeIngredientMatch != null ||
            await context.EgyptianDrugRegistry
                .AsNoTracking()
                .AnyAsync(d => d.ActiveIngredientNormalized != null &&
                               (d.ActiveIngredientNormalized == sourceNorm ||
                                d.ActiveIngredientNormalized.StartsWith(sourceNorm + " ") ||
                                d.ActiveIngredientNormalized.EndsWith(" " + sourceNorm)), cancellationToken);

        if (isDirectActiveIngredient)
        {
            var activeNorm = activeIngredientMatch ?? sourceNorm;
            return await HandleActiveIngredientQueryAsync(
                rawInput, activeNorm, searcherLocation, radiusMeters, cancellationToken);
        }

        // 2. Otherwise, treat as Brand / Trade Name
        var source = await context.EgyptianDrugRegistry
            .AsNoTracking()
            .FirstOrDefaultAsync(d =>
                d.TradeNameNormalized == sourceNorm ||
                (d.CommercialNameArNormalized != null && d.CommercialNameArNormalized == sourceNorm) ||
                (d.CommercialNameAr != null && d.CommercialNameAr == rawInput) ||
                d.TradeName.ToLower() == rawInput.ToLower(), cancellationToken);

        // Fallback: check if trade name starts with normalized query
        if (source == null)
        {
            source = await context.EgyptianDrugRegistry
                .AsNoTracking()
                .FirstOrDefaultAsync(d =>
                    d.TradeNameNormalized.StartsWith(sourceNorm) ||
                    (d.CommercialNameArNormalized != null && d.CommercialNameArNormalized.StartsWith(sourceNorm)),
                    cancellationToken);
        }

        // No active ingredient on file → substitute feature stays hidden (never guess)
        if (source?.ActiveIngredientNormalized is null)
        {
            return new MedicationEquivalentsResponse(
                source is null ? null : ToOriginal(source, false),
                [], LegalDisclaimerText);
        }

        return await HandleBrandEquivalentsAsync(
            source, searcherLocation, radiusMeters, cancellationToken);
    }

    private async Task<MedicationEquivalentsResponse> HandleActiveIngredientQueryAsync(
        string rawInput,
        string activeNorm,
        Point searcherLocation,
        double radiusMeters,
        CancellationToken cancellationToken)
    {
        // Find all drugs sharing this active ingredient
        var allWithActive = await context.EgyptianDrugRegistry
            .AsNoTracking()
            .Where(d => d.ActiveIngredientNormalized != null &&
                        (d.ActiveIngredientNormalized == activeNorm ||
                         d.ActiveIngredientNormalized.Contains(activeNorm)))
            .Select(d => new
            {
                d.Id,
                d.TradeName,
                d.CommercialNameAr,
                d.ActiveIngredient,
                d.ActiveIngredientNormalized,
                d.Strength,
                d.DosageForm,
                d.OfficialPriceEGP,
                d.Manufacturer
            })
            .ToListAsync(cancellationToken);

        if (allWithActive.Count == 0)
        {
            return new MedicationEquivalentsResponse(null, [], LegalDisclaimerText);
        }

        var canonicalActive = allWithActive.First().ActiveIngredient ?? activeNorm;
        var canonicalActiveAr = EnglishToArabicActiveIngredients.TryGetValue(activeNorm, out var ar)
            ? ar
            : rawInput;

        var allTradeNameLookups = allWithActive
            .Select(e => DrugNameNormalizer.NormalizeLookup(e.TradeName))
            .ToHashSet();

        // Query in-stock inventory nearby
        var inStockNearby = await context.InventoryItems
            .AsNoTracking()
            .Where(i => i.Status == InventoryStatus.InStock &&
                        i.Quantity > 0 &&
                        allTradeNameLookups.Contains(i.MedicationNameNormalized.ToLower()) &&
                        i.Pharmacy.VerificationStatus == VerificationStatus.Approved &&
                        i.Pharmacy.GeoPoint.Distance(searcherLocation) <= radiusMeters &&
                        !i.Pharmacy.IsDeleted)
            .Select(i => new
            {
                i.Id,
                i.MedicationName,
                i.Price,
                PharmacyId = i.Pharmacy.Id,
                PharmacyName = i.Pharmacy.Name,
                Distance = i.Pharmacy.GeoPoint.Distance(searcherLocation)
            })
            .OrderBy(i => i.Distance)
            .Take(30)
            .ToListAsync(cancellationToken);

        // Group into Bioequivalents and Alternatives
        var bioequivalents = new List<EquivalentPharmacyResult>();
        var alternatives = new List<EquivalentPharmacyResult>();
        var seenInventoryIds = new HashSet<Guid>();

        // 1. First add in-stock inventory items
        foreach (var inv in inStockNearby)
        {
            seenInventoryIds.Add(inv.Id);
            var match = allWithActive.FirstOrDefault(e =>
                DrugNameNormalizer.NormalizeLookup(e.TradeName) == inv.MedicationName.Trim().ToLowerInvariant());

            var officialPrice = match?.OfficialPriceEGP ?? inv.Price;
            var item = new EquivalentPharmacyResult(
                inv.MedicationName,
                match?.Manufacturer,
                officialPrice,
                0m,
                inv.PharmacyId,
                inv.PharmacyName,
                Math.Round(inv.Distance / 1000, 2),
                inv.Id,
                inv.Price,
                match?.Strength,
                match?.DosageForm,
                match?.CommercialNameAr,
                true,
                0m,
                "ExactBioequivalent",
                true);

            bioequivalents.Add(item);
        }

        var allCombined = bioequivalents.Concat(alternatives).ToList();

        var originalInfo = new OriginalMedicationInfo(
            TradeName: canonicalActive,
            ActiveIngredient: canonicalActive,
            Strength: allWithActive.FirstOrDefault(a => a.Strength != null)?.Strength,
            DosageForm: allWithActive.FirstOrDefault(a => a.DosageForm != null)?.DosageForm,
            OfficialPriceEGP: allWithActive.Min(a => a.OfficialPriceEGP),
            IsAvailableNearby: inStockNearby.Count > 0,
            CommercialNameAr: canonicalActiveAr,
            Manufacturer: "هيئة الدواء المصرية (دليل الأصناف المسجلة)");

        return new MedicationEquivalentsResponse(
            originalInfo,
            allCombined,
            LegalDisclaimerText,
            IsActiveIngredientSearch: true,
            ActiveIngredient: canonicalActive,
            ActiveIngredientAr: canonicalActiveAr,
            TotalRegisteredInEgypt: allWithActive.Count,
            Bioequivalents: bioequivalents,
            TherapeuticAlternatives: alternatives);
    }

    private async Task<MedicationEquivalentsResponse> HandleBrandEquivalentsAsync(
        EgyptianDrugRegistry source,
        Point searcherLocation,
        double radiusMeters,
        CancellationToken cancellationToken)
    {
        // 1. Bioequivalents: same active ingredient + same strength + same dosage form (excluding self)
        var bioCandidates = await context.EgyptianDrugRegistry
            .AsNoTracking()
            .Where(d => d.ActiveIngredientNormalized == source.ActiveIngredientNormalized &&
                        d.Strength == source.Strength &&
                        d.DosageForm == source.DosageForm &&
                        d.Id != source.Id)
            .Select(d => new
            {
                d.Id,
                d.TradeName,
                d.CommercialNameAr,
                d.Manufacturer,
                d.OfficialPriceEGP,
                d.Strength,
                d.DosageForm
            })
            .ToListAsync(cancellationToken);

        // 2. Therapeutic alternatives: same active ingredient with different strength or dosage form
        var alternativeCandidates = await context.EgyptianDrugRegistry
            .AsNoTracking()
            .Where(d => d.ActiveIngredientNormalized == source.ActiveIngredientNormalized &&
                        (d.Strength != source.Strength || d.DosageForm != source.DosageForm) &&
                        d.Id != source.Id)
            .Select(d => new
            {
                d.Id,
                d.TradeName,
                d.CommercialNameAr,
                d.Manufacturer,
                d.OfficialPriceEGP,
                d.Strength,
                d.DosageForm
            })
            .ToListAsync(cancellationToken);

        var bioLookups = bioCandidates
            .Select(e => DrugNameNormalizer.NormalizeLookup(e.TradeName))
            .ToHashSet();

        var altLookups = alternativeCandidates
            .Select(e => DrugNameNormalizer.NormalizeLookup(e.TradeName))
            .ToHashSet();

        var allCandidateLookups = bioLookups.Union(altLookups).ToHashSet();

        // In-stock inventory nearby for any candidate
        var inStockNearby = await context.InventoryItems
            .AsNoTracking()
            .Where(i => i.Status == InventoryStatus.InStock &&
                        i.Quantity > 0 &&
                        allCandidateLookups.Contains(i.MedicationNameNormalized.ToLower()) &&
                        i.Pharmacy.VerificationStatus == VerificationStatus.Approved &&
                        i.Pharmacy.GeoPoint.Distance(searcherLocation) <= radiusMeters &&
                        !i.Pharmacy.IsDeleted)
            .Select(i => new
            {
                i.Id,
                i.MedicationName,
                i.Price,
                PharmacyId = i.Pharmacy.Id,
                PharmacyName = i.Pharmacy.Name,
                Distance = i.Pharmacy.GeoPoint.Distance(searcherLocation)
            })
            .OrderBy(i => i.Distance)
            .Take(30)
            .ToListAsync(cancellationToken);

        var originalPrice = source.OfficialPriceEGP;

        var bioResults = new List<EquivalentPharmacyResult>();
        var altResults = new List<EquivalentPharmacyResult>();

        // Process in-stock items
        foreach (var inv in inStockNearby)
        {
            var isBio = bioLookups.Contains(inv.MedicationName.Trim().ToLowerInvariant());
            var matchedCandidate = isBio
                ? bioCandidates.FirstOrDefault(c => DrugNameNormalizer.NormalizeLookup(c.TradeName) == inv.MedicationName.Trim().ToLowerInvariant())
                : alternativeCandidates.FirstOrDefault(c => DrugNameNormalizer.NormalizeLookup(c.TradeName) == inv.MedicationName.Trim().ToLowerInvariant());

            var officialPrice = matchedCandidate?.OfficialPriceEGP ?? inv.Price;
            var savingPercent = originalPrice > 0 && inv.Price < originalPrice.Value
                ? Math.Round((originalPrice.Value - inv.Price) / originalPrice.Value * 100m, 0)
                : 0m;
            var priceDiff = originalPrice > 0 && inv.Price < originalPrice.Value
                ? originalPrice.Value - inv.Price
                : 0m;

            var result = new EquivalentPharmacyResult(
                inv.MedicationName,
                matchedCandidate?.Manufacturer,
                officialPrice,
                savingPercent,
                inv.PharmacyId,
                inv.PharmacyName,
                Math.Round(inv.Distance / 1000, 2),
                inv.Id,
                inv.Price,
                matchedCandidate?.Strength ?? source.Strength,
                matchedCandidate?.DosageForm ?? source.DosageForm,
                matchedCandidate?.CommercialNameAr,
                isBio,
                priceDiff,
                isBio ? "ExactBioequivalent" : "DosageAlternative",
                true);

            if (isBio)
                bioResults.Add(result);
            else
                altResults.Add(result);
        }

        var isAvailableNearby = await context.InventoryItems
            .AsNoTracking()
            .AnyAsync(i => i.Status == InventoryStatus.InStock &&
                           i.Quantity > 0 &&
                           i.MedicationNameNormalized.ToLower() == source.TradeNameNormalized.ToLower() &&
                           i.Pharmacy.VerificationStatus == VerificationStatus.Approved &&
                           i.Pharmacy.GeoPoint.Distance(searcherLocation) <= radiusMeters &&
                           !i.Pharmacy.IsDeleted, cancellationToken);

        var activeAr = EnglishToArabicActiveIngredients.TryGetValue(source.ActiveIngredientNormalized ?? "", out var arName)
            ? arName
            : null;

        var allAvailable = bioResults.Concat(altResults).ToList();

        return new MedicationEquivalentsResponse(
            ToOriginal(source, isAvailableNearby),
            allAvailable,
            LegalDisclaimerText,
            IsActiveIngredientSearch: false,
            ActiveIngredient: source.ActiveIngredient,
            ActiveIngredientAr: activeAr,
            TotalRegisteredInEgypt: bioCandidates.Count + alternativeCandidates.Count + 1,
            Bioequivalents: bioResults,
            TherapeuticAlternatives: altResults);
    }

    private static OriginalMedicationInfo ToOriginal(EgyptianDrugRegistry source, bool isAvailableNearby) =>
        new(source.TradeName, source.ActiveIngredient, source.Strength,
            source.DosageForm, source.OfficialPriceEGP, isAvailableNearby,
            source.CommercialNameAr, source.Manufacturer);
}
