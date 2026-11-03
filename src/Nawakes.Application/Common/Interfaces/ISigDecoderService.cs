namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// Structured medical abbreviation definition detected in a prescription Sig.
/// </summary>
public sealed record SigAbbreviationDto(
    string Code,
    string Latin,
    string Meaning,
    string? ArabicMeaning = null);

/// <summary>
/// Fully decoded prescription Sig instructions in both standardized English and patient-friendly Arabic.
/// </summary>
public sealed record DecodedSigDto(
    string RawSig,
    string DoseAmount,
    string RouteCode,
    string RouteExpanded,
    string FrequencyCode,
    string FrequencyExpanded,
    string TimingExpanded,
    string PrnReason,
    string DurationExpanded,
    string DispenseQuantity,
    string HumanReadable,
    string ArabicInstruction,
    IReadOnlyList<SigAbbreviationDto> AbbreviationsDetected,
    int DoseQuantity = 1,
    int? FrequencyPerDay = 1,
    string? RouteArabic = "عن طريق الفم",
    string? TimingArabic = null)
{
    public string ArabicInstructionSticker => ArabicInstruction;
    public string ArabicText => ArabicInstruction;
}

/// <summary>
/// Bilingual Sig decoder service for medical prescriptions.
/// Translates Latin/English abbreviations and colloquial Egyptian notations (1x1, 1x2, 1x3, 1x4, على الريق, بعد الأكل, قبل النوم)
/// into standardized pharmacy sticker instructions.
/// </summary>
public interface ISigDecoderService
{
    /// <summary>
    /// Decodes a raw Sig instruction string into human-readable English and patient-friendly Arabic.
    /// </summary>
    DecodedSigDto DecodeMedicalSig(string rawSig);

    /// <summary>
    /// Alias for DecodeMedicalSig.
    /// </summary>
    DecodedSigDto DecodeSig(string rawSig) => DecodeMedicalSig(rawSig);

    /// <summary>
    /// Decodes a Sig with knowledge of the medication's dosage form (Tablet, Eye Drops, Suspension, ...).
    /// When the Sig omits an explicit unit (e.g. the Egyptian "1x2" shorthand), the unit word is
    /// derived from the dosage form instead of defaulting to "قرص واحد".
    /// </summary>
    DecodedSigDto DecodeMedicalSig(string rawSig, string? dosageForm);

    /// <summary>
    /// Extracts the directions (Sig) portion from a raw doctor prescription line.
    /// </summary>
    string ExtractSigFromRawLine(string rawLine, string defaultSig = "1 tab PO QD #30");
}
