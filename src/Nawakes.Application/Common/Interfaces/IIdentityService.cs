using Nawakes.Application.Profile.Queries.GetProfile;

namespace Nawakes.Application.Common.Interfaces;

public interface IIdentityService
{
    Task<(bool Success, string? UserId, string? Error)> RegisterAsync(
        string email,
        string password,
        string fullName,
        string? fcmToken,
        string? encryptedHealthJson,
        CancellationToken cancellationToken = default);

    Task<(bool Success, string? UserId, string? Role, string? Error)> ValidateCredentialsAsync(
        string email,
        string password,
        CancellationToken cancellationToken = default);

    Task UpdateFcmTokenAsync(Guid userId, string fcmToken, CancellationToken cancellationToken = default);

    /// <summary>
    /// Clears the stored push token (called on logout so a shared or resold
    /// device stops receiving the previous user's notifications).
    /// </summary>
    Task ClearFcmTokenAsync(Guid userId, CancellationToken cancellationToken = default);

    Task<ProfileDto> GetProfileAsync(Guid userId, CancellationToken cancellationToken = default);

    Task UpdateProfileAsync(
        Guid userId,
        string? fullName,
        string? phone,
        string? medicalHistoryNotes,
        CancellationToken cancellationToken = default);

    Task<(string Role, string Email)> GetRoleAndEmailAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>Generates a password-reset token (returns null if the account doesn't exist).</summary>
    Task<string?> GeneratePasswordResetTokenAsync(string email, CancellationToken cancellationToken = default);

    /// <summary>Resets the password using the token. Returns an error message on failure.</summary>
    Task<string?> ResetPasswordAsync(string email, string resetToken, string newPassword, CancellationToken cancellationToken = default);
}
