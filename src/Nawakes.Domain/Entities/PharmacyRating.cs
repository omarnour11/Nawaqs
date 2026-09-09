using Nawakes.Domain.Common;

namespace Nawakes.Domain.Entities;

/// <summary>
/// A patient's 1–5 star review of a pharmacy. One rating per patient per pharmacy
/// (upsert semantics); the aggregate average is surfaced in pharmacy detail.
/// </summary>
public sealed class PharmacyRating : BaseEntity
{
    public Guid UserId { get; set; }
    public Guid PharmacyId { get; set; }

    /// <summary>Star score from 1 to 5.</summary>
    public int Score { get; set; }

    public string? Comment { get; set; }

    // Navigation
    public Pharmacy Pharmacy { get; set; } = null!;
}
