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

    Task<ProfileDto> GetProfileAsync(Guid userId, CancellationToken cancellationToken = default);

    Task UpdateProfileAsync(
        Guid userId,
        string? fullName,
        string? phone,
        string? medicalHistoryNotes,
        CancellationToken cancellationToken = default);

    Task<(string Role, string Email)> GetRoleAndEmailAsync(Guid userId, CancellationToken cancellationToken = default);
}
