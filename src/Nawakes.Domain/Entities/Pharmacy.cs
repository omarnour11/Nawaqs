using NetTopologySuite.Geometries;
using Nawakes.Domain.Common;
using Nawakes.Domain.Enums;

namespace Nawakes.Domain.Entities;

/// <summary>
/// A verified pharmacy with geospatial location.
/// GeoPoint uses SRID 4326 (WGS84) for SQL Server geography compatibility.
/// Navigation properties reference Guids only — no Identity dependency in Domain.
/// </summary>
public sealed class Pharmacy : BaseEntity
{
    public Guid OwnerId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string AddressLine { get; set; } = string.Empty;
    public string City { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;

    /// <summary>SQL Server geography column via NetTopologySuite. SRID must be 4326.</summary>
    public Point GeoPoint { get; set; } = null!;

    public string? LicenseDocUrl { get; set; }
    public string? NationalIdDocUrl { get; set; }
    public VerificationStatus VerificationStatus { get; set; } = VerificationStatus.Pending;
    public string? RejectionReason { get; set; }

    /// <summary>Clamped 0–100. Recalculated by TrustScoreRecalculationJob every 6 hours.</summary>
    public decimal TrustScore { get; set; } = 100m;
    public DateTime TrustScoreUpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation (configured in Infrastructure)
    public ICollection<InventoryItem> InventoryItems { get; set; } = [];
    public ICollection<Reservation> Reservations { get; set; } = [];
    public ICollection<Report> Reports { get; set; } = [];
}
