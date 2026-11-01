namespace Nawakes.Application.Common.Models;

/// <summary>
/// Configurable parameters for the clinical prescription matcher.
/// Allows fine-tuning scoring weights, feasibility penalties, and phonetic thresholds
/// without modifying core business or algorithm logic.
/// </summary>
public sealed class ClinicalMatchingOptions
{
    /// <summary>Confidence score above which a match is considered unambiguous without user confirmation.</summary>
    public decimal ConfidentThreshold { get; set; } = 0.82m;

    /// <summary>Base score awarded for an exact normalized string match against the master catalog.</summary>
    public decimal ExactMatchBaseScore { get; set; } = 1.0m;

    /// <summary>Base score for an exact token prefix match (e.g. "CONCOR" matches "CONCOR 5MG").</summary>
    public decimal ExactPrefixBaseScore { get; set; } = 0.95m;

    /// <summary>Base score for matching phonetic consonant skeletons (recovering doctor handwritten vowel drops).</summary>
    public decimal PhoneticSkeletonBaseScore { get; set; } = 0.88m;

    /// <summary>Bonus awarded when the extracted dosage strength matches a registered strength in the EDA catalog.</summary>
    public decimal DosageFeasibleBonus { get; set; } = 0.08m;

    /// <summary>Penalty subtracted when candidate brand family has registered strengths, but none match the extracted strength.</summary>
    public decimal DosageMismatchPenalty { get; set; } = 0.25m;

    /// <summary>Bonus awarded when candidate dosage form aligns with extracted form (e.g. "Tablet", "Capsule").</summary>
    public decimal FormMatchBonus { get; set; } = 0.04m;

    /// <summary>Maximum Damerau-Levenshtein distance allowed for character transpositions / OCR substitutions.</summary>
    public int MaxDamerauDistance { get; set; } = 2;

    /// <summary>Whether to enforce the Dosage Feasibility Gate against official EDA registrations.</summary>
    public bool EnableDosageFeasibilityGate { get; set; } = true;

    /// <summary>Whether to apply Egyptian colloquial and clinical phonetic transformations (P/B, PH/F, K/C).</summary>
    public bool EnableEgyptianPhonetics { get; set; } = true;

    /// <summary>Maximum number of candidate suggestions returned for disambiguation.</summary>
    public int MaxCandidatesReturned { get; set; } = 10;
}
