namespace Nawakes.Application.Common.Interfaces;

public sealed record NormalizedMedication(
    string TradeName,
    string? Strength,
    string? DosageForm,
    decimal Confidence);

public interface IEgyptianDialectNormalizer
{
    /// <summary>
    /// Applies the Egyptian dialect rule table to raw voice/OCR text: maps
    /// Arabic drug names to Latin trade names, number words to strengths,
    /// and extracts package quantities.
    /// </summary>
    Task<NormalizedMedication?> NormalizeAsync(string rawText, CancellationToken cancellationToken = default);
}
