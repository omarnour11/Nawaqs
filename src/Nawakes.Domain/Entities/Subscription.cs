using Nawakes.Domain.Common;
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
}
