namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// Secondary Cloud OCR service (e.g. Azure AI Vision 4.0 Read API) used as Tier 2 failover
/// when Tier 1 (Gemini Flash AI) encounters quota exhaustion, 429 rate limiting, or network timeout.
/// </summary>
public interface ISecondaryOcrService
{
    /// <summary>
    /// Indicates whether the secondary OCR client has valid credentials and is enabled.
    /// </summary>
    bool IsConfigured { get; }

    /// <summary>
    /// Extracts text lines from a prescription image stream.
    /// </summary>
    Task<IReadOnlyList<string>> ExtractTextLinesAsync(
        byte[] imageBytes,
        string contentType,
        CancellationToken cancellationToken = default);
}
