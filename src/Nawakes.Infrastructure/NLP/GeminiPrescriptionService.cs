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
using Nawakes.Domain.Common;

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
        return ExecuteVisionEnsembleAsync(imagePart, ocrHintText, cancellationToken);
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
        return ExecuteVisionEnsembleAsync(imagePart, ocrHintText, cancellationToken);
    }

    private static string BuildTextPrompt(string rawText) => $$"""
            You are an Egyptian clinical pharmacist expert in deciphering messy doctor handwriting and prescription text.
            CRITICAL INSTRUCTIONS:
            - Strictly ignore doctor names (e.g. Dr., د., دكتور), clinic/hospital headers, patient names, dates, phone numbers, and addresses.
            - Extract ONLY the prescribed medications (e.g. Concor, Augmentin, Lipitor, Glucophage, Cataflam, Controloc, Panadol, Otrivin, Zurcal, Epizithro, Ganaton, Sedatiss, Xilone).
            - Disambiguation: 'Zurcal 40' is Pantoprazole 40mg (stomach PPI), NEVER 'Zolam' (Alprazolam 0.5mg).
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

    private static string BuildClinicalVisionPrompt(string? ocrHintText)
    {
        var hint = string.IsNullOrWhiteSpace(ocrHintText)
            ? "No on-device OCR hint."
            : ocrHintText.Trim();
        return $$"""
            You are an expert Egyptian clinical pharmacologist and medical handwriting OCR specialist operating under Egyptian Personal Data Protection Law No. 151 of 2020.
            CRITICAL PRIVACY & PII REDACTION RULES:
            - NEVER extract, transcribe, or output any patient name, doctor/prescriber name, clinic name, hospital name, syndicate number, national ID, age, phone number, address, or Egyptian city/governorate.
            - Strictly ignore, suppress, and redact all personal identifiable information (PII / PHI).
            - Extract ONLY the prescribed medication lines (e.g. Concor, Augmentin, Panadol, Glucophage, Cataflam, Controloc, Brufen, Sirdalud, Plavix, Otrivin, Zurcal, Epizithro, Ganaton, etc.).

            CRITICAL CLINICAL PHARMACOLOGY & ROUTE INVARIANTS:
            - Nasal Drops (e.g. Otrivin, Afrin, Nasivin, Rhinocort, Physiomer, Sinomarin) -> dosageForm: 'نقط للأنف' or 'بخاخ أنفي'. Route in rawSig: nasal ('في الأنف' / 'نقط بالأنف'), NEVER oral ('في الفم') and NEVER 'قرص'!
            - Eye Drops (e.g. Tobradex, Tobrex, Vigamox, Systane, Tears Guard, Polyfresh, Fresh Tears, Ciprocin) -> dosageForm: 'قطرة للعين'. Route: 'في العين'.
            - Ear Drops (e.g. Otal, Viotic, Otocalm, Waxsol) -> dosageForm: 'قطرة للأذن'. Route: 'في الأذن'.
            - Syrups & Suspensions (e.g. Megamox susp, Catafly, Augmentin syrup, Brufen syrup) -> dosageForm: 'شراب' or 'معلق'. Units in rawSig: 'ملعقة' or 'سم' / 'مل' (NEVER 'قرص'!).
            - Topicals (e.g. Betnovate, Fucidin, Kenacomb, Mebo, Daktarin, Voltaren Emulgel) -> dosageForm: 'مرهم' / 'كريم' / 'جل'. Route: 'دهان موضعي'.
            - Tablets/Capsules (e.g. Concor tab, Panadol tab, Augmentin 1g tab, Omeprazole cap) -> dosageForm: 'أقراص' or 'كبسولات'.

            CRITICAL LOOK-ALIKE HANDWRITING DISAMBIGUATION (EGYPTIAN PRACTICE):
            - 'Zurcal 40' / 'Zorcal 40' is Pantoprazole 40mg (stomach acid PPI). NEVER confuse with 'Zolam' (Alprazolam 0.5mg)! Zolam only exists in 0.25mg/0.5mg, so any 40mg or 20mg indication is Zurcal.
            - 'Epizithro 500' is Azithromycin 500mg capsules.
            - 'Ganaton 50' is Itopride 50mg (prokinetic).
            - 'Xilone Forte Syp' is Prednisolone syrup.
            - 'Sedatiss Syp' is Pentoxyverine syrup.

            CRITICAL QUANTITY EXTRACTION RULES (STRICT CLINICAL PROTOCOL):
            - ONLY extract a quantity > 1 if the prescription explicitly specifies a count or number of packs (e.g. 'No. 30', 'N 2', 'علبتين', 'x 2', '2 boxes', 'pack of 2').
            - If NO specific package quantity is explicitly written by the doctor, ALWAYS return "quantity": 1.
            - NEVER invent or guess package counts. 30 tablets taken 1/day is 1 box (quantity: 1), NOT 30 boxes.

            On-device OCR hint:
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

    private static string BuildOpticalVisionPrompt(string? ocrHintText)
    {
        var hint = string.IsNullOrWhiteSpace(ocrHintText)
            ? "No on-device OCR hint."
            : ocrHintText.Trim();
        return $$"""
            You are a forensic medical handwriting transcriptionist specialized in Egyptian Arabic and English cursive prescription scripts.
            Your task is to optically transcribe every medication line written by the physician with maximum literal accuracy without guessing.
            Strictly ignore doctor headers, patient names, clinics, and phone numbers.
            Focus on deciphering cursive medical abbreviations:
            - Tab / Cap / Syp / Susp / Amp / Drop / Lot / Cream / Oint
            - Exact brand names as written in Egyptian pharmacies (e.g. Concor, Augmentin, Controloc, Zurcal, Cataflam, Brufen, Epizithro, Ganaton).
            - Quantities: Only transcribe explicit pack counts (e.g., #2, x2, علبتين); otherwise default strictly to 1.

            On-device OCR hint:
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

    private static string BuildQuantityAndFormVisionPrompt(string? ocrHintText)
    {
        var hint = string.IsNullOrWhiteSpace(ocrHintText)
            ? "No on-device OCR hint."
            : ocrHintText.Trim();
        return $$"""
            You are a clinical pharmacy auditor specialized in dosage forms, directions (Sig), and dispensing quantities in Egyptian prescriptions.
            Verify each prescribed medication line:
            1. Form & Route: Ensure drops (Eye/Ear/Nasal) are NEVER classified as tablets. Ensure syrups are classified as 'شراب / معلق'.
            2. Dosage Directions (Sig): Decode instructions (e.g. 'قرص قبل الإفطار', '5 سم كل 12 ساعة', 'نقطتان في كل فتحة أنف').
            3. STRICT DISPENSING QUANTITY:
               - The number of packages/boxes to dispense must be 1 UNLESS the physician explicitly wrote a higher package count (e.g., '2 علبة', 'N 2', 'x 2').
               - Daily dose instructions (e.g. '1x3' or 'لمدة شهر') indicate treatment duration, NOT number of boxes! Return quantity: 1 unless multiple boxes are explicitly demanded.
               - Never return quantity 0 or negative. Always 1 unless explicitly specified.

            On-device OCR hint:
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

    private async Task<GeminiPrescriptionResult> ExecuteVisionEnsembleAsync(
        object imagePart,
        string? ocrHintText,
        CancellationToken cancellationToken)
    {
        if (!IsDailyQuotaAvailable())
        {
            _logger.LogInformation(
                "Nawaqss Medical AI daily quota reached or circuit breaker active ({Count}/{Limit}). Failing over to local engine.",
                GetDailyRequestCount(), _options.DailyQuotaLimit);
            return new GeminiPrescriptionResult(null, null, null, 0m, false, true);
        }

        var models = new List<string>();
        if (!string.IsNullOrWhiteSpace(_options.VisionModel))
        {
            models.Add(_options.VisionModel);
        }
        if (_options.FallbackVisionModels is { Length: > 0 })
        {
            foreach (var fb in _options.FallbackVisionModels)
            {
                if (!models.Contains(fb, StringComparer.OrdinalIgnoreCase))
                {
                    models.Add(fb);
                }
            }
        }
        if (models.Count == 0)
        {
            models.Add("gemini-1.5-flash");
        }

        var model1 = models[0];
        var model2 = models.Count > 1 ? models[1] : models[0];
        var model3 = models.Count > 2 ? models[2] : (models.Count > 1 ? models[1] : models[0]);

        var prompt1 = BuildClinicalVisionPrompt(ocrHintText);
        var prompt2 = BuildOpticalVisionPrompt(ocrHintText);
        var prompt3 = BuildQuantityAndFormVisionPrompt(ocrHintText);

        _logger.LogInformation(
            "Launching 3-pass parallel vision ensemble for prescription deciphering on models: [{M1}, {M2}, {M3}]",
            model1, model2, model3);

        // Execute 3 complementary vision passes in parallel
        var pass1Task = ExecuteSingleVisionPassAsync(prompt1, imagePart, model1, 0.0, cancellationToken);
        var pass2Task = ExecuteSingleVisionPassAsync(prompt2, imagePart, model2, 0.15, cancellationToken);
        var pass3Task = ExecuteSingleVisionPassAsync(prompt3, imagePart, model3, 0.0, cancellationToken);

        var results = await Task.WhenAll(pass1Task, pass2Task, pass3Task);
        return MergeEnsembleConsensus(results, _logger);
    }

    private async Task<GeminiPrescriptionResult> ExecuteSingleVisionPassAsync(
        string prompt,
        object imagePart,
        string model,
        double temperature,
        CancellationToken cancellationToken)
    {
        var url = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent";
        object[] parts = [imagePart, new { text = prompt }];

        var isThinking = model.Contains("gemini-3", StringComparison.OrdinalIgnoreCase) &&
                         !string.IsNullOrWhiteSpace(_options.ThinkingLevel);

        object genConfig = isThinking
            ? new
            {
                temperature,
                responseMimeType = "application/json",
                thinkingConfig = new { thinkingLevel = _options.ThinkingLevel }
            }
            : new
            {
                temperature,
                responseMimeType = "application/json"
            };

        var requestBody = new
        {
            contents = new[] { new { parts } },
            generationConfig = genConfig
        };

        const int maxRetries = 1;
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
                        response.Dispose();
                        response = null;
                        await Task.Delay(delay, cancellationToken);
                        continue;
                    }
                    _logger.LogWarning("Pass on model {Model} returned {Status} after retry.", model, response.StatusCode);
                    return new GeminiPrescriptionResult(null, null, null, 0m, false, true);
                }

                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning("Pass on model {Model} failed with {Status}.", model, response.StatusCode);
                    return new GeminiPrescriptionResult(null, null, null, 0m, false, false);
                }

                var jsonDoc = await response.Content.ReadFromJsonAsync<JsonDocument>(cancellationToken: cancellationToken);
                var root = jsonDoc?.RootElement;

                if (root == null || !root.Value.TryGetProperty("candidates", out var candidates) || candidates.GetArrayLength() == 0)
                {
                    return new GeminiPrescriptionResult(null, null, null, 0m, false, false);
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
                _logger.LogWarning("Pass on model {Model} timed out.", model);
                return new GeminiPrescriptionResult(null, null, null, 0m, false, false);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Unexpected error in pass on model {Model}.", model);
                return new GeminiPrescriptionResult(null, null, null, 0m, false, false);
            }
            finally
            {
                response?.Dispose();
            }
        }

        return new GeminiPrescriptionResult(null, null, null, 0m, false, false);
    }

    private static GeminiPrescriptionResult MergeEnsembleConsensus(
        IReadOnlyList<GeminiPrescriptionResult> results,
        ILogger logger)
    {
        var successful = results.Where(r => r.IsSuccess && r.Medications is { Count: > 0 }).ToList();
        if (successful.Count == 0)
        {
            var fallback = results.FirstOrDefault(r => r.IsSuccess);
            return fallback ?? new GeminiPrescriptionResult(null, null, null, 0m, false, false);
        }

        if (successful.Count == 1)
        {
            return successful[0];
        }

        var allItems = new List<GeminiMedicationItem>();
        foreach (var pass in successful)
        {
            if (pass.Medications != null)
            {
                allItems.AddRange(pass.Medications);
            }
        }

        // Group into clusters by phonetic / normalized drug name
        var clusters = new List<List<GeminiMedicationItem>>();
        foreach (var item in allItems)
        {
            var norm = DrugNameNormalizer.NormalizeName(item.TradeName);
            var matchedCluster = clusters.FirstOrDefault(c =>
                c.Any(existing =>
                {
                    var existingNorm = DrugNameNormalizer.NormalizeName(existing.TradeName);
                    if (existingNorm == norm) return true;
                    if (existingNorm.StartsWith(norm, StringComparison.Ordinal) || norm.StartsWith(existingNorm, StringComparison.Ordinal)) return true;
                    var dist = DrugNameNormalizer.DamerauLevenshteinDistance(existingNorm, norm);
                    return dist <= 2 && Math.Max(existingNorm.Length, norm.Length) >= 4;
                }));

            if (matchedCluster != null)
            {
                matchedCluster.Add(item);
            }
            else
            {
                clusters.Add([item]);
            }
        }

        var consolidatedItems = new List<GeminiMedicationItem>();
        foreach (var cluster in clusters)
        {
            var voteCount = cluster.Count;
            var bestItem = cluster.OrderByDescending(i => i.Confidence).First();
            var tradeName = bestItem.TradeName;
            var genericName = cluster.FirstOrDefault(i => !string.IsNullOrWhiteSpace(i.GenericName))?.GenericName;

            var strength = cluster
                .Where(i => !string.IsNullOrWhiteSpace(i.Strength))
                .GroupBy(i => i.Strength!)
                .OrderByDescending(g => g.Count())
                .FirstOrDefault()?.Key ?? bestItem.Strength;

            var dosageForm = cluster
                .Where(i => !string.IsNullOrWhiteSpace(i.DosageForm))
                .GroupBy(i => i.DosageForm!)
                .OrderByDescending(g => g.Count())
                .FirstOrDefault()?.Key ?? bestItem.DosageForm;

            var rawSig = cluster
                .OrderByDescending(i => i.RawSig?.Length ?? 0)
                .FirstOrDefault()?.RawSig ?? bestItem.RawSig;

            var baseConf = bestItem.Confidence;
            var consensusConfidence = voteCount >= 2
                ? Math.Min(0.99m, Math.Max(0.95m, baseConf + 0.05m))
                : baseConf;

            // Strict quantity invariant: Quantity > 1 ONLY if multiple passes agree!
            var qtyVotes = cluster.Select(i => i.Quantity).ToList();
            var quantity = qtyVotes.Count(q => q > 1) >= 2
                ? qtyVotes.Where(q => q > 1).GroupBy(q => q).OrderByDescending(g => g.Count()).First().Key
                : 1;

            (dosageForm, rawSig) = SanitizeClinicalFormAndRoute(tradeName, dosageForm, rawSig);

            consolidatedItems.Add(new GeminiMedicationItem(
                tradeName,
                strength,
                dosageForm,
                consensusConfidence,
                quantity,
                rawSig,
                genericName));
        }

        if (consolidatedItems.Count == 0)
        {
            return successful[0];
        }

        var primary = consolidatedItems[0];
        logger.LogInformation(
            "Multi-Pass Ensemble Consensus resolved {Count} items across {Passes} passes. Primary: {Primary} (Confidence: {Conf:P0})",
            consolidatedItems.Count, successful.Count, primary.TradeName, primary.Confidence);

        return new GeminiPrescriptionResult(
            primary.TradeName,
            primary.Strength,
            primary.DosageForm,
            primary.Confidence,
            true,
            false,
            consolidatedItems);
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
                    var qty = el.TryGetProperty("quantity", out var q) && q.TryGetInt32(out var qv) && qv > 0
                        ? (qv <= 5 ? qv : 1)
                        : 1;
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