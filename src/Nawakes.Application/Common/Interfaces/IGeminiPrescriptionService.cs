namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// A medication item extracted from a prescription.
/// </summary>
public sealed record GeminiMedicationItem(
    string TradeName,
    string? Strength,
    string? DosageForm,
    decimal Confidence,
    int Quantity = 1,
    string? RawSig = null,
    string? GenericName = null);

/// <summary>
/// Result returned by Gemini Flash AI prescription analysis.
/// </summary>
public sealed record GeminiPrescriptionResult(
    string? TradeName,
    string? Strength,
    string? DosageForm,
    decimal Confidence,
    bool IsSuccess,
    bool QuotaExceeded,
    IReadOnlyList<GeminiMedicationItem>? Medications = null);

/// <summary>
/// Service interface for extracting and cleaning prescription text using Google Gemini Flash.
/// Enforces daily quota limits and trips circuit breaker upon quota exhaustion or 429 status.
/// </summary>
public interface IGeminiPrescriptionService
{
    /// <summary>
    /// Checks whether the daily Gemini quota is available.
    /// </summary>
    bool IsDailyQuotaAvailable();

    /// <summary>
    /// Current count of requests processed today.
    /// </summary>
    int GetDailyRequestCount();

    /// <summary>
    /// Analyzes noisy prescription text using Gemini Flash AI.
    /// Returns QuotaExceeded = true if limit reached or 429 encountered, prompting immediate local fallback.
    /// </summary>
    Task<GeminiPrescriptionResult> ParsePrescriptionAsync(
        string rawText,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Reads a cropped prescription photo (JPEG base64) with optional on-device OCR hints.
    /// </summary>
    Task<GeminiPrescriptionResult> ParsePrescriptionFromImageAsync(
        string jpegBase64,
        string? ocrHintText,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Reads a prescription photo from raw image bytes with optional on-device OCR hints.
    /// </summary>
    Task<GeminiPrescriptionResult> ParsePrescriptionFromImageBytesAsync(
        byte[] imageBytes,
        string contentType,
        string? ocrHintText,
        CancellationToken cancellationToken = default);
}
