using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Common.Models;

namespace Nawakes.Infrastructure.NLP;

/// <summary>
/// Azure AI Vision 4.0 Read API integration.
/// Acts as Tier 2 secondary cloud OCR failover when Gemini Vision (Tier 1) encounters
/// quota exhaustion, rate limiting (429), or network timeout.
/// </summary>
public sealed class AzureVisionOcrService : ISecondaryOcrService
{
    private readonly HttpClient _httpClient;
    private readonly AzureVisionOptions _options;
    private readonly ILogger<AzureVisionOcrService> _logger;

    public AzureVisionOcrService(
        HttpClient httpClient,
        IOptions<AzureVisionOptions> options,
        ILogger<AzureVisionOcrService> logger)
    {
        _httpClient = httpClient;
        _options = options.Value;
        _logger = logger;

        if (_options.TimeoutSeconds > 0)
        {
            _httpClient.Timeout = TimeSpan.FromSeconds(_options.TimeoutSeconds);
        }
    }

    /// <inheritdoc />
    public bool IsConfigured =>
        _options.IsEnabled &&
        !string.IsNullOrWhiteSpace(_options.Endpoint) &&
        !string.IsNullOrWhiteSpace(_options.ApiKey) &&
        !_options.ApiKey.Contains("REPLACE_WITH", StringComparison.OrdinalIgnoreCase);

    /// <inheritdoc />
    public async Task<IReadOnlyList<string>> ExtractTextLinesAsync(
        byte[] imageBytes,
        string contentType,
        CancellationToken cancellationToken = default)
    {
        if (!IsConfigured)
        {
            _logger.LogDebug("Azure Vision OCR is not configured. Skipping Tier 2 extraction.");
            return [];
        }

        if (imageBytes == null || imageBytes.Length == 0)
        {
            return [];
        }

        try
        {
            var requestUrl = $"{_options.Endpoint.TrimEnd('/')}/computervision/imageanalysis:analyze?api-version=2024-02-01&features=read";
            using var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
            request.Headers.TryAddWithoutValidation("Ocp-Apim-Subscription-Key", _options.ApiKey);

            var mime = string.IsNullOrWhiteSpace(contentType) ? "image/jpeg" : contentType;
            request.Content = new ByteArrayContent(imageBytes);
            request.Content.Headers.ContentType = new MediaTypeHeaderValue(mime);

            var response = await _httpClient.SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning(
                    "Azure Vision Read API failed with status {StatusCode}. Gracefully degrading.",
                    response.StatusCode);
                return [];
            }

            using var doc = await response.Content.ReadFromJsonAsync<JsonDocument>(cancellationToken: cancellationToken);
            if (doc is null) return [];

            var lines = new List<string>();
            var root = doc.RootElement;

            // Azure AI Vision 4.0 Read API returns:
            // { "readResult": { "blocks": [ { "lines": [ { "text": "..." } ] } ] } }
            // or { "readResult": { "lines": [ { "text": "..." } ] } }
            if (root.TryGetProperty("readResult", out var readResult))
            {
                if (readResult.TryGetProperty("blocks", out var blocks) && blocks.ValueKind == JsonValueKind.Array)
                {
                    foreach (var block in blocks.EnumerateArray())
                    {
                        if (block.TryGetProperty("lines", out var blockLines) && blockLines.ValueKind == JsonValueKind.Array)
                        {
                            foreach (var lineEl in blockLines.EnumerateArray())
                            {
                                if (lineEl.TryGetProperty("text", out var textProp))
                                {
                                    var text = textProp.GetString()?.Trim();
                                    if (!string.IsNullOrEmpty(text))
                                    {
                                        lines.Add(text);
                                    }
                                }
                            }
                        }
                    }
                }
                else if (readResult.TryGetProperty("lines", out var directLines) && directLines.ValueKind == JsonValueKind.Array)
                {
                    foreach (var lineEl in directLines.EnumerateArray())
                    {
                        if (lineEl.TryGetProperty("text", out var textProp))
                        {
                            var text = textProp.GetString()?.Trim();
                            if (!string.IsNullOrEmpty(text))
                            {
                                lines.Add(text);
                            }
                        }
                    }
                }
            }

            _logger.LogInformation("Azure Vision OCR extracted {Count} text lines.", lines.Count);
            return lines;
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("Azure Vision Read API call timed out after {Timeout}s.", _options.TimeoutSeconds);
            return [];
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Azure Vision OCR encountered an error. Gracefully degrading.");
            return [];
        }
    }
}
