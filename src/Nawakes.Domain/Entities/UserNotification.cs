using Nawakes.Domain.Common;
using Nawakes.Domain.Enums;

namespace Nawakes.Domain.Entities;

/// <summary>
/// An in-app notification delivered to a user's notification center.
/// Written alongside (and independently of) best-effort FCM pushes, so the
/// user always sees a durable history even without a registered device token.
/// </summary>
public sealed class UserNotification : BaseEntity
{
    public Guid UserId { get; set; }
    public NotificationType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;

    /// <summary>Optional reference to the related entity (reservation, pharmacy, …).</summary>
    public Guid? RelatedEntityId { get; set; }

    public bool IsRead { get; set; }
    public DateTime? ReadAt { get; set; }
}
