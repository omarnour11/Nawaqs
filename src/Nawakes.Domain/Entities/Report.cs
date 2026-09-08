using Nawakes.Domain.Common;
using Nawakes.Domain.Enums;

namespace Nawakes.Domain.Entities;

public sealed class Report : BaseEntity
{
    public Guid UserId { get; set; }
    public Guid PharmacyId { get; set; }
    public ReportType Type { get; set; }
    public ReportStatus Status { get; set; } = ReportStatus.Pending;
    public string? Description { get; set; }

    /// <summary>Populated for ReportType.Found — medication the reporter found in stock.</summary>
    public string? MedicationName { get; set; }
    public decimal? ReportedPrice { get; set; }

    public Guid? ReviewedByAdminId { get; set; }
    public DateTime? ReviewedAt { get; set; }

    // Navigation
    public Pharmacy Pharmacy { get; set; } = null!;
}
