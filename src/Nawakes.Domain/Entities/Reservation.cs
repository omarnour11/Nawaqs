using Nawakes.Domain.Common;
using Nawakes.Domain.Enums;

namespace Nawakes.Domain.Entities;

public sealed class Reservation : BaseEntity
{
    public Guid UserId { get; set; }
    public Guid InventoryItemId { get; set; }
    public Guid PharmacyId { get; set; }
    public ReservationStatus Status { get; set; } = ReservationStatus.Active;
    public DateTime ExpiresAt { get; set; }

    /// <summary>Hangfire job ID stored so it can be deleted on early completion/cancellation.</summary>
    public string? HangfireJobId { get; set; }

    public DateTime? CompletedAt { get; set; }
    public DateTime? CancelledAt { get; set; }

    // Navigation
    public InventoryItem InventoryItem { get; set; } = null!;
    public Pharmacy Pharmacy { get; set; } = null!;
}
