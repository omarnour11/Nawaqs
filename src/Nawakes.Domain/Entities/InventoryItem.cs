using Nawakes.Domain.Common;
using Nawakes.Domain.Enums;

namespace Nawakes.Domain.Entities;

/// <summary>
/// A single medication entry in a pharmacy's stock.
/// RowVersion enables optimistic concurrency for the reservation race-condition guard.
/// </summary>
public sealed class InventoryItem : BaseEntity
{
    public Guid PharmacyId { get; set; }
    public string MedicationName { get; set; } = string.Empty;

    /// <summary>UPPER-trimmed value stored for case-insensitive search without collation dependency.</summary>
    public string MedicationNameNormalized { get; set; } = string.Empty;

    public decimal Price { get; set; }
    public InventoryStatus Status { get; set; } = InventoryStatus.InStock;

    /// <summary>Optimistic concurrency token — maps to SQL ROWVERSION.</summary>
    public byte[] RowVersion { get; set; } = [];

    // Navigation
    public Pharmacy Pharmacy { get; set; } = null!;
    public ICollection<Reservation> Reservations { get; set; } = [];
}
