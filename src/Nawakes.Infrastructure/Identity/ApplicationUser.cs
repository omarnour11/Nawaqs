using Microsoft.AspNetCore.Identity;
using Nawakes.Domain.Enums;

namespace Nawakes.Infrastructure.Identity;

/// <summary>
/// Extended IdentityUser for Nawakes. Lives in Infrastructure because it depends on
/// Microsoft.AspNetCore.Identity.EntityFrameworkCore which belongs in the adapter layer.
/// Domain entities reference UserId (Guid) — not this class — to stay dependency-free.
/// </summary>
public sealed class ApplicationUser : IdentityUser<Guid>
{
    public UserRole Role { get; set; } = UserRole.Patient;

    /// <summary>AES-256 encrypted JSON blob. Never logged or exposed directly.</summary>
    public string? HealthQuestionnaireJson { get; set; }

    public string? FcmToken { get; set; }
    public double? LastKnownLatitude { get; set; }
    public double? LastKnownLongitude { get; set; }

    public bool IsDeleted { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public sealed class ApplicationRole : IdentityRole<Guid> { }
