namespace Nawakes.Application.Common.Models;

/// <summary>
/// Configuration options for Google Gemini Multimodal / Text Prescription AI.
/// Supports free tier quota gating (default 1,400 requests/day) with automatic failover.
/// </summary>
public sealed class GeminiOptions
{
    public const string SectionName = "Gemini";

    /// <summary>Google AI Studio API key.</summary>
    public string ApiKey { get; set; } = string.Empty;

    /// <summary>Gemini model for text-only requests.</summary>
    public string Model { get; set; } = "gemini-1.5-flash";

    /// <summary>Model for prescription photos (vision). Free tier: gemini-1.5-flash.</summary>
    public string VisionModel { get; set; } = "gemini-1.5-flash";

    /// <summary>Maximum daily requests before failing over to local matching engine.</summary>
    public int DailyQuotaLimit { get; set; } = 1400;

    /// <summary>Global toggle to enable/disable Gemini AI.</summary>
    public bool IsEnabled { get; set; } = true;

    /// <summary>HTTP timeout in seconds for Gemini API calls.</summary>
    public int TimeoutSeconds { get; set; } = 5;
}
