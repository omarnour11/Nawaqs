using Nawakes.Domain.Common;

namespace Nawakes.Domain.Entities;

/// <summary>
/// Persisted refresh token for a user session.
/// Tokens are stored hashed (SHA-256); the raw token is only ever returned at issuance.
/// Rotation: consuming a token revokes it and issues a new one.
/// </summary>
public sealed class RefreshToken : BaseEntity
{
    /// <summary>SHA-256 hash of the opaque token string.</summary>
    public string TokenHash { get; set; } = string.Empty;

    public Guid UserId { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime? RevokedAt { get; set; }

    /// <summary>Token that replaced this one during rotation (null if not rotated).</summary>
    public Guid? ReplacedByTokenId { get; set; }

    /// <summary>Client identifier (device/user-agent) that requested the token.</summary>
    public string? DeviceInfo { get; set; }

    public bool IsActive => RevokedAt is null && ExpiresAt > DateTime.UtcNow;

    // Navigation
    // FK to ApplicationUser configured in Infrastructure (no Identity dependency in Domain)
}
