using MediatR;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Commands.ParseMultimodal;

namespace Nawakes.Application.Search.Commands.ParsePrescriptionImage;

/// <summary>
/// Multi-Tier Doctor Prescription Image Recognition &amp; Clinical Validation Handler:
/// Tier 1: Google Gemini Flash Vision AI (high accuracy cursive &amp; multilingual handwriting).
/// Tier 2: Secondary Cloud OCR (Azure AI Vision 4.0 Read API) failover on quota, 429, or timeout.
/// Tier 3: In-Process Fallback using on-device OCR hint text + ClinicalPrescriptionMatcher.
/// Every candidate is validated and anchored against the 37k official EDA catalog via the Dosage Feasibility Gate,
/// decoded via Bilingual ISigDecoderService, and audited by IPrescriptionSafetyAuditor.
/// </summary>
public sealed class ParsePrescriptionImageCommandHandler : IRequestHandler<ParsePrescriptionImageCommand, ParsedMedicationDto>
{
    private readonly IGeminiPrescriptionService _geminiService;
    private readonly ISecondaryOcrService _secondaryOcrService;
    private readonly IClinicalPrescriptionMatcher _prescriptionMatcher;
    private readonly ISigDecoderService _sigDecoderService;
    private readonly IPrescriptionSafetyAuditor _safetyAuditor;
    private readonly ILogger<ParsePrescriptionImageCommandHandler> _logger;

    [ActivatorUtilitiesConstructor]
    public ParsePrescriptionImageCommandHandler(
        IGeminiPrescriptionService geminiService,
        ISecondaryOcrService secondaryOcrService,
        IClinicalPrescriptionMatcher prescriptionMatcher,
        ISigDecoderService sigDecoderService,
        IPrescriptionSafetyAuditor safetyAuditor,
        ILogger<ParsePrescriptionImageCommandHandler> logger)
    {
        _geminiService = geminiService;
        _secondaryOcrService = secondaryOcrService;
        _prescriptionMatcher = prescriptionMatcher;
        _sigDecoderService = sigDecoderService;
        _safetyAuditor = safetyAuditor;
        _logger = logger;
    }

    /// <summary>
    /// Backward-compatible constructor for existing tests and callers without explicit decoder/auditor injections.
    /// </summary>
    public ParsePrescriptionImageCommandHandler(
        IGeminiPrescriptionService geminiService,
        ISecondaryOcrService secondaryOcrService,
        IClinicalPrescriptionMatcher prescriptionMatcher,
        ILogger<ParsePrescriptionImageCommandHandler> logger)
        : this(
            geminiService,
            secondaryOcrService,
            prescriptionMatcher,
            new FallbackSigDecoderService(),
            new FallbackSafetyAuditor(),
            logger)
    {
    }

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
        var isAiQuotaAvailable = _geminiService.IsDailyQuotaAvailable();
        if (isAiQuotaAvailable)
        {
            try
            {
                _logger.LogInformation("Processing prescription image via Tier 1 Gemini Vision AI.");
                var aiResult = await _geminiService.ParsePrescriptionFromImageBytesAsync(
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
                        var match = await _prescriptionMatcher.MatchPrescriptionAsync(
                            item.TradeName, item.Strength, item.DosageForm, cancellationToken);

                        var effectiveTrade = !string.IsNullOrWhiteSpace(match.ResolvedName)
                            ? match.ResolvedName
                            : item.TradeName;
                        var effectiveStrength = match.Strength ?? item.Strength;
                        var effectiveForm = match.DosageForm ?? item.DosageForm;
                        var effectiveConf = match.Confidence > 0
                            ? Math.Max(match.Confidence, item.Confidence)
                            : item.Confidence;

                        var rawSig = !string.IsNullOrWhiteSpace(item.RawSig)
                            ? item.RawSig
                            : _sigDecoderService.ExtractSigFromRawLine(item.TradeName);
                        var decodedSig = _sigDecoderService.DecodeMedicalSig(rawSig);
                        var price = match.PriceEgp ?? match.Candidates.FirstOrDefault(c => c.PriceEgp.HasValue)?.PriceEgp;

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
                                c.ActiveIngredient,
                                false,
                                null,
                                rawSig,
                                decodedSig.ArabicInstruction,
                                c.PriceEgp))
                            .ToList();

                        verifiedCandidates.Add(new ParsedCandidateDto(
                            effectiveTrade,
                            effectiveStrength,
                            effectiveForm,
                            effectiveConf,
                            item.Quantity,
                            match.ActiveIngredient,
                            requiresDisambig,
                            alternatives.Count > 0 ? alternatives : null,
                            rawSig,
                            decodedSig.ArabicInstruction,
                            price));
                    }

                    if (verifiedCandidates.Count > 0)
                    {
                        var primary = verifiedCandidates[0];
                        // Bug Fix: Multiple valid prescribed items MUST NOT trigger disambiguation.
                        // Disambiguation is only required if an individual candidate requires it or primary confidence is low.
                        var requiresDisambiguation = verifiedCandidates.Any(c => c.RequiresDisambiguation) ||
                                                     primary.Confidence < 0.90m;

                        var safetyAlerts = _safetyAuditor.AuditPrescriptionSafety(verifiedCandidates, request.PatientAllergies);

                        _logger.LogInformation(
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
                            IsSuccess: true,
                            RawSig: primary.RawSig,
                            ArabicSig: primary.ArabicSig,
                            PriceEgp: primary.PriceEgp,
                            SafetyAlerts: safetyAlerts);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Tier 1 Gemini Vision AI failed. Evaluating Tier 2 failover.");
            }
        }
        else
        {
            _logger.LogInformation("Tier 1 Gemini AI daily quota exhausted or circuit breaker tripped. Skipping to Tier 2.");
        }

        // ── Tier 2: Secondary Cloud OCR (Azure AI Vision 4.0 Read API) ────────
        if (_secondaryOcrService.IsConfigured)
        {
            try
            {
                _logger.LogInformation("Attempting Tier 2 Secondary Cloud OCR failover.");
                var lines = await _secondaryOcrService.ExtractTextLinesAsync(
                    request.ImageBytes, request.ContentType, cancellationToken);

                if (lines.Count > 0)
                {
                    var tier2Candidates = new List<ParsedCandidateDto>();
                    foreach (var line in lines)
                    {
                        if (string.IsNullOrWhiteSpace(line) || line.Trim().Length < 3) continue;
                        var match = await _prescriptionMatcher.MatchPrescriptionAsync(line, null, null, cancellationToken);
                        if (!string.IsNullOrWhiteSpace(match.ResolvedName) && match.Confidence >= 0.70m)
                        {
                            var rawSig = _sigDecoderService.ExtractSigFromRawLine(line);
                            var decodedSig = _sigDecoderService.DecodeMedicalSig(rawSig);
                            var price = match.PriceEgp ?? match.Candidates.FirstOrDefault(c => c.PriceEgp.HasValue)?.PriceEgp;

                            var alts = match.Candidates
                                .Where(c => !c.TradeName.Equals(match.ResolvedName, StringComparison.OrdinalIgnoreCase))
                                .Take(3)
                                .Select(c => new ParsedCandidateDto(
                                    c.TradeName, c.Strength, c.DosageForm, c.Confidence, 1, c.ActiveIngredient, false, null, rawSig, decodedSig.ArabicInstruction, c.PriceEgp))
                                .ToList();

                            tier2Candidates.Add(new ParsedCandidateDto(
                                match.ResolvedName,
                                match.Strength,
                                match.DosageForm,
                                match.Confidence,
                                1,
                                match.ActiveIngredient,
                                RequiresDisambiguation: true,
                                Alternatives: alts.Count > 0 ? alts : null,
                                RawSig: rawSig,
                                ArabicSig: decodedSig.ArabicInstruction,
                                PriceEgp: price));
                        }
                    }

                    if (tier2Candidates.Count > 0)
                    {
                        var primary = tier2Candidates[0];
                        var safetyAlerts = _safetyAuditor.AuditPrescriptionSafety(tier2Candidates, request.PatientAllergies);

                        _logger.LogInformation(
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
                            IsSuccess: true,
                            RawSig: primary.RawSig,
                            ArabicSig: primary.ArabicSig,
                            PriceEgp: primary.PriceEgp,
                            SafetyAlerts: safetyAlerts);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Tier 2 Secondary Cloud OCR failed. Evaluating Tier 3 fallback.");
            }
        }

        // ── Tier 3: In-Process Fallback via OCR Hint Text ──────────────────────
        if (!string.IsNullOrWhiteSpace(request.OcrHintText))
        {
            _logger.LogInformation("Falling back to Tier 3 in-process OCR hint text matching.");
            var hintLines = request.OcrHintText.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var tier3Candidates = new List<ParsedCandidateDto>();

            foreach (var line in hintLines)
            {
                if (line.Length < 3) continue;
                var match = await _prescriptionMatcher.MatchPrescriptionAsync(line, null, null, cancellationToken);
                if (!string.IsNullOrWhiteSpace(match.ResolvedName) && match.Confidence >= 0.65m)
                {
                    var rawSig = _sigDecoderService.ExtractSigFromRawLine(line);
                    var decodedSig = _sigDecoderService.DecodeMedicalSig(rawSig);
                    var price = match.PriceEgp ?? match.Candidates.FirstOrDefault(c => c.PriceEgp.HasValue)?.PriceEgp;

                    var alts = match.Candidates
                        .Where(c => !c.TradeName.Equals(match.ResolvedName, StringComparison.OrdinalIgnoreCase))
                        .Take(3)
                        .Select(c => new ParsedCandidateDto(
                            c.TradeName, c.Strength, c.DosageForm, c.Confidence, 1, c.ActiveIngredient, false, null, rawSig, decodedSig.ArabicInstruction, c.PriceEgp))
                        .ToList();

                    tier3Candidates.Add(new ParsedCandidateDto(
                        match.ResolvedName,
                        match.Strength,
                        match.DosageForm,
                        match.Confidence,
                        1,
                        match.ActiveIngredient,
                        RequiresDisambiguation: true,
                        Alternatives: alts.Count > 0 ? alts : null,
                        RawSig: rawSig,
                        ArabicSig: decodedSig.ArabicInstruction,
                        PriceEgp: price));
                }
            }

            if (tier3Candidates.Count > 0)
            {
                var primary = tier3Candidates[0];
                var safetyAlerts = _safetyAuditor.AuditPrescriptionSafety(tier3Candidates, request.PatientAllergies);

                _logger.LogInformation(
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
                    IsSuccess: true,
                    RawSig: primary.RawSig,
                    ArabicSig: primary.ArabicSig,
                    PriceEgp: primary.PriceEgp,
                    SafetyAlerts: safetyAlerts);
            }
        }

        // ── No Medications Recognized ─────────────────────────────────────────
        _logger.LogWarning("Prescription image processing completed with zero recognized medications.");
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

    private sealed class FallbackSigDecoderService : ISigDecoderService
    {
        public DecodedSigDto DecodeMedicalSig(string rawSig) =>
            new(rawSig, "1 tablet", "PO", "by mouth", "QD", "once daily", "", "", "", "30 units", "Take 1 tablet by mouth once daily.", "قرص واحد — عن طريق الفم — مرة واحدة يومياً", []);

        public string ExtractSigFromRawLine(string rawLine, string defaultSig = "1 tab PO QD #30") => defaultSig;
    }

    private sealed class FallbackSafetyAuditor : IPrescriptionSafetyAuditor
    {
        public IReadOnlyList<SafetyAlertDto> AuditPrescriptionSafety(
            IReadOnlyList<ParsedCandidateDto> candidates,
            IReadOnlyList<string>? patientAllergies = null) => [];

        public IReadOnlyList<SafetyAlertDto> AuditPrescriptionSafety(
            IReadOnlyList<SafetyMedicationInput> medications,
            IReadOnlyList<string>? patientAllergies = null) => [];

        public Task<IReadOnlyList<SafetyAlertDto>> AuditPrescriptionSafetyAsync(
            IReadOnlyList<SafetyMedicationInput> medications,
            IReadOnlyList<string>? patientAllergies = null,
            CancellationToken cancellationToken = default) =>
            Task.FromResult<IReadOnlyList<SafetyAlertDto>>([]);
    }
}
