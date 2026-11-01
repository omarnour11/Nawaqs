namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// A single candidate medication evaluated during clinical prescription matching.
/// </summary>
public sealed record ClinicalCandidateDto(
    string TradeName,
    string? Strength,
    string? DosageForm,
    decimal Confidence,
    bool IsDosageFeasible,
    string? ActiveIngredient = null,
    decimal? PriceEgp = null);

/// <summary>
/// Resolution result produced by the clinical prescription matcher.
/// </summary>
public sealed record ClinicalMatchResolution(
    string ResolvedName,
    string? Strength,
    string? DosageForm,
    decimal Confidence,
    bool RequiresDisambiguation,
    IReadOnlyList<ClinicalCandidateDto> Candidates,
    string? ActiveIngredient = null,
    decimal? PriceEgp = null);

/// <summary>
/// Dedicated clinical prescription resolution service.
/// Decoupled from MediatR commands to allow independent tuning, testing, and evolution.
/// Implements:
/// 1. Clinical noise stripping (R/, 1-, bid, 1x1, Arabic frequencies).
/// 2. Egyptian medical phonetic transformations (P/B, PH/F, K/C).
/// 3. Consonant skeleton vowel-drop compression.
/// 4. Dosage Feasibility Gate (validates candidates against the 37k official EDA registered strengths).
/// 5. Damerau-Levenshtein edit-distance with contextual scoring.
/// </summary>
public interface IClinicalPrescriptionMatcher
{
    Task<ClinicalMatchResolution> MatchPrescriptionAsync(
        string rawText,
        string? targetStrength = null,
        string? targetDosageForm = null,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ClinicalCandidateDto>> GenerateCandidatesAsync(
        string query,
        string? targetStrength,
        string? targetDosageForm,
        CancellationToken cancellationToken = default);
}
