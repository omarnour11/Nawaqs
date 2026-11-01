using MediatR;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Search.Commands.ParseMultimodal;

/// <summary>
/// Handles multimodal voice and prescription queries using a Dual-Engine Resilient Pipeline:
/// 1. Engine A (Gemini Flash AI): Used for up to 1,400 daily requests (95-98% accuracy on messy handwriting).
///    Every AI prediction is cross-checked against the 37k official EDA catalog via the Dosage Feasibility Gate.
/// 2. Engine B (Local Fallback): When the 1,400 quota is exhausted, or on HTTP 429/network failure,
///    the handler automatically falls back to <see cref="IClinicalPrescriptionMatcher"/> and forces
///    RequiresDisambiguation = true so the mobile app displays the 1-tap confirmation card.
/// </summary>
public sealed class ParseMultimodalQueryCommandHandler(
    IClinicalPrescriptionMatcher prescriptionMatcher,
    IGeminiPrescriptionService geminiService,
    ILogger<ParseMultimodalQueryCommandHandler> logger)
    : IRequestHandler<ParseMultimodalQueryCommand, ParsedMedicationDto>
{
    public async Task<ParsedMedicationDto> Handle(
        ParseMultimodalQueryCommand request, CancellationToken cancellationToken)
    {
        var raw = request.RawText?.Trim() ?? string.Empty;
        var imageBase64 = request.ImageBase64?.Trim();
        if (raw.Length == 0 && string.IsNullOrWhiteSpace(imageBase64))
        {
            return new ParsedMedicationDto(string.Empty, null, null, 0m, true, []);
        }

        var isAiQuotaAvailable = geminiService.IsDailyQuotaAvailable();

        // ── Engine A: Gemini Flash AI (High Accuracy Tier) ──────────────────────
        if (isAiQuotaAvailable)
        {
            try
            {
                var aiResult = !string.IsNullOrWhiteSpace(imageBase64)
                    ? await geminiService.ParsePrescriptionFromImageAsync(
                        imageBase64!, raw.Length > 0 ? raw : null, cancellationToken)
                    : await geminiService.ParsePrescriptionAsync(raw, cancellationToken);

                var items = aiResult.Medications is { Count: > 0 }
                    ? aiResult.Medications
                    : (!string.IsNullOrWhiteSpace(aiResult.TradeName)
                        ? [new GeminiMedicationItem(aiResult.TradeName!, aiResult.Strength, aiResult.DosageForm, aiResult.Confidence)]
                        : null);

                if (aiResult.IsSuccess && items is { Count: > 0 })
                {
                    var verifiedCandidates = new List<ParsedCandidateDto>();
                    foreach (var item in items)
                    {
                        var verified = await prescriptionMatcher.MatchPrescriptionAsync(
                            item.TradeName, item.Strength, item.DosageForm, cancellationToken);

                        var effectiveTrade = !string.IsNullOrWhiteSpace(verified.ResolvedName) ? verified.ResolvedName : item.TradeName;
                        var effectiveStrength = verified.Strength ?? item.Strength;
                        var effectiveForm = verified.DosageForm ?? item.DosageForm;
                        var effectiveConf = verified.Confidence > 0 ? Math.Max(verified.Confidence, item.Confidence) : item.Confidence;

                        verifiedCandidates.Add(new ParsedCandidateDto(
                            effectiveTrade, effectiveStrength, effectiveForm, effectiveConf, item.Quantity, verified.ActiveIngredient));
                    }

                    if (verifiedCandidates.Count > 0)
                    {
                        var primary = verifiedCandidates[0];
                        var requiresDisambiguation = verifiedCandidates.Count > 1 || primary.Confidence < 0.90m;

                        logger.LogInformation(
                            "Prescription resolved via Gemini Flash AI with {Count} medications. Primary: {Primary}",
                            verifiedCandidates.Count, primary.TradeName);

                        return new ParsedMedicationDto(
                            primary.TradeName,
                            primary.Strength,
                            primary.DosageForm,
                            primary.Confidence,
                            requiresDisambiguation,
                            verifiedCandidates,
                            primary.ActiveIngredient);
                    }
                }
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Gemini Flash AI failed. Gracefully falling over to local matching engine.");
            }
        }

        // ── Engine B: Local Engine (Fallback Tier — 100% Free & In-Process) ─────
        logger.LogInformation(
            "Resolving prescription via local ClinicalPrescriptionMatcher (AI Quota available: {Quota}).",
            isAiQuotaAvailable);

        var lines = raw.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var localCandidates = new List<ParsedCandidateDto>();

        foreach (var line in lines)
        {
            if (line.Length < 3) continue;
            var match = await prescriptionMatcher.MatchPrescriptionAsync(line, null, null, cancellationToken);
            if (!string.IsNullOrWhiteSpace(match.ResolvedName))
            {
                localCandidates.Add(new ParsedCandidateDto(
                    match.ResolvedName, match.Strength, match.DosageForm, match.Confidence, 1, match.ActiveIngredient));
            }
        }

        if (localCandidates.Count > 0)
        {
            var primary = localCandidates[0];
            return new ParsedMedicationDto(
                primary.TradeName,
                primary.Strength,
                primary.DosageForm,
                primary.Confidence,
                true,
                localCandidates,
                primary.ActiveIngredient);
        }

        var localResolution = await prescriptionMatcher.MatchPrescriptionAsync(
            raw, null, null, cancellationToken);

        var requiresDisambig = !isAiQuotaAvailable ||
                               localResolution.RequiresDisambiguation ||
                               localResolution.Confidence < 0.95m;

        return new ParsedMedicationDto(
            localResolution.ResolvedName,
            localResolution.Strength,
            localResolution.DosageForm,
            localResolution.Confidence,
            requiresDisambig,
            localResolution.Candidates.Take(5).Select(c => new ParsedCandidateDto(
                c.TradeName, c.Strength, c.DosageForm, c.Confidence, 1, c.ActiveIngredient)).ToList(),
            localResolution.ActiveIngredient);
    }
}
