using Nawakes.Domain.Common;
using Nawakes.Domain.Enums;

namespace Nawakes.Domain.Entities;

public sealed class Reservation : BaseEntity
{
    public Guid UserId { get; set; }
    public Guid InventoryItemId { get; set; }
    public Guid PharmacyId { get; set; }
    public ReservationStatus Status { get; set; } = ReservationStatus.Active;

    /// <summary>Short human-readable pickup code shown to the patient (e.g. NWQ-4F2A9C).</summary>
    public string ReservationCode { get; set; } = string.Empty;

    /// <summary>Pickup from pharmacy (0) vs Home Delivery (1).</summary>
    public FulfillmentType FulfillmentType { get; set; } = FulfillmentType.Pickup;

    public string? DeliveryAddress { get; set; }
    public double? DeliveryLatitude { get; set; }
    public double? DeliveryLongitude { get; set; }
    public string? DeliveryContactPhone { get; set; }
    public string? DeliveryNotes { get; set; }
    public DeliveryStatus? DeliveryStatus { get; set; }

    public DateTime ExpiresAt { get; set; }

    /// <summary>Hangfire job ID stored so it can be deleted on early completion/cancellation.</summary>
    public string? HangfireJobId { get; set; }

    public DateTime? CompletedAt { get; set; }
    public DateTime? CancelledAt { get; set; }

    /// <summary>Clinical contraindication reason if pharmacy rejected with alternative recommendation.</summary>
    public string? ClinicalContraindicationReason { get; set; }
    public string? RecommendedAlternativeMedication { get; set; }
    public Guid? RecommendedAlternativeItemId { get; set; }

    /// <summary>Sanitized prescription image crop URL or base64 data (strictly no PII) for pharmacy safety verification.</summary>
    public string? PrescriptionCropUrl { get; set; }

    /// <summary>Raw bytes of sanitized prescription image crop if stored directly.</summary>
    public byte[]? PrescriptionCropBytes { get; set; }

    // ── Payment ──────────────────────────────────────────────────────────
    /// <summary>Unpaid | Paid | Failed | Refunded</summary>
    public string PaymentStatus { get; set; } = "Unpaid";

    /// <summary>Paymob transaction ID returned in the webhook.</summary>
    public string? PaymentReference { get; set; }

    /// <summary>Amount paid in EGP (from Paymob amount_cents / 100).</summary>
    public decimal? PaymentAmountEgp { get; set; }

    /// <summary>Paymob | InstaPay | Cash</summary>
    public string? PaymentProvider { get; set; }

    /// <summary>Paymob merchant order ID used to correlate webhook with reservation.</summary>
    public string? PaymobMerchantOrderId { get; set; }

    // Navigation
    public InventoryItem InventoryItem { get; set; } = null!;
    public Pharmacy Pharmacy { get; set; } = null!;
}
