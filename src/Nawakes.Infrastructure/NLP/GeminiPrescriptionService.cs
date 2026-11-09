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
            - Extract ONLY the prescribed medications (e.g. Concor, Augmentin, Lipitor, Glucophage, Cataflam, Controloc, Panadol, Otrivin).
            - For each medication identify:
              1. tradeName: Official Egyptian brand/trade name (NEVER put a doctor or clinic name here!).
              2. strength: Dosage strength if present (e.g. 5mg, 10mg, 1000mg, 1g, 50mg, 0.1%, 0.05%).
              3. dosageForm: EXACT clinical dosage form. NEVER label drops, liquids, sprays, or topicals as 'Tablet' or 'قرص'!
                 Allowed forms: 'نقط للأنف' (Nasal Drops), 'قطرة للعين' (Eye Drops), 'قطرة للأذن' (Ear Drops), 'نقط بالفم' (Oral Drops), 'شراب' (Syrup), 'معلق' (Suspension), 'بخاخ' (Spray/Inhaler), 'مرهم' (Ointment), 'كريم' (Cream), 'جل' (Gel), 'حقن / أمبول' (Injection/Ampoule), 'لبوس' (Suppository), 'فوار' (Effervescent), 'أقراص' (Tablets), 'كبسولات' (Capsules).
              4. rawSig: Full dosage directions with the correct clinical route:
                 * Nasal drops/sprays (e.g. Otrivin, Afrin, Nasivin) MUST specify 'في الأنف' / 'نقط بالأنف' (NEVER 'في الفم'!).
                 * Eye drops/ointments (e.g. Tobradex, Tobrex, Systane) MUST specify 'في العين'.
                 * Ear drops (e.g. Otal, Viotic) MUST specify 'في الأذن'.
                 * Syrups/suspensions MUST specify spoonful/mL ('ملعقة' or 'سم'), NEVER 'قرص'.
              5. quantity: Number of packs or count if indicated (e.g. 1, 2, 3), default to 1.
              6. confidence: Confidence score between 0.0 and 1.0.

            PRESCRIPTION TEXT TO DECIPHER:
            ---
            {{rawText}}
            ---

            Output ONLY valid JSON matching this exact structure:
            {
              "medications": [
                {"tradeName": "string", "strength": "string or null", "dosageForm": "string or null", "rawSig": "string or null", "quantity": 1, "confidence": 0.95}
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
            - Extract ONLY the prescribed medication lines (e.g. Concor, Augmentin, Panadol, Glucophage, Cataflam, Controloc, Brufen, Sirdalud, Plavix, Otrivin, etc.).

            CRITICAL CLINICAL PHARMACOLOGY & ROUTE INVARIANTS:
            - Accurately determine the true dosageForm:
              * Drops (نقط/قطرة):
                - Nasal Drops (e.g. Otrivin, Afrin, Nasivin, Rhinocort, Xylometazoline, Physiomer, Sinomarin) -> dosageForm: 'نقط للأنف' or 'بخاخ أنفي'. Route in rawSig MUST be nasal ('في الأنف' / 'نقط بالأنف' / 'في كل فتحة أنف'), NEVER oral ('في الفم') and NEVER 'قرص'!
                - Eye Drops (e.g. Tobradex, Tobrex, Vigamox, Systane, Tears Guard, Polyfresh, Fresh Tears, Ciprocin) -> dosageForm: 'قطرة للعين'. Route in rawSig: 'في العين'.
                - Ear Drops (e.g. Otal, Viotic, Otocalm, Waxsol) -> dosageForm: 'قطرة للأذن'. Route in rawSig: 'في الأذن'.
                - Oral Drops (e.g. Vi-Syneral, Cebion, Iron drops) -> dosageForm: 'نقط بالفم'.
              * Syrups & Suspensions (e.g. Megamox susp, Catafly, Augmentin syrup, Brufen syrup) -> dosageForm: 'شراب' or 'معلق'. Units in rawSig: 'ملعقة' or 'سم' / 'مل' (NEVER 'قرص'!).
              * Inhalers & Sprays (e.g. Ventolin, Symbicort, Seretide) -> dosageForm: 'بخاخ استنشاق'. Units in rawSig: 'بخة'.
              * Topicals (e.g. Betnovate, Fucidin, Kenacomb, Mebo, Daktarin, Voltaren Emulgel) -> dosageForm: 'مرهم' / 'كريم' / 'جل'. Route: 'دهان موضعي'.
              * Suppositories (e.g. Dolphin, Cetal supp) -> dosageForm: 'لبوس'.
              * Injections (e.g. Cefotax, Ceftriaxone, Voltaren amp) -> dosageForm: 'حقن / أمبول'.
              * Tablets/Capsules (e.g. Concor tab, Panadol tab, Augmentin 1g tab, Omeprazole cap) -> dosageForm: 'أقراص' or 'كبسولات'.
            - Put complete dosage directions reflecting the true dosage form and anatomical route in 'rawSig'.

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

                    if (root == null || !root.Value.TryGetProperty("candidates", out var candidates) || candidates.GetArrayLength() == 0)
                    {
                        _logger.LogWarning("Gemini model {Model} returned response with no candidates.", model);
                        break;
                    }

                    string? textResponse = null;
                    if (candidates[0].TryGetProperty("content", out var contentEl) &&
                        contentEl.TryGetProperty("parts", out var partsEl) &&
                        partsEl.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var part in partsEl.EnumerateArray())
                        {
                            if (part.TryGetProperty("text", out var textEl) && !string.IsNullOrWhiteSpace(textEl.GetString()))
                            {
                                textResponse = textEl.GetString();
                                break;
                            }
                        }
                    }

                    if (string.IsNullOrWhiteSpace(textResponse))
                    {
                        _logger.LogWarning("Gemini model {Model} returned empty text in candidate content parts.", model);
                        break;
                    }

                    var items = ParseMedicationJson(textResponse);
                    if (items.Count == 0)
                    {
                        _logger.LogWarning("Gemini model {Model} output could not be parsed into medications: {Text}", model, textResponse);
                        break;
                    }

                    IncrementDailyQuota();

                    var primary = items[0];
                    _logger.LogInformation("Gemini model {Model} successfully extracted {Count} medications in Tier 1. Primary: {Primary}",
                        model, items.Count, primary.TradeName);
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

        // Extract JSON structure if model output included surrounding prose
        var firstBrace = cleanJson.IndexOfAny(['{', '[']);
        var lastBrace = cleanJson.LastIndexOfAny(['}', ']']);
        if (firstBrace >= 0 && lastBrace > firstBrace)
        {
            cleanJson = cleanJson.Substring(firstBrace, lastBrace - firstBrace + 1);
        }

        var items = new List<GeminiMedicationItem>();
        try
        {
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
                    (df, rawSig) = SanitizeClinicalFormAndRoute(name, df, rawSig);
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
        }
        catch (JsonException)
        {
            // Malformed JSON handled gracefully
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

    /// <summary>
    /// Clinical Pharmacology Sanitizer for Egyptian medications:
    /// Enforces anatomical routes and correct dosage forms so that nasal drops (e.g. Otrivin)
    /// never get routed to oral ingestion or labeled as tablets/قرص, and syrups are never 'tablets'.
    /// </summary>
    internal static (string? Form, string? Sig) SanitizeClinicalFormAndRoute(string name, string? form, string? sig)
    {
        var cleanName = name.Trim().ToLowerInvariant();
        var cleanSig = sig?.Trim() ?? string.Empty;
        var cleanForm = form?.Trim();

        // 1. Nasal drops & sprays (Otrivin, Afrin, Nasivin, Rhinocort, Physiomer, Sinomarin, Xylometazoline, etc.)
        if (cleanName.Contains("otrivin") || cleanName.Contains("afrin") || cleanName.Contains("nasivin") ||
            cleanName.Contains("rhinocort") || cleanName.Contains("physiomer") || cleanName.Contains("sinomarin") ||
            cleanName.Contains("xylometazoline") || cleanName.Contains("اوترفين") || cleanName.Contains("افرين") ||
            cleanName.Contains("نازيفين") || cleanName.Contains("رينوكورت") || cleanName.Contains("فيزيومير") ||
            cleanName.Contains("أنف") || cleanName.Contains("انف") || cleanName.Contains("nasal"))
        {
            cleanForm = cleanForm == null || cleanForm.Contains("قرص") || cleanForm.Contains("tab", StringComparison.OrdinalIgnoreCase)
                ? "نقط للأنف"
                : cleanForm;

            if (string.IsNullOrWhiteSpace(cleanSig) || cleanSig.Contains("فم") || cleanSig.Contains("قرص") || cleanSig.Contains("po", StringComparison.OrdinalIgnoreCase))
            {
                cleanSig = "نقطتان في كل فتحة أنف عند اللزوم (أو كل 8 ساعات)";
            }
            else if (!cleanSig.Contains("أنف") && !cleanSig.Contains("انف"))
            {
                cleanSig = $"{cleanSig} (نقط بالأنف)";
            }
            return (cleanForm, cleanSig);
        }

        // 2. Ophthalmic / Eye Drops (Tobradex, Tobrex, Vigamox, Systane, Tears Guard, Polyfresh, Fresh Tears, Ciprocin, etc.)
        if (cleanName.Contains("tobradex") || cleanName.Contains("tobrex") || cleanName.Contains("vigamox") ||
            cleanName.Contains("systane") || cleanName.Contains("tears guard") || cleanName.Contains("polyfresh") ||
            cleanName.Contains("fresh tears") || cleanName.Contains("ciprocin") || cleanName.Contains("توبارادكس") ||
            cleanName.Contains("توبركس") || cleanName.Contains("فيجاموكس") || cleanName.Contains("سيستين") ||
            cleanName.Contains("تيرز جارد") || cleanName.Contains("بولي فريش") || cleanName.Contains("عين") || cleanName.Contains("eye"))
        {
            cleanForm = cleanForm == null || cleanForm.Contains("قرص") || cleanForm.Contains("tab", StringComparison.OrdinalIgnoreCase)
                ? "قطرة للعين"
                : cleanForm;

            if (string.IsNullOrWhiteSpace(cleanSig) || cleanSig.Contains("فم") || cleanSig.Contains("قرص") || cleanSig.Contains("po", StringComparison.OrdinalIgnoreCase))
            {
                cleanSig = "نقطة في كل عين 3 مرات يومياً";
            }
            else if (!cleanSig.Contains("عين"))
            {
                cleanSig = $"{cleanSig} (في العين)";
            }
            return (cleanForm, cleanSig);
        }

        // 3. Otic / Ear Drops (Otal, Viotic, Otocalm, Waxsol, etc.)
        if (cleanName.Contains("otal") || cleanName.Contains("viotic") || cleanName.Contains("otocalm") ||
            cleanName.Contains("waxsol") || cleanName.Contains("اوتال") || cleanName.Contains("فيوتيك") ||
            cleanName.Contains("اوتوكالم") || cleanName.Contains("أذن") || cleanName.Contains("اذن") || cleanName.Contains("ear"))
        {
            cleanForm = cleanForm == null || cleanForm.Contains("قرص") || cleanForm.Contains("tab", StringComparison.OrdinalIgnoreCase)
                ? "قطرة للأذن"
                : cleanForm;

            if (string.IsNullOrWhiteSpace(cleanSig) || cleanSig.Contains("فم") || cleanSig.Contains("قرص") || cleanSig.Contains("po", StringComparison.OrdinalIgnoreCase))
            {
                cleanSig = "نقطتان في الأذن المصابة 3 مرات يومياً";
            }
            else if (!cleanSig.Contains("أذن") && !cleanSig.Contains("اذن"))
            {
                cleanSig = $"{cleanSig} (في الأذن)";
            }
            return (cleanForm, cleanSig);
        }

        // 4. Oral Drops for infants (Vi-Syneral, Cebion, etc.)
        if (cleanName.Contains("vi-syneral") || cleanName.Contains("cebion") || cleanName.Contains("في سينرال") || cleanName.Contains("سيبيون"))
        {
            cleanForm = "نقط بالفم";
            if (string.IsNullOrWhiteSpace(cleanSig) || cleanSig.Contains("قرص"))
            {
                cleanSig = "نقط بالفم يومياً حسب الجرعة الموصوفة";
            }
            return (cleanForm, cleanSig);
        }

        // 5. Syrups & Suspensions (Megamox syrup, Catafly, Augmentin syrup, Brufen syrup, etc.)
        if (cleanName.Contains("syrup") || cleanName.Contains("susp") || cleanName.Contains("شراب") || cleanName.Contains("معلق") ||
            cleanName.Contains("catafly") || cleanName.Contains("كتافلاي"))
        {
            cleanForm = cleanForm == null || cleanForm.Contains("قرص") || cleanForm.Contains("tab", StringComparison.OrdinalIgnoreCase)
                ? "شراب / معلق"
                : cleanForm;

            if (!string.IsNullOrWhiteSpace(cleanSig) && cleanSig.Contains("قرص"))
            {
                cleanSig = cleanSig.Replace("أقراص", "ملاعق").Replace("قرصين", "ملعقتين (10 سم)").Replace("قرص", "ملعقة (5 سم)");
            }
            return (cleanForm, cleanSig);
        }

        // 6. Topicals (Creams / Ointments / Gels)
        if (cleanName.Contains("cream") || cleanName.Contains("ointment") || cleanName.Contains("gel") ||
            cleanName.Contains("كريم") || cleanName.Contains("مرهم") || cleanName.Contains("جل") ||
            cleanName.Contains("fucidin") || cleanName.Contains("kenacomb") || cleanName.Contains("mebo") ||
            cleanName.Contains("betnovate") || cleanName.Contains("daktarin") || cleanName.Contains("فيوسيدين") ||
            cleanName.Contains("كيناكومب") || cleanName.Contains("ميبو") || cleanName.Contains("بيتنوفيت") || cleanName.Contains("داكتارين"))
        {
            cleanForm = cleanForm == null || cleanForm.Contains("قرص") || cleanForm.Contains("tab", StringComparison.OrdinalIgnoreCase)
                ? "مرهم / كريم"
                : cleanForm;

            if (string.IsNullOrWhiteSpace(cleanSig) || cleanSig.Contains("فم") || cleanSig.Contains("قرص") || cleanSig.Contains("po", StringComparison.OrdinalIgnoreCase))
            {
                cleanSig = "دهان موضعي على المنطقة المصابة مرتين إلى 3 مرات يومياً";
            }
            return (cleanForm, cleanSig);
        }

        // 7. Prevent incorrect "قرص" labeling if form is drops/syrup
        if ((cleanForm != null && (cleanForm.Contains("نقط") || cleanForm.Contains("قطر") || cleanForm.Contains("drop") || cleanForm.Contains("syrup") || cleanForm.Contains("شراب"))) &&
            !string.IsNullOrWhiteSpace(cleanSig) && cleanSig.Contains("قرص"))
        {
            if (cleanForm.Contains("نقط") || cleanForm.Contains("قطر") || cleanForm.Contains("drop"))
            {
                cleanSig = cleanSig.Replace("أقراص", "نقط").Replace("قرصين", "نقطتين").Replace("قرص", "نقطة واحدة");
            }
            else
            {
                cleanSig = cleanSig.Replace("أقراص", "ملاعق").Replace("قرصين", "ملعقتين (10 سم)").Replace("قرص", "ملعقة (5 سم)");
            }
        }

        return (cleanForm, cleanSig);
    }
}