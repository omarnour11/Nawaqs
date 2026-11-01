using MediatR;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Commands.ParseMultimodal;

namespace Nawakes.Application.Search.Commands.ParsePrescriptionImage;

/// <summary>
/// Multi-Tier Doctor Prescription Image Recognition &amp; Clinical Validation Handler:
/// Tier 1: Google Gemini Flash Vision AI (high accuracy cursive &amp; multilingual handwriting).
/// Tier 2: Secondary Cloud OCR (Azure AI Vision 4.0 Read API) failover on quota, 429, or timeout.
/// Tier 3: In-Process Fallback using on-device OCR hint text + ClinicalPrescriptionMatcher.
/// Every candidate is validated and anchored against the 37k official EDA catalog via the Dosage Feasibility Gate.
/// </summary>
public sealed class ParsePrescriptionImageCommandHandler(
    IGeminiPrescriptionService geminiService,
    ISecondaryOcrService secondaryOcrService,
    IClinicalPrescriptionMatcher prescriptionMatcher,
    ILogger<ParsePrescriptionImageCommandHandler> logger)
    : IRequestHandler<ParsePrescriptionImageCommand, ParsedMedicationDto>
{
    public async Task<ParsedMedicationDto> Handle(
        ParsePrescriptionImageCommand request,
        CancellationToken cancellationToken)
    {
        if (request.ImageBytes is null || request.ImageBytes.Length == 0)
        {
            return new ParsedMedicationDto(
                ResolvedName: string.Empty,
                Strength: null,
                DosageForm: null,
                Confidence: 0m,
                RequiresDisambiguation: true,
                Candidates: [],
                ActiveIngredient: null,
                IsSuccess: false,
                ErrorCode: "INVALID_IMAGE",
                ErrorMessage: "صورة الروشتة غير صالحة أو فارغة.");
        }

        // ── Tier 1: Google Gemini Flash Vision AI ─────────────────────────────
        var isAiQuotaAvailable = geminiService.IsDailyQuotaAvailable();
        if (isAiQuotaAvailable)
        {
            try
            {
                logger.LogInformation("Processing prescription image via Tier 1 Gemini Vision AI.");
                var aiResult = await geminiService.ParsePrescriptionFromImageBytesAsync(
                    request.ImageBytes,
                    request.ContentType,
                    request.OcrHintText,
                    cancellationToken);

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
                        var match = await prescriptionMatcher.MatchPrescriptionAsync(
                            item.TradeName, item.Strength, item.DosageForm, cancellationToken);

                        var effectiveTrade = !string.IsNullOrWhiteSpace(match.ResolvedName)
                            ? match.ResolvedName
                            : item.TradeName;
                        var effectiveStrength = match.Strength ?? item.Strength;
                        var effectiveForm = match.DosageForm ?? item.DosageForm;
                        var effectiveConf = match.Confidence > 0
                            ? Math.Max(match.Confidence, item.Confidence)
                            : item.Confidence;

                        var requiresDisambig = match.RequiresDisambiguation || effectiveConf < 0.90m;
                        var alternatives = match.Candidates
                            .Where(c => !c.TradeName.Equals(effectiveTrade, StringComparison.OrdinalIgnoreCase))
                            .Take(3)
                            .Select(c => new ParsedCandidateDto(
                                c.TradeName,
                                c.Strength,
                                c.DosageForm,
                                c.Confidence,
                                1,
                                c.ActiveIngredient))
                            .ToList();

                        verifiedCandidates.Add(new ParsedCandidateDto(
                            effectiveTrade,
                            effectiveStrength,
                            effectiveForm,
                            effectiveConf,
                            item.Quantity,
                            match.ActiveIngredient,
                            requiresDisambig,
                            alternatives.Count > 0 ? alternatives : null));
                    }

                    if (verifiedCandidates.Count > 0)
                    {
                        var primary = verifiedCandidates[0];
                        var requiresDisambiguation = verifiedCandidates.Any(c => c.RequiresDisambiguation) ||
                                                     verifiedCandidates.Count > 1 ||
                                                     primary.Confidence < 0.90m;

                        logger.LogInformation(
                            "Prescription resolved via Gemini Vision Tier 1 with {Count} medications. Primary: {Primary}",
                            verifiedCandidates.Count, primary.TradeName);

                        return new ParsedMedicationDto(
                            primary.TradeName,
                            primary.Strength,
                            primary.DosageForm,
                            primary.Confidence,
                            requiresDisambiguation,
                            verifiedCandidates,
                            primary.ActiveIngredient,
                            IsSuccess: true);
                    }
                }
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Tier 1 Gemini Vision AI failed. Evaluating Tier 2 failover.");
            }
        }
        else
        {
            logger.LogInformation("Tier 1 Gemini AI daily quota exhausted or circuit breaker tripped. Skipping to Tier 2.");
        }

        // ── Tier 2: Secondary Cloud OCR (Azure AI Vision 4.0 Read API) ────────
        if (secondaryOcrService.IsConfigured)
        {
            try
            {
                logger.LogInformation("Attempting Tier 2 Secondary Cloud OCR failover.");
                var lines = await secondaryOcrService.ExtractTextLinesAsync(
                    request.ImageBytes, request.ContentType, cancellationToken);

                if (lines.Count > 0)
                {
                    var tier2Candidates = new List<ParsedCandidateDto>();
                    foreach (var line in lines)
                    {
                        if (string.IsNullOrWhiteSpace(line) || line.Trim().Length < 3) continue;
                        var match = await prescriptionMatcher.MatchPrescriptionAsync(line, null, null, cancellationToken);
                        if (!string.IsNullOrWhiteSpace(match.ResolvedName) && match.Confidence >= 0.70m)
                        {
                            var alts = match.Candidates
                                .Where(c => !c.TradeName.Equals(match.ResolvedName, StringComparison.OrdinalIgnoreCase))
                                .Take(3)
                                .Select(c => new ParsedCandidateDto(
                                    c.TradeName, c.Strength, c.DosageForm, c.Confidence, 1, c.ActiveIngredient))
                                .ToList();

                            tier2Candidates.Add(new ParsedCandidateDto(
                                match.ResolvedName,
                                match.Strength,
                                match.DosageForm,
                                match.Confidence,
                                1,
                                match.ActiveIngredient,
                                RequiresDisambiguation: true,
                                Alternatives: alts.Count > 0 ? alts : null));
                        }
                    }

                    if (tier2Candidates.Count > 0)
                    {
                        var primary = tier2Candidates[0];
                        logger.LogInformation(
                            "Prescription resolved via Tier 2 Secondary Cloud OCR with {Count} medications.",
                            tier2Candidates.Count);

                        return new ParsedMedicationDto(
                            primary.TradeName,
                            primary.Strength,
                            primary.DosageForm,
                            primary.Confidence,
                            RequiresDisambiguation: true,
                            tier2Candidates,
                            primary.ActiveIngredient,
                            IsSuccess: true);
                    }
                }
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Tier 2 Secondary Cloud OCR failed. Evaluating Tier 3 fallback.");
            }
        }

        // ── Tier 3: In-Process Fallback via OCR Hint Text ──────────────────────
        if (!string.IsNullOrWhiteSpace(request.OcrHintText))
        {
            logger.LogInformation("Falling back to Tier 3 in-process OCR hint text matching.");
            var hintLines = request.OcrHintText.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var tier3Candidates = new List<ParsedCandidateDto>();

            foreach (var line in hintLines)
            {
                if (line.Length < 3) continue;
                var match = await prescriptionMatcher.MatchPrescriptionAsync(line, null, null, cancellationToken);
                if (!string.IsNullOrWhiteSpace(match.ResolvedName) && match.Confidence >= 0.65m)
                {
                    var alts = match.Candidates
                        .Where(c => !c.TradeName.Equals(match.ResolvedName, StringComparison.OrdinalIgnoreCase))
                        .Take(3)
                        .Select(c => new ParsedCandidateDto(
                            c.TradeName, c.Strength, c.DosageForm, c.Confidence, 1, c.ActiveIngredient))
                        .ToList();

                    tier3Candidates.Add(new ParsedCandidateDto(
                        match.ResolvedName,
                        match.Strength,
                        match.DosageForm,
                        match.Confidence,
                        1,
                        match.ActiveIngredient,
                        RequiresDisambiguation: true,
                        Alternatives: alts.Count > 0 ? alts : null));
                }
            }

            if (tier3Candidates.Count > 0)
            {
                var primary = tier3Candidates[0];
                logger.LogInformation(
                    "Prescription resolved via Tier 3 in-process OCR hint matching with {Count} medications.",
                    tier3Candidates.Count);

                return new ParsedMedicationDto(
                    primary.TradeName,
                    primary.Strength,
                    primary.DosageForm,
                    primary.Confidence,
                    RequiresDisambiguation: true,
                    tier3Candidates,
                    primary.ActiveIngredient,
                    IsSuccess: true);
            }
        }

        // ── No Medications Recognized ─────────────────────────────────────────
        logger.LogWarning("Prescription image processing completed with zero recognized medications.");
        return new ParsedMedicationDto(
            ResolvedName: string.Empty,
            Strength: null,
            DosageForm: null,
            Confidence: 0m,
            RequiresDisambiguation: true,
            Candidates: [],
            ActiveIngredient: null,
            IsSuccess: false,
            ErrorCode: "NO_MEDICATIONS_FOUND",
            ErrorMessage: "لم نتمكن من قراءة أدوية في هذه الصورة. يرجى التأكد من وضوح الروشتة والإضاءة.");
    }
}
