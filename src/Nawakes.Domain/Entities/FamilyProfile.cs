using Nawakes.Domain.Common;

namespace Nawakes.Domain.Entities;

/// <summary>
/// دولاب دوا العيلة — a tracked person (e.g. an elderly parent) whose chronic
/// medication supplies the family monitors. Owned by one account; accessible
/// to accepted caregivers.
/// </summary>
public sealed class FamilyProfile : BaseEntity
{
    public Guid OwnerUserId { get; set; }
    public string Nickname { get; set; } = string.Empty;
    public double HomeLatitude { get; set; }
    public double HomeLongitude { get; set; }
    public bool IsActive { get; set; } = true;

    public List<FamilyMedication> FamilyMedications { get; set; } = [];
    public List<FamilyCaregiverLink> FamilyCaregiverLinks { get; set; } = [];
}

/// <summary>
/// A chronic medication tracked inside a family cabinet with depletion math:
/// DaysRemaining = floor(StripsCount × UnitsPerStrip / DailyDoseUnits).
/// </summary>
public sealed class FamilyMedication : BaseEntity
{
    public Guid FamilyProfileId { get; set; }
    public string MedicationName { get; set; } = string.Empty;
    public string? Strength { get; set; }
    public int StripsCount { get; set; }
    public int UnitsPerStrip { get; set; }
    public decimal DailyDoseUnits { get; set; }
    public DateTime? LastRefillDate { get; set; }
    public int AlertThresholdDays { get; set; } = 7;
    public bool IsActive { get; set; } = true;

    public FamilyProfile FamilyProfile { get; set; } = null!;
}

/// <summary>
/// Links a caregiver account to a family cabinet so they can track and
/// refill medications for the person.
/// </summary>
public sealed class FamilyCaregiverLink : BaseEntity
{
    public Guid FamilyProfileId { get; set; }
    public Guid CaregiverUserId { get; set; }
    public string? InvitedPhoneNumber { get; set; }
    public bool IsAccepted { get; set; }

    /// <summary>
    /// Optimistic concurrency guard so two simultaneous accepts of the same
    /// invitation cannot both succeed (which would double-notify the owner).
    /// </summary>
    public byte[] RowVersion { get; set; } = [];
}
