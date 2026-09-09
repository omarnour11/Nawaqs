using Nawakes.Domain.Common;

namespace Nawakes.Domain.Entities;

/// <summary>
/// A patient's saved (favorited) pharmacy for one-tap access from the home screen.
/// </summary>
public sealed class FavoritePharmacy : BaseEntity
{
    public Guid UserId { get; set; }
    public Guid PharmacyId { get; set; }
}
