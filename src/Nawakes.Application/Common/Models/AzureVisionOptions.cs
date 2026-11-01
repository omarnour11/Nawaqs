namespace Nawakes.Application.Common.Models;

/// <summary>
/// Configuration options for Azure AI Vision 4.0 Read API.
/// Used as Tier 2 secondary cloud OCR failover.
/// </summary>
public sealed class AzureVisionOptions
{
    public const string SectionName = "AzureVision";

    /// <summary>
    /// Azure AI Vision cognitive services endpoint, e.g. https://eastus.api.cognitive.microsoft.com/
    /// </summary>
    public string Endpoint { get; set; } = string.Empty;

    /// <summary>
    /// Azure AI Vision subscription key.
    /// </summary>
    public string ApiKey { get; set; } = string.Empty;

    /// <summary>
    /// Global toggle to enable/disable Azure Vision OCR.
    /// </summary>
    public bool IsEnabled { get; set; } = true;

    /// <summary>
    /// Timeout in seconds for Read API analysis.
    /// </summary>
    public int TimeoutSeconds { get; set; } = 10;
}
