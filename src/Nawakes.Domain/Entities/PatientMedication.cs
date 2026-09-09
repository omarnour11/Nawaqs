using Nawakes.Domain.Common;

namespace Nawakes.Domain.Entities;

/// <summary>
/// A medication on the patient's current regimen (الملف الطبي → الأدوية الحالية).
/// Used for interaction context and future refill reminders.
/// </summary>
public sealed class PatientMedication : BaseEntity
{
    public Guid UserId { get; set; }

    public string MedicationName { get; set; } = string.Empty;
    public string? Strength { get; set; }       // e.g. "500 مجم"
    public string? Form { get; set; }           // كبسولات / أقراص / قلم حقن
    public string? DoseSchedule { get; set; }   // يوميًا / مرتين يوميًا

    /// <summary>Units per day — future refill math (quantity / unitsPerDay).</summary>
    public decimal? UnitsPerDay { get; set; }

    public bool IsActive { get; set; } = true;
    public string? Notes { get; set; }
}
