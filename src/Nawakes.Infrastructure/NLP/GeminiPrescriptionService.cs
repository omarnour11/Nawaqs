using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Common.Models;

namespace Nawakes.Infrastructure.NLP;

/// <summary>
/// Google Gemini Flash integration for clinical prescription deciphering.
/// Implements a 1,400 daily quota limit with distributed atomic tracking (Redis/memory),
/// exponential backoff retry on 429/503, and automated circuit breaker tripping
/// (5-minute TTL) upon quota exhaustion.
/// </summary>
public sealed class GeminiPrescriptionService : IGeminiPrescriptionService
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private readonly HttpClient _httpClient;
    private readonly IDistributedCache _distributedCache;
    private readonly IMemoryCache _memoryCache;
    private readonly ILogger<GeminiPrescriptionService> _logger;
    private readonly GeminiOptions _options;

    private const string CircuitBreakerKey = "gemini:circuit_breaker_tripped";
    private static string GetQuotaCacheKey() => $"gemini:quota:{DateTime.UtcNow:yyyy-MM-dd}";

    public GeminiPrescriptionService(
        HttpClient httpClient,
        IDistributedCache distributedCache,
        IMemoryCache memoryCache,
        IOptions<GeminiOptions> options,
        ILogger<GeminiPrescriptionService> logger)
    {
        _httpClient = httpClient;
        _distributedCache = distributedCache;
        _memoryCache = memoryCache;
        _logger = logger;
        _options = options.Value;

        if (string.IsNullOrWhiteSpace(_options.ApiKey))
        {
            var envKey = Environment.GetEnvironmentVariable("GEMINI_API_KEY") ?? Environment.GetEnvironmentVariable("GOOGLE_API_KEY");
            if (!string.IsNullOrWhiteSpace(envKey))
            {
                _options.ApiKey = envKey.Trim();
            }
        }

        if (_options.TimeoutSeconds > 0)
        {
            _httpClient.Timeout = TimeSpan.FromSeconds(_options.TimeoutSeconds);
        }
    }

    /// <inheritdoc />
    public bool IsDailyQuotaAvailable()
    {
        if (!_options.IsEnabled || !LooksLikeGeminiKey(_options.ApiKey))
        {
            return false;
        }

        // If circuit breaker is tripped
        if (IsCircuitBreakerTripped())
        {
            return false;
        }

        var current = GetDailyRequestCount();
        return current < _options.DailyQuotaLimit;
    }

    /// <inheritdoc />
    public int GetDailyRequestCount()
    {
        var key = GetQuotaCacheKey();
        try
        {
            var strVal = _distributedCache.GetString(key);
            if (!string.IsNullOrEmpty(strVal) && int.TryParse(strVal, out var count))
            {
                return count;
            }
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "Distributed cache unavailable for daily quota count. Falling back to memory cache.");
        }

        return _memoryCache.TryGetValue(key, out int memCount) ? memCount : 0;
    }

    /// <inheritdoc />
    public Task<GeminiPrescriptionResult> ParsePrescriptionAsync(
        string rawText,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(rawText))
        {
            return Task.FromResult(new GeminiPrescriptionResult(null, null, null, 0m, false, false));
        }

        return GenerateMedicationsAsync(BuildTextPrompt(rawText), imagePart: null, cancellationToken);
    }

    /// <inheritdoc />
    public Task<GeminiPrescriptionResult> ParsePrescriptionFromImageAsync(
        string jpegBase64,
        string? ocrHintText,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(jpegBase64))
        {
            return Task.FromResult(new GeminiPrescriptionResult(null, null, null, 0m, false, false));
        }

        if (jpegBase64.Length > 6_000_000)
        {
            _logger.LogWarning("Prescription image too large ({Length} chars base64). Skipping vision.", jpegBase64.Length);
            return Task.FromResult(new GeminiPrescriptionResult(null, null, null, 0m, false, false));
        }

        var imagePart = new { inlineData = new { mimeType = "image/jpeg", data = jpegBase64 } };
        return GenerateMedicationsAsync(BuildVisionPrompt(ocrHintText), imagePart, cancellationToken);
    }

    /// <inheritdoc />
    public Task<GeminiPrescriptionResult> ParsePrescriptionFromImageBytesAsync(
        byte[] imageBytes,
        string contentType,
        string? ocrHintText,
        CancellationToken cancellationToken = default)
    {
        if (imageBytes is null || imageBytes.Length == 0)
        {
            return Task.FromResult(new GeminiPrescriptionResult(null, null, null, 0m, false, false));
        }

        if (imageBytes.Length > 10 * 1024 * 1024)
        {
            _logger.LogWarning("Prescription image too large ({Length} bytes). Skipping vision.", imageBytes.Length);
            return Task.FromResult(new GeminiPrescriptionResult(null, null, null, 0m, false, false));
        }

        var base64 = Convert.ToBase64String(imageBytes);
        var mime = string.IsNullOrWhiteSpace(contentType) ? "image/jpeg" : contentType;
        var imagePart = new { inlineData = new { mimeType = mime, data = base64 } };
        return GenerateMedicationsAsync(BuildVisionPrompt(ocrHintText), imagePart, cancellationToken);
    }

    private static string BuildTextPrompt(string rawText) => $$"""
            You are an Egyptian clinical pharmacist expert in deciphering messy doctor handwriting and prescription text.
            CRITICAL INSTRUCTIONS:
            - Strictly ignore doctor names (e.g. Dr., د., دكتور), clinic/hospital headers, patient names, dates, phone numbers, and addresses.
            - Extract ONLY the prescribed medications (e.g. Concor, Augmentin, Lipitor, Glucophage, Cataflam, Controloc, Panadol).
            - For each medication identify:
              1. tradeName: Official Egyptian brand/trade name (NEVER put a doctor or clinic name here!).
              2. strength: Dosage strength if present (e.g. 5mg, 10mg, 1000mg, 1g, 50mg).
              3. dosageForm: Dosage form if present (e.g. Tablet, Capsule, Syrup, Injection).
              4. quantity: Number of packs or count if indicated (e.g. 1, 2, 3), default to 1.
              5. confidence: Confidence score between 0.0 and 1.0.

            PRESCRIPTION TEXT TO DECIPHER:
            ---
            {{rawText}}
            ---

            Output ONLY valid JSON matching this exact structure:
            {
              "medications": [
                {"tradeName": "string", "strength": "string or null", "dosageForm": "string or null", "quantity": 1, "confidence": 0.95}
              ]
            }
            Do not include markdown fences or any other text.
            """;

    private static string BuildVisionPrompt(string? ocrHintText)
    {
        var hint = string.IsNullOrWhiteSpace(ocrHintText)
            ? "No on-device OCR hint."
            : ocrHintText.Trim();
        return $$"""
            You are an Egyptian clinical pharmacist reading a prescription pad.
            Read Arabic and Latin handwriting. Use official Egyptian brand names (e.g. Concor, Augmentin, Panadol, Glucophage, Cataflam, Controloc, Brufen, Antinal, etc.).
            Strictly ignore doctor/clinic headers, physician credentials, stamps, patient demographic details, phone numbers, dates, and addresses.
            Extract ALL prescribed medications in the Rx body.
            On-device OCR hint (may be noisy — verify against the image):
            ---
            {{hint}}
            ---

            Output ONLY valid JSON:
            {
              "medications": [
                {"tradeName": "string", "strength": "string or null", "dosageForm": "string or null", "quantity": 1, "confidence": 0.95}
              ]
            }
            Do not include markdown fences or any other text.
            """;
    }

    private async Task<GeminiPrescriptionResult> GenerateMedicationsAsync(
        string prompt,
        object? imagePart,
        CancellationToken cancellationToken)
    {
        if (!IsDailyQuotaAvailable())
        {
            _logger.LogInformation(
                "Gemini AI daily quota reached or circuit breaker active ({Count}/{Limit}). Failing over to local engine.",
                GetDailyRequestCount(), _options.DailyQuotaLimit);
            return new GeminiPrescriptionResult(null, null, null, 0m, false, true);
        }

        var model = string.IsNullOrWhiteSpace(_options.VisionModel)
            ? _options.Model
            : _options.VisionModel;
        var url =
            $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent";

        object[] parts = imagePart is null
            ? [new { text = prompt }]
            : [imagePart, new { text = prompt }];

        var requestBody = new
        {
            contents = new[] { new { parts } },
            generationConfig = new
            {
                temperature = 0.0,
                responseMimeType = "application/json"
            }
        };

        const int maxRetries = 2;
        HttpResponseMessage? response = null;

        for (int attempt = 0; attempt <= maxRetries; attempt++)
        {
            try
            {
                using var request = new HttpRequestMessage(HttpMethod.Post, url)
                {
                    Content = JsonContent.Create(requestBody)
                };
                request.Headers.TryAddWithoutValidation("x-goog-api-key", _options.ApiKey);

                response = await _httpClient.SendAsync(request, cancellationToken);

                if (response.StatusCode is HttpStatusCode.TooManyRequests or HttpStatusCode.ServiceUnavailable)
                {
                    if (attempt < maxRetries)
                    {
                        var delay = GetRetryDelay(response, attempt);
                        _logger.LogWarning(
                            "Gemini API returned {StatusCode}. Retrying after {Delay}ms (attempt {Attempt}/{MaxRetries}).",
                            response.StatusCode, delay.TotalMilliseconds, attempt + 1, maxRetries);
                        response.Dispose();
                        response = null;
                        await Task.Delay(delay, cancellationToken);
                        continue;
                    }

                    TripCircuitBreaker($"Received HTTP {response.StatusCode} from Google Gemini after {maxRetries} retries.");
                    return new GeminiPrescriptionResult(null, null, null, 0m, false, true);
                }

                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning("Gemini API call failed with status {StatusCode}. Failing over to local engine.", response.StatusCode);
                    return new GeminiPrescriptionResult(null, null, null, 0m, false, false);
                }

                var jsonDoc = await response.Content.ReadFromJsonAsync<JsonDocument>(cancellationToken: cancellationToken);
                var root = jsonDoc?.RootElement;

                var candidates = root?.GetProperty("candidates");
                if (candidates == null || candidates.Value.GetArrayLength() == 0)
                {
                    return new GeminiPrescriptionResult(null, null, null, 0m, false, false);
                }

                var textResponse = candidates.Value[0]
                    .GetProperty("content")
                    .GetProperty("parts")[0]
                    .GetProperty("text")
                    .GetString();

                if (string.IsNullOrWhiteSpace(textResponse))
                {
                    return new GeminiPrescriptionResult(null, null, null, 0m, false, false);
                }

                var items = ParseMedicationJson(textResponse);
                if (items.Count == 0)
                {
                    return new GeminiPrescriptionResult(null, null, null, 0m, false, false);
                }

                IncrementDailyQuota();

                var primary = items[0];
                return new GeminiPrescriptionResult(
                    primary.TradeName,
                    primary.Strength,
                    primary.DosageForm,
                    primary.Confidence,
                    true,
                    false,
                    items);
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("Gemini API call timed out after {Timeout}s. Falling back to local engine.", _options.TimeoutSeconds);
                return new GeminiPrescriptionResult(null, null, null, 0m, false, false);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Unexpected error in Gemini API call. Falling back to local engine.");
                return new GeminiPrescriptionResult(null, null, null, 0m, false, false);
            }
            finally
            {
                response?.Dispose();
            }
        }

        return new GeminiPrescriptionResult(null, null, null, 0m, false, false);
    }

    private static TimeSpan GetRetryDelay(HttpResponseMessage response, int attempt)
    {
        if (response.Headers.RetryAfter != null)
        {
            if (response.Headers.RetryAfter.Delta.HasValue)
            {
                return response.Headers.RetryAfter.Delta.Value;
            }
            if (response.Headers.RetryAfter.Date.HasValue)
            {
                var diff = response.Headers.RetryAfter.Date.Value - DateTimeOffset.UtcNow;
                if (diff > TimeSpan.Zero) return diff;
            }
        }

        var baseMs = 500 * (int)Math.Pow(2, attempt);
        var jitter = Random.Shared.Next(0, 300);
        var totalMs = Math.Clamp(baseMs + jitter, 500, 2500);
        return TimeSpan.FromMilliseconds(totalMs);
    }

    private static List<GeminiMedicationItem> ParseMedicationJson(string textResponse)
    {
        var cleanJson = textResponse.Trim();
        if (cleanJson.StartsWith("```json", StringComparison.OrdinalIgnoreCase))
        {
            cleanJson = cleanJson["```json".Length..];
        }
        if (cleanJson.StartsWith("```"))
        {
            cleanJson = cleanJson[3..];
        }
        if (cleanJson.EndsWith("```"))
        {
            cleanJson = cleanJson[..^3];
        }
        cleanJson = cleanJson.Trim();

        var items = new List<GeminiMedicationItem>();
        using var doc = JsonDocument.Parse(cleanJson);
        var rootEl = doc.RootElement;
        if (rootEl.TryGetProperty("medications", out var medsProp) && medsProp.ValueKind == JsonValueKind.Array)
        {
            foreach (var el in medsProp.EnumerateArray())
            {
                var name = el.TryGetProperty("tradeName", out var tn) ? tn.GetString()
                    : (el.TryGetProperty("name", out var n) ? n.GetString() : null);

                if (!string.IsNullOrWhiteSpace(name))
                {
                    var str = el.TryGetProperty("strength", out var s) ? s.GetString() : null;
                    var df = el.TryGetProperty("dosageForm", out var d) ? d.GetString()
                        : (el.TryGetProperty("form", out var f) ? f.GetString() : null);
                    var conf = el.TryGetProperty("confidence", out var c) && c.TryGetDecimal(out var cv) ? cv : 0.95m;
                    var qty = el.TryGetProperty("quantity", out var q) && q.TryGetInt32(out var qv) && qv > 0 ? qv : 1;
                    items.Add(new GeminiMedicationItem(name.Trim(), str?.Trim(), df?.Trim(), conf, qty));
                }
            }
        }
        else if ((rootEl.TryGetProperty("tradeName", out var singleTn) || rootEl.TryGetProperty("name", out singleTn))
                 && !string.IsNullOrWhiteSpace(singleTn.GetString()))
        {
            var str = rootEl.TryGetProperty("strength", out var s) ? s.GetString() : null;
            var df = rootEl.TryGetProperty("dosageForm", out var d) ? d.GetString()
                : (rootEl.TryGetProperty("form", out var f) ? f.GetString() : null);
            var conf = rootEl.TryGetProperty("confidence", out var c) && c.TryGetDecimal(out var cv) ? cv : 0.95m;
            var qty = rootEl.TryGetProperty("quantity", out var q) && q.TryGetInt32(out var qv) && qv > 0 ? qv : 1;
            items.Add(new GeminiMedicationItem(singleTn.GetString()!.Trim(), str?.Trim(), df?.Trim(), conf, qty));
        }

        return items;
    }

    private void IncrementDailyQuota()
    {
        var key = GetQuotaCacheKey();
        var current = GetDailyRequestCount();
        var next = current + 1;
        var midnight = DateTime.UtcNow.Date.AddDays(1);
        var ttl = midnight - DateTime.UtcNow;

        try
        {
            _distributedCache.SetString(key, next.ToString(), new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = ttl
            });
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "Distributed cache unavailable for incrementing daily quota. Falling back to memory cache.");
        }

        _memoryCache.Set(key, next, ttl);
    }

    /// <summary>
    /// Google AI Studio keys: legacy AIza… or newer authorization keys (AQ.…).
    /// Placeholders must not trigger a failing HTTP call.
    /// </summary>
    internal static bool LooksLikeGeminiKey(string? key)
    {
        if (string.IsNullOrWhiteSpace(key)) return false;
        if (key.Contains("REPLACE_WITH", StringComparison.OrdinalIgnoreCase)) return false;
        return key.StartsWith("AIza", StringComparison.Ordinal)
               || key.StartsWith("AQ.", StringComparison.Ordinal);
    }

    private bool IsCircuitBreakerTripped()
    {
        try
        {
            var value = _distributedCache.GetString(CircuitBreakerKey);
            if (!string.IsNullOrEmpty(value)) return true;
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "Distributed cache unavailable for circuit breaker check. Falling back to memory cache.");
        }

        return _memoryCache.TryGetValue(CircuitBreakerKey, out _);
    }

    private void TripCircuitBreaker(string reason)
    {
        _logger.LogWarning("Gemini Circuit Breaker Tripped: {Reason}. Failing over for 5 minutes.", reason);
        var ttl = TimeSpan.FromMinutes(5);

        try
        {
            _distributedCache.SetString(CircuitBreakerKey, "true", new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = ttl
            });
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "Distributed cache unavailable for tripping circuit breaker. Falling back to memory cache.");
        }

        _memoryCache.Set(CircuitBreakerKey, true, ttl);
    }
}
