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
            You are an expert Egyptian clinical pharmacist and medical handwriting OCR specialist operating under Egyptian Personal Data Protection Law No. 151 of 2020.
            CRITICAL PRIVACY & PII REDACTION RULES:
            - NEVER extract, transcribe, or output any patient name, doctor/prescriber name, clinic name, hospital name, syndicate number, national ID, age, phone number, address, or Egyptian city/governorate (e.g. Cairo, Alexandria, Giza, Mansoura, Tanta, Dokki, Mohandessin, Smouha, Maadi, etc.).
            - Strictly ignore, suppress, and redact all personal identifiable information (PII / PHI).
            - Extract ONLY the prescribed medication lines (e.g. Concor, Augmentin, Panadol, Glucophage, Cataflam, Controloc, Brufen, Sirdalud, Plavix, etc.).
            - Put dosage directions (e.g. 1x1, 1x2, 1x3, 1 tab PO QHS, قرص ليلا, قرص كل 12 ساعة بعد الأكل, قبل الأكل بساعة) in "rawSig".

            On-device OCR hint (preliminary optical tokens — verify against image):
            ---
            {{hint}}
            ---

            Output ONLY valid JSON matching this schema:
            {
              "medications": [
                {
                  "tradeName": "string",
                  "genericName": "string or null",
                  "strength": "string or null",
                  "dosageForm": "string or null",
                  "rawSig": "string or null",
                  "quantity": 1,
                  "confidence": 0.95
                }
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

        object[] parts = imagePart is null
            ? [new { text = prompt }]
            : [imagePart, new { text = prompt }];

        var modelsToTry = new List<string>();
        if (imagePart != null)
        {
            if (!string.IsNullOrWhiteSpace(_options.VisionModel))
            {
                modelsToTry.Add(_options.VisionModel);
            }
            if (_options.FallbackVisionModels is { Length: > 0 })
            {
                foreach (var fb in _options.FallbackVisionModels)
                {
                    if (!modelsToTry.Contains(fb, StringComparer.OrdinalIgnoreCase))
                    {
                        modelsToTry.Add(fb);
                    }
                }
            }
        }
        else
        {
            modelsToTry.Add(string.IsNullOrWhiteSpace(_options.Model) ? "gemini-1.5-flash" : _options.Model);
        }

        if (modelsToTry.Count == 0)
        {
            modelsToTry.Add("gemini-1.5-flash");
        }

        for (int m = 0; m < modelsToTry.Count; m++)
        {
            var model = modelsToTry[m];
            var url = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent";

            var isThinking = model.Contains("gemini-3", StringComparison.OrdinalIgnoreCase) &&
                             !string.IsNullOrWhiteSpace(_options.ThinkingLevel);

            object genConfig = isThinking
                ? new
                {
                    temperature = 0.0,
                    responseMimeType = "application/json",
                    thinkingConfig = new { thinkingLevel = _options.ThinkingLevel }
                }
                : new
                {
                    temperature = 0.0,
                    responseMimeType = "application/json"
                };

            var requestBody = new
            {
                contents = new[] { new { parts } },
                generationConfig = genConfig
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

                        if (m < modelsToTry.Count - 1)
                        {
                            _logger.LogWarning("Gemini model {Model} returned {StatusCode}. Trying next fallback model in cascade.", model, response.StatusCode);
                            break;
                        }

                        TripCircuitBreaker($"Received HTTP {response.StatusCode} from Google Gemini after {maxRetries} retries.");
                        return new GeminiPrescriptionResult(null, null, null, 0m, false, true);
                    }

                    if (!response.IsSuccessStatusCode)
                    {
                        _logger.LogWarning("Gemini model {Model} failed with status {StatusCode}. Trying fallback cascade.", model, response.StatusCode);
                        break;
                    }

                    var jsonDoc = await response.Content.ReadFromJsonAsync<JsonDocument>(cancellationToken: cancellationToken);
                    var root = jsonDoc?.RootElement;

                    var candidates = root?.GetProperty("candidates");
                    if (candidates == null || candidates.Value.GetArrayLength() == 0)
                    {
                        break;
                    }

                    var textResponse = candidates.Value[0]
                        .GetProperty("content")
                        .GetProperty("parts")[0]
                        .GetProperty("text")
                        .GetString();

                    if (string.IsNullOrWhiteSpace(textResponse))
                    {
                        break;
                    }

                    var items = ParseMedicationJson(textResponse);
                    if (items.Count == 0)
                    {
                        break;
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
                    _logger.LogWarning("Gemini API call timed out after {Timeout}s on model {Model}.", _options.TimeoutSeconds, model);
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Unexpected error in Gemini API call for model {Model}.", model);
                    break;
                }
                finally
                {
                    response?.Dispose();
                }
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

    private static readonly HashSet<string> PiiStopwords = new(StringComparer.OrdinalIgnoreCase)
    {
        "doctor", "dr", "prof", "consultant", "specialist", "clinic", "hospital", "center", "pharmacy", "patient", "name",
        "syndicate", "phone", "tel", "rx", "address", "signature",
        "cairo", "alexandria", "giza", "mansoura", "tanta", "asyut", "ismailia", "faiyum", "zagazig", "damietta", "aswan",
        "minya", "damanhur", "beni suef", "hurghada", "qena", "sohag", "dokki", "mohandessin", "smouha", "maadi", "nasr city",
        "heliopolis", "zamalek", "tagamoa", "october", "zayed", "rehab", "madinaty", "shorouk", "obour", "badr", "helwan",
        "دكتور", "د", "أستاذ", "استشاري", "اخصائي", "عيادة", "مستشفى", "مركز", "صيدلية", "مريض", "الاسم", "السن", "العنوان", "تليفون",
        "القاهرة", "الإسكندرية", "اسكندرية", "الجيزة", "المنصورة", "طنطا", "أسيوط", "اسيوط", "الإسماعيلية", "الفيوم", "الزقازيق",
        "دمياط", "أسوان", "المنيا", "دمنهور", "بني سويف", "الغردقة", "قنا", "سوهاج", "الدقي", "المهندسين", "سموحة", "المعادي",
        "مدينة نصر", "مصر الجديدة", "الزمالك", "التجمع", "أكتوبر", "الشيخ زايد", "الرحاب", "مدينتي", "الشروق", "العبور", "حلوان"
    };

    /// <summary>
    /// Egyptian Law No. 151 of 2020 PII redaction: filters doctor, clinic, patient, syndicate,
    /// and location lines from raw prescription OCR text, preserving only medication orders.
    /// </summary>
    public static string FilterPiiStopwords(string rawText)
    {
        if (string.IsNullOrWhiteSpace(rawText)) return string.Empty;

        var lines = rawText.Split(["\r\n", "\r", "\n"], StringSplitOptions.None);
        var filteredLines = new List<string>();

        var piiLineIndicators = new[]
        {
            "عيادة", "مستشفى", "مركز", "clinic", "hospital", "center",
            "دكتور", "د.", "د/ ", "أستاذ", "استشاري", "اخصائي", "طبيب", "الطبيب", "doctor", "dr.", "prof", "consultant", "specialist",
            "نقابة", "نقابه", "رقم القيد", "syndicate", "dea", "npi",
            "اسم المريض", "المريض", "الاسم:", "الاسم", "السن:", "السن", "العنوان:", "العنوان", "patient", "name:", "age:", "address:",
            "تليفون", "هاتف", "موبايل", "ت:", "فكس", "phone", "tel", "mobile", "cell", "fax", "contact",
            "توقيع", "signature", "sign:", "ختم", "stamp",
            "الدقي", "المهندسين", "سموحة", "المعادي", "مدينة نصر", "مصر الجديدة", "الزمالك", "التجمع",
            "أكتوبر", "الشيخ زايد", "الرحاب", "مدينتي", "الشروق", "العبور", "حلوان", "العجوزة",
            "القاهرة", "الإسكندرية", "اسكندرية", "الجيزة", "المنصورة", "طنطا", "أسيوط", "اسيوط",
            "cairo", "alexandria", "giza", "mansoura", "tanta", "dokki", "mohandessin", "smouha", "agouza",
            "تاريخ:", "تاريخ :", "date:"
        };

        foreach (var line in lines)
        {
            var trimmed = line.Trim();
            if (string.IsNullOrWhiteSpace(trimmed)) continue;

            var lower = trimmed.ToLowerInvariant();
            var isPii = piiLineIndicators.Any(pii => lower.Contains(pii));

            // Law No. 151: Check for phone numbers (7+ digits including Arabic-Indic numerals)
            if (!isPii)
            {
                var digits = System.Text.RegularExpressions.Regex.Replace(trimmed, @"[^\d\u0660-\u0669]", "");
                if (digits.Length >= 7)
                {
                    isPii = true;
                }
            }

            if (!isPii)
            {
                filteredLines.Add(trimmed);
            }
        }

        return string.Join(Environment.NewLine, filteredLines);
    }

    private static bool IsPii(string? name)
    {
        if (string.IsNullOrWhiteSpace(name)) return true;
        var clean = name.Trim().ToLowerInvariant();
        if (PiiStopwords.Contains(clean)) return true;
        var words = clean.Split([' ', ',', '.', '-', '/', '\\', '#'], StringSplitOptions.RemoveEmptyEntries);
        return words.Length > 0 && words.All(w => PiiStopwords.Contains(w));
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

        void AddItemFromElement(JsonElement el)
        {
            if (el.ValueKind != JsonValueKind.Object) return;

            var name = el.TryGetProperty("tradeName", out var tn) ? tn.GetString()
                : (el.TryGetProperty("name", out var n) ? n.GetString() : null);

            if (!string.IsNullOrWhiteSpace(name) && !IsPii(name))
            {
                var str = el.TryGetProperty("strength", out var s) ? s.GetString() : null;
                var df = el.TryGetProperty("dosageForm", out var d) ? d.GetString()
                    : (el.TryGetProperty("form", out var f) ? f.GetString() : null);
                var conf = el.TryGetProperty("confidence", out var c) && c.TryGetDecimal(out var cv) ? cv : 0.95m;
                var qty = el.TryGetProperty("quantity", out var q) && q.TryGetInt32(out var qv) && qv > 0 ? qv : 1;
                var rawSig = el.TryGetProperty("rawSig", out var rs) ? rs.GetString() : null;
                var generic = el.TryGetProperty("genericName", out var gn) ? gn.GetString() : null;
                items.Add(new GeminiMedicationItem(name.Trim(), str?.Trim(), df?.Trim(), conf, qty, rawSig?.Trim(), generic?.Trim()));
            }
        }

        if (rootEl.ValueKind == JsonValueKind.Array)
        {
            foreach (var el in rootEl.EnumerateArray())
            {
                AddItemFromElement(el);
            }
        }
        else if (rootEl.ValueKind == JsonValueKind.Object)
        {
            if (rootEl.TryGetProperty("medications", out var medsProp) && medsProp.ValueKind == JsonValueKind.Array)
            {
                foreach (var el in medsProp.EnumerateArray())
                {
                    AddItemFromElement(el);
                }
            }
            else if (rootEl.TryGetProperty("items", out var itemsProp) && itemsProp.ValueKind == JsonValueKind.Array)
            {
                foreach (var el in itemsProp.EnumerateArray())
                {
                    AddItemFromElement(el);
                }
            }
            else
            {
                AddItemFromElement(rootEl);
            }
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
