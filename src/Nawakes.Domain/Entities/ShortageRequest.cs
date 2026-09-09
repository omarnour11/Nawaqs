using Nawakes.Domain.Common;
using NetTopologySuite.Geometries;
using Nawakes.Domain.Enums;

namespace Nawakes.Domain.Entities;

/// <summary>
/// استغاثة دواء — a patient's live shortage request. Broadcast to nearby
/// verified pharmacies; the first pharmacy to claim fulfills it as a reservation.
/// </summary>
public sealed class ShortageRequest : BaseEntity
{
    public Guid UserId { get; set; }
    public string MedicationName { get; set; } = string.Empty;

    /// <summary>UPPER-trimmed for matching.</summary>
    public string MedicationNameNormalized { get; set; } = string.Empty;

    public string? Strength { get; set; }
    public int QuantityNeeded { get; set; } = 1;

    /// <summary>Patient's location when posting (search origin).</summary>
    public Point GeoPoint { get; set; } = null!;

    public ShortageRequestStatus Status { get; set; } = ShortageRequestStatus.Open;

    /// <summary>Pharmacy that claimed it (null while Open / Expired).</summary>
    public Guid? ClaimedByPharmacyId { get; set; }
    public DateTime? ClaimedAt { get; set; }

    /// <summary>Reservation created after fulfillment (QR pass).</summary>
    public Guid? FulfilledReservationId { get; set; }

    public DateTime ExpiresAt { get; set; } = DateTime.UtcNow.AddHours(6);

    /// <summary>Free text from the patient (دواء بديل مقبول، ملاحظات…).</summary>
    public string? Notes { get; set; }
}
