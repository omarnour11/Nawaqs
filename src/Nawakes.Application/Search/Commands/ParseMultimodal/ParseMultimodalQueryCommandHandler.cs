using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Common;

namespace Nawakes.Application.Search.Commands.ParseMultimodal;

/// <summary>
/// Fuzzy-matching pipeline for noisy voice/OCR text against the EDA catalog:
/// Pass 1 (dialect rule table) → Pass 2 (exact normalized lookup) →
/// Pass 3 (fuzzy: prefix / substring / bounded edit distance). No LLM involved.
/// </summary>
public sealed class ParseMultimodalQueryCommandHandler(
    IApplicationDbContext context,
    IEgyptianDialectNormalizer dialectNormalizer)
    : IRequestHandler<ParseMultimodalQueryCommand, ParsedMedicationDto>
{
    private const int FuzzyEditTolerance = 2;
    private const decimal ConfidentThreshold = 0.8m;

    public async Task<ParsedMedicationDto> Handle(
        ParseMultimodalQueryCommand request, CancellationToken cancellationToken)
    {
        var raw = request.RawText?.Trim() ?? string.Empty;
        if (raw.Length == 0)
        {
            return new ParsedMedicationDto(string.Empty, null, null, 0m, true, []);
        }

        // Pass 1: Egyptian dialect rules (Arabic → Latin trade name + strength words)
        var normalized = await dialectNormalizer.NormalizeAsync(raw, cancellationToken);

        // Pass 2/3 run against the catalog
        var candidates = await FindCandidatesAsync(normalized?.TradeName ?? raw, cancellationToken);

        if (candidates.Count == 0)
        {
            return new ParsedMedicationDto(string.Empty, null, null, 0m, true, []);
        }

        var best = candidates[0];
        var requiresDisambiguation = candidates.Count > 1 || best.Confidence < ConfidentThreshold;

        return new ParsedMedicationDto(
            best.TradeName,
            best.Strength ?? normalized?.Strength,
            best.DosageForm ?? normalized?.DosageForm,
            best.Confidence,
            requiresDisambiguation,
            candidates.Take(3).Select(c => new ParsedCandidateDto(
                c.TradeName, c.Strength, c.DosageForm, c.Confidence)).ToList());
    }

    private async Task<List<CatalogMatch>> FindCandidatesAsync(string query, CancellationToken ct)
    {
        var queryNorm = DrugNameNormalizer.NormalizeName(query);
        if (queryNorm.Length == 0) return [];

        var catalog = await context.EgyptianDrugRegistry
            .AsNoTracking()
            .Select(d => new { d.TradeName, d.TradeNameNormalized, d.Strength, d.DosageForm })
            .ToListAsync(ct);

        // Pass 2: exact normalized match
        var exact = catalog
            .Where(d => d.TradeNameNormalized == queryNorm)
            .Select(d => new CatalogMatch(d.TradeName, d.Strength, d.DosageForm, 1.0m))
            .ToList();
        if (exact.Count > 0) return exact;

        // Pass 3a: token-level fuzzy per catalog entry
        var queryTokens = queryNorm.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var scored = new List<CatalogMatch>();

        foreach (var d in catalog)
        {
            var entryTokens = d.TradeNameNormalized.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (entryTokens.Length == 0) continue;

            var bestScore = 0m;
            foreach (var qt in queryTokens)
            {
                foreach (var et in entryTokens)
                {
                    bestScore = Math.Max(bestScore, TokenSimilarity(qt, et));
                }
            }

            if (bestScore >= 0.5m)
            {
                scored.Add(new CatalogMatch(d.TradeName, d.Strength, d.DosageForm, bestScore));
            }
        }

        return scored
            .OrderByDescending(m => m.Confidence)
            .Take(10)
            .ToList();
    }

    private static decimal TokenSimilarity(string queryToken, string entryToken)
    {
        if (queryToken == entryToken) return 1.0m;
        if (entryToken.StartsWith(queryToken, StringComparison.Ordinal)) return 0.9m;
        if (queryToken.Length >= 4 && entryToken.Contains(queryToken, StringComparison.Ordinal)) return 0.85m;

        var distance = BoundedEditDistance(queryToken, entryToken, FuzzyEditTolerance);
        if (distance < 0) return 0m;

        var longer = Math.Max(queryToken.Length, entryToken.Length);
        var score = 1.0m - (decimal)distance / longer;

        return score >= 0.5m ? score : 0m;
    }

    /// <summary>Levenshtein distance with early exit; returns -1 when tolerance is exceeded.</summary>
    private static int BoundedEditDistance(string a, string b, int tolerance)
    {
        if (Math.Abs(a.Length - b.Length) > tolerance) return -1;

        var prev = new int[b.Length + 1];
        var curr = new int[b.Length + 1];

        for (var j = 0; j <= b.Length; j++) prev[j] = j;

        for (var i = 1; i <= a.Length; i++)
        {
            curr[0] = i;
            var rowMin = curr[0];

            for (var j = 1; j <= b.Length; j++)
            {
                var cost = a[i - 1] == b[j - 1] ? 0 : 1;
                curr[j] = Math.Min(Math.Min(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
                rowMin = Math.Min(rowMin, curr[j]);
            }

            if (rowMin > tolerance) return -1;
            (prev, curr) = (curr, prev);
        }

        return prev[b.Length] <= tolerance ? prev[b.Length] : -1;
    }

    private sealed record CatalogMatch(
        string TradeName, string? Strength, string? DosageForm, decimal Confidence);
}
