using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Entities;
using Nawakes.Infrastructure.Payments;

namespace Nawakes.API.Controllers;

/// <summary>
/// Real Paymob payment gateway integration.
/// Handles: create payment intent → webhook callback → status polling.
/// </summary>
[ApiController]
[Route("api/v1/payments")]
[Produces("application/json")]
public sealed class PaymentsController(
    PaymobGatewayService paymob,
    IApplicationDbContext db,
    IConfiguration configuration,
    ILogger<PaymentsController> logger) : ControllerBase
{
    // ─── POST api/v1/payments/paymob/create-intent ─────────────────────────
    /// <summary>
    /// Step 1 called by Flutter after the user picks a payment method.
    /// Returns the Paymob iFrame URL to open in WebView.
    /// </summary>
    [HttpPost("paymob/create-intent")]
    [Authorize(Roles = "Patient")]
    [ProducesResponseType(typeof(CreateIntentResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<CreateIntentResponse>> CreateIntent(
        [FromBody] CreateIntentRequest req,
        CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        Reservation? reservation = null;
        string merchantOrderId;

        if (req.ReservationId.HasValue && req.ReservationId.Value != Guid.Empty)
        {
            reservation = await db.Reservations
                .Include(r => r.InventoryItem)
                .Include(r => r.Pharmacy)
                .FirstOrDefaultAsync(r => r.Id == req.ReservationId.Value && r.UserId == userId, ct);

            if (reservation is null)
                return NotFound(new { error = "الحجز غير موجود" });

            if (reservation.PaymentStatus == "Paid")
                return BadRequest(new { error = "تم دفع هذا الحجز مسبقاً" });

            merchantOrderId = $"NWQ-{reservation.Id:N}-{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";
        }
        else
        {
            merchantOrderId = $"NWQ-TEST-{userId:N}-{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";
        }

        // Pick integration ID based on payment type
        var integrationId = req.PaymentType.ToLowerInvariant() switch
        {
            "wallet" => int.Parse(configuration["Paymob:WalletIntegrationId"] ?? "0"),
            _        => int.Parse(configuration["Paymob:CardIntegrationId"]   ?? "0"),
        };

        if (integrationId == 0)
            return BadRequest(new { error = "Integration ID غير مضبوط فالـ Config" });

        try
        {
            var amountCents = (long)Math.Round(req.AmountEgp * 100);

            // Split customer name safely
            var parts      = (req.CustomerName ?? "Patient User").Split(' ', 2);
            var firstName  = parts[0];
            var lastName   = parts.Length > 1 ? parts[1] : "Nawaks";

            // Paymob 3-step flow
            var authToken     = await paymob.AuthenticateAsync(ct);
            var paymobOrderId = await paymob.RegisterOrderAsync(authToken, amountCents, merchantOrderId, ct);
            var paymentKey    = await paymob.GetPaymentKeyAsync(
                authToken,
                paymobOrderId,
                amountCents,
                integrationId,
                firstName,
                lastName,
                req.CustomerEmail ?? $"patient-{userId:N}@nawaks.app",
                req.CustomerPhone ?? "01000000000",
                ct);

            var iframeUrl = paymob.BuildIframeUrl(paymentKey);

            // Store merchant order ID on the reservation for webhook correlation
            if (reservation != null)
            {
                reservation.PaymobMerchantOrderId = merchantOrderId;
                reservation.PaymentProvider       = req.PaymentType.ToLowerInvariant() == "wallet" ? "PaymobWallet" : "PaymobCard";
                await db.SaveChangesAsync(ct);

                logger.LogInformation(
                    "Paymob intent created. Reservation={ReservationId} MerchantOrder={MerchantOrderId} Amount={Amount}EGP",
                    reservation.Id, merchantOrderId, req.AmountEgp);
            }
            else
            {
                logger.LogInformation(
                    "Paymob standalone intent created. User={UserId} MerchantOrder={MerchantOrderId} Amount={Amount}EGP",
                    userId, merchantOrderId, req.AmountEgp);
            }

            return Ok(new CreateIntentResponse(
                IframeUrl:        iframeUrl,
                MerchantOrderId:  merchantOrderId,
                PaymobOrderId:    paymobOrderId,
                AmountEgp:        req.AmountEgp));
        }
        catch (HttpRequestException ex)
        {
            logger.LogError(ex, "Paymob API call failed for reservation {Id}", req.ReservationId);
            return StatusCode(502, new { error = "فشل الاتصال بـ Paymob، حاول تاني" });
        }
    }

    // ─── POST api/v1/payments/paymob/webhook ───────────────────────────────
    /// <summary>
    /// Paymob calls this endpoint after payment completes (success or failure).
    /// Must return 200 always; Paymob retries on any other status.
    /// Query param ?hmac= contains the HMAC-SHA512 signature.
    /// </summary>
    [HttpPost("paymob/webhook")]
    [AllowAnonymous]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> Webhook(
        [FromQuery] string hmac,
        CancellationToken ct)
    {
        string rawBody;
        using (var reader = new System.IO.StreamReader(Request.Body))
            rawBody = await reader.ReadToEndAsync(ct);

        JsonElement root;
        try
        {
            root = JsonDocument.Parse(rawBody).RootElement;
        }
        catch
        {
            logger.LogWarning("Paymob webhook: invalid JSON body");
            return Ok(); // Always 200
        }

        // Extract the transaction object (Paymob wraps it in { type, obj })
        if (!root.TryGetProperty("obj", out var txn))
        {
            logger.LogWarning("Paymob webhook: missing 'obj' field");
            return Ok();
        }

        // Build flat payload for HMAC
        var payload = new PaymobWebhookPayload
        {
            AmountCents          = txn.TryGetProperty("amount_cents",           out var v) ? v.ToString() : "",
            CreatedAt            = txn.TryGetProperty("created_at",             out v)     ? v.ToString() : "",
            Currency             = txn.TryGetProperty("currency",               out v)     ? v.ToString() : "",
            ErrorOccured         = txn.TryGetProperty("error_occured",          out v)     ? v.ToString().ToLower() : "",
            HasParentTransaction = txn.TryGetProperty("has_parent_transaction", out v)     ? v.ToString().ToLower() : "",
            Id                   = txn.TryGetProperty("id",                     out v)     ? v.ToString() : "",
            IntegrationId        = txn.TryGetProperty("integration_id",         out v)     ? v.ToString() : "",
            Is3dSecure           = txn.TryGetProperty("is_3d_secure",           out v)     ? v.ToString().ToLower() : "",
            IsAuth               = txn.TryGetProperty("is_auth",                out v)     ? v.ToString().ToLower() : "",
            IsCapture            = txn.TryGetProperty("is_capture",             out v)     ? v.ToString().ToLower() : "",
            IsRefunded           = txn.TryGetProperty("is_refunded",            out v)     ? v.ToString().ToLower() : "",
            IsStandalonePayment  = txn.TryGetProperty("is_standalone_payment",  out v)     ? v.ToString().ToLower() : "",
            IsVoided             = txn.TryGetProperty("is_voided",              out v)     ? v.ToString().ToLower() : "",
            OrderId              = txn.TryGetProperty("order",                  out var ord) && ord.TryGetProperty("id", out v) ? v.ToString() : "",
            Owner                = txn.TryGetProperty("owner",                  out v)     ? v.ToString() : "",
            Pending              = txn.TryGetProperty("pending",                out v)     ? v.ToString().ToLower() : "",
            SourceDataPan        = txn.TryGetProperty("source_data",            out var sd) && sd.TryGetProperty("pan",      out v) ? v.ToString() : "",
            SourceDataSubType    = txn.TryGetProperty("source_data",            out sd)    && sd.TryGetProperty("sub_type",  out v) ? v.ToString() : "",
            SourceDataType       = txn.TryGetProperty("source_data",            out sd)    && sd.TryGetProperty("type",      out v) ? v.ToString() : "",
            Success              = txn.TryGetProperty("success",                out v)     ? v.ToString().ToLower() : "",
        };

        // ── HMAC Verification ──────────────────────────────────────────────
        if (!paymob.VerifyHmacSignature(payload, hmac))
        {
            logger.LogWarning("Paymob webhook: HMAC verification FAILED for transaction {Id}", payload.Id);
            return Ok(); // Return 200 to prevent retries flooding us; already logged
        }

        bool isSuccess = payload.Success == "true";
        string? merchantOrderId = null;
        if (txn.TryGetProperty("order", out var orderEl) && orderEl.TryGetProperty("merchant_order_id", out var moid))
            merchantOrderId = moid.GetString();

        if (string.IsNullOrEmpty(merchantOrderId))
        {
            logger.LogWarning("Paymob webhook: no merchant_order_id in webhook, transaction {Id}", payload.Id);
            return Ok();
        }

        // Find the reservation by our merchant order ID
        var reservation = await db.Reservations
            .FirstOrDefaultAsync(r => r.PaymobMerchantOrderId == merchantOrderId, ct);

        if (reservation is null)
        {
            logger.LogWarning("Paymob webhook: reservation not found for MerchantOrderId={Id}", merchantOrderId);
            return Ok();
        }

        if (isSuccess)
        {
            reservation.PaymentStatus    = "Paid";
            reservation.PaymentReference = payload.Id;
            reservation.PaymentAmountEgp = long.TryParse(payload.AmountCents, out var cents)
                ? Math.Round((decimal)cents / 100, 2)
                : null;

            logger.LogInformation(
                "Payment CONFIRMED. Reservation={ReservationId} Txn={TxnId} Amount={Amount}EGP",
                reservation.Id, payload.Id, reservation.PaymentAmountEgp);
        }
        else
        {
            reservation.PaymentStatus = "Failed";
            logger.LogWarning(
                "Payment FAILED. Reservation={ReservationId} Txn={TxnId}",
                reservation.Id, payload.Id);
        }

        await db.SaveChangesAsync(ct);
        return Ok(new { received = true });
    }

    // ─── GET api/v1/payments/paymob/status/{reservationId} ─────────────────
    /// <summary>
    /// Flutter polls this after the WebView closes to confirm payment status.
    /// </summary>
    [HttpGet("paymob/status/{reservationId:guid}")]
    [Authorize(Roles = "Patient")]
    [ProducesResponseType(typeof(PaymentStatusResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PaymentStatusResponse>> GetStatus(
        Guid reservationId,
        CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var reservation = await db.Reservations
            .AsNoTracking()
            .FirstOrDefaultAsync(r => r.Id == reservationId && r.UserId == userId, ct);

        if (reservation is null)
            return NotFound(new { error = "الحجز غير موجود" });

        return Ok(new PaymentStatusResponse(
            ReservationId:    reservation.Id,
            PaymentStatus:    reservation.PaymentStatus,
            PaymentReference: reservation.PaymentReference,
            PaymentAmountEgp: reservation.PaymentAmountEgp,
            PaymentProvider:  reservation.PaymentProvider));
    }
}

// ─── DTOs ──────────────────────────────────────────────────────────────────

public sealed record CreateIntentRequest(
    Guid?  ReservationId,
    double AmountEgp,
    string PaymentType,       // "card" | "wallet"
    string? CustomerName  = null,
    string? CustomerEmail = null,
    string? CustomerPhone = null);

public sealed record CreateIntentResponse(
    string IframeUrl,
    string MerchantOrderId,
    long   PaymobOrderId,
    double AmountEgp);

public sealed record PaymentStatusResponse(
    Guid    ReservationId,
    string  PaymentStatus,
    string? PaymentReference,
    decimal? PaymentAmountEgp,
    string? PaymentProvider);

