using Nawakes.Domain.Common;
using Nawakes.Domain.Enums;
using NetTopologySuite.Geometries;

namespace Nawakes.Domain.Entities;

public sealed class Subscription : BaseEntity
{
    public Guid UserId { get; set; }
    public string MedicationName { get; set; } = string.Empty;
    public string MedicationNameNormalized { get; set; } = string.Empty;
    public decimal RadiusKm { get; set; }
    public Point GeoPoint { get; set; } = null!;
    public bool IsActive { get; set; } = true;
    public DateTime? LastNotifiedAt { get; set; }

    // ── Fair availability queue (Phase 3) ───────────────────────────────
    public int QueuePosition { get; set; }
    public QueueStatus QueueStatus { get; set; } = QueueStatus.Waiting;
    public DateTime? OfferedAt { get; set; }
    public DateTime? OfferExpiresAt { get; set; }
    public Guid? OfferedInventoryItemId { get; set; }
    public string? OfferExpiryHangfireJobId { get; set; }

    /// <summary>
    /// Optimistic concurrency guard so two allocation/claim paths can never
    /// hand the same subscriber two different offers.
    /// </summary>
    public byte[] RowVersion { get; set; } = [];
}
