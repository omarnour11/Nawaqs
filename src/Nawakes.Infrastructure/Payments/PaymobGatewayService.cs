using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Nawakes.Infrastructure.Payments;

/// <summary>
/// Encapsulates all Paymob Accept API calls needed for the Egypt payment flow.
/// Production-ready: reads credentials from configuration, verifies HMAC-SHA512 on webhooks.
/// </summary>
public sealed class PaymobGatewayService(
    IHttpClientFactory httpClientFactory,
    IConfiguration configuration,
    ILogger<PaymobGatewayService> logger)
{
    private readonly string _apiKey     = configuration["Paymob:ApiKey"]     ?? throw new InvalidOperationException("Paymob:ApiKey not configured");
    private readonly string _hmacSecret = configuration["Paymob:HmacSecret"] ?? throw new InvalidOperationException("Paymob:HmacSecret not configured");
    private readonly string _iframeId   = configuration["Paymob:IframeId"]   ?? throw new InvalidOperationException("Paymob:IframeId not configured");
    private readonly string _baseUrl    = configuration["Paymob:BaseUrl"]    ?? "https://accept.paymob.com/api";

    // ─── Step 1: Authenticate ──────────────────────────────────────────────
    public async Task<string> AuthenticateAsync(CancellationToken ct = default)
    {
        var http = httpClientFactory.CreateClient("Paymob");
        var body = JsonSerializer.Serialize(new { api_key = _apiKey });
        using var resp = await http.PostAsync(
            $"{_baseUrl}/auth/tokens",
            new StringContent(body, Encoding.UTF8, "application/json"),
            ct);

        resp.EnsureSuccessStatusCode();
        var json = await resp.Content.ReadAsStringAsync(ct);
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.GetProperty("token").GetString()
               ?? throw new InvalidOperationException("Paymob auth token was null");
    }

    // ─── Step 2: Register Order ────────────────────────────────────────────
    public async Task<long> RegisterOrderAsync(
        string authToken,
        long amountCents,
        string merchantOrderId,
        CancellationToken ct = default)
    {
        var http = httpClientFactory.CreateClient("Paymob");
        var body = JsonSerializer.Serialize(new
        {
            auth_token        = authToken,
            delivery_needed   = "false",
            amount_cents      = amountCents.ToString(),
            currency          = "EGP",
            merchant_order_id = merchantOrderId,
            items             = Array.Empty<object>()
        });

        using var resp = await http.PostAsync(
            $"{_baseUrl}/ecommerce/orders",
            new StringContent(body, Encoding.UTF8, "application/json"),
            ct);

        resp.EnsureSuccessStatusCode();
        var json = await resp.Content.ReadAsStringAsync(ct);
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.GetProperty("id").GetInt64();
    }

    // ─── Step 3: Get Payment Key ───────────────────────────────────────────
    public async Task<string> GetPaymentKeyAsync(
        string authToken,
        long paymobOrderId,
        long amountCents,
        int integrationId,
        string customerFirstName,
        string customerLastName,
        string customerEmail,
        string customerPhone,
        CancellationToken ct = default)
    {
        var http = httpClientFactory.CreateClient("Paymob");
        var body = JsonSerializer.Serialize(new
        {
            auth_token     = authToken,
            amount_cents   = amountCents.ToString(),
            expiration     = 3600,
            order_id       = paymobOrderId,
            billing_data   = new
            {
                apartment        = "NA",
                email            = customerEmail,
                floor            = "NA",
                first_name       = customerFirstName,
                street           = "NA",
                building         = "NA",
                phone_number     = customerPhone,
                shipping_method  = "NA",
                postal_code      = "NA",
                city             = "Cairo",
                country          = "EG",
                last_name        = customerLastName,
                state            = "NA"
            },
            currency        = "EGP",
            integration_id  = integrationId,
            lock_order_when_paid = "false"
        });

        using var resp = await http.PostAsync(
            $"{_baseUrl}/acceptance/payment_keys",
            new StringContent(body, Encoding.UTF8, "application/json"),
            ct);

        resp.EnsureSuccessStatusCode();
        var json = await resp.Content.ReadAsStringAsync(ct);
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.GetProperty("token").GetString()
               ?? throw new InvalidOperationException("Paymob payment key was null");
    }

    // ─── Step 4: Build iFrame URL ──────────────────────────────────────────
    public string BuildIframeUrl(string paymentToken)
        => $"{_baseUrl}/acceptance/iframes/{_iframeId}?payment_token={paymentToken}";

    // ─── Webhook HMAC Verification ─────────────────────────────────────────
    /// <summary>
    /// Computes the Paymob HMAC-SHA512 signature for a payload using the merchant HMAC secret.
    /// The 20 fields must be concatenated in the exact order Paymob specifies.
    /// </summary>
    public string ComputeHmacSignature(PaymobWebhookPayload payload)
    {
        var fields = new[]
        {
            payload.AmountCents,
            payload.CreatedAt,
            payload.Currency,
            payload.ErrorOccured,
            payload.HasParentTransaction,
            payload.Id,
            payload.IntegrationId,
            payload.Is3dSecure,
            payload.IsAuth,
            payload.IsCapture,
            payload.IsRefunded,
            payload.IsStandalonePayment,
            payload.IsVoided,
            payload.OrderId,
            payload.Owner,
            payload.Pending,
            payload.SourceDataPan,
            payload.SourceDataSubType,
            payload.SourceDataType,
            payload.Success
        };

        var concatenated = string.Concat(fields);
        using var hmac = new HMACSHA512(Encoding.UTF8.GetBytes(_hmacSecret));
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(concatenated));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    /// <summary>
    /// Verifies the Paymob HMAC-SHA512 signature sent in the webhook query string.
    /// </summary>
    public bool VerifyHmacSignature(PaymobWebhookPayload payload, string receivedHmac)
    {
        var computed = ComputeHmacSignature(payload);
        var match = string.Equals(computed, receivedHmac.ToLowerInvariant(), StringComparison.Ordinal);
        if (!match)
            logger.LogWarning("Paymob HMAC mismatch. Computed={Computed} Received={Received}", computed, receivedHmac);

        return match;
    }
}

/// <summary>Flat projection of the fields needed for HMAC verification from Paymob's webhook obj.transaction.</summary>
public sealed class PaymobWebhookPayload
{
    public string AmountCents          { get; init; } = "";
    public string CreatedAt            { get; init; } = "";
    public string Currency             { get; init; } = "";
    public string ErrorOccured         { get; init; } = "";
    public string HasParentTransaction { get; init; } = "";
    public string Id                   { get; init; } = "";
    public string IntegrationId        { get; init; } = "";
    public string Is3dSecure           { get; init; } = "";
    public string IsAuth               { get; init; } = "";
    public string IsCapture            { get; init; } = "";
    public string IsRefunded           { get; init; } = "";
    public string IsStandalonePayment  { get; init; } = "";
    public string IsVoided             { get; init; } = "";
    public string OrderId              { get; init; } = "";
    public string Owner                { get; init; } = "";
    public string Pending              { get; init; } = "";
    public string SourceDataPan        { get; init; } = "";
    public string SourceDataSubType    { get; init; } = "";
    public string SourceDataType       { get; init; } = "";
    public string Success              { get; init; } = "";
}

