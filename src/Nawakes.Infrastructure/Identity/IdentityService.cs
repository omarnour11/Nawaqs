using Microsoft.AspNetCore.Identity;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Infrastructure.Identity;

/// <summary>
/// Wraps ASP.NET Core Identity's UserManager to implement IIdentityService.
/// Keeps UserManager completely out of the Application layer.
/// </summary>
public sealed class IdentityService(UserManager<ApplicationUser> userManager) : IIdentityService
{
    public async Task<(bool Success, string? UserId, string? Error)> RegisterAsync(
        string email,
        string password,
        string fullName,
        string? fcmToken,
        string? encryptedHealthJson,
        CancellationToken cancellationToken = default)
    {
        var existingUser = await userManager.FindByEmailAsync(email);
        if (existingUser is not null)
            return (false, null, "An account with this email already exists.");

        var user = new ApplicationUser
        {
            UserName = email,
            Email = email,
            FcmToken = fcmToken,
            HealthQuestionnaireJson = encryptedHealthJson,
            Role = UserRole.Patient
        };

        // UserManager handles bcrypt hashing internally (cost factor set in DI registration)
        var result = await userManager.CreateAsync(user, password);
        if (!result.Succeeded)
        {
            var errors = string.Join("; ", result.Errors.Select(e => e.Description));
            return (false, null, errors);
        }

        await userManager.AddToRoleAsync(user, "Patient");

        return (true, user.Id.ToString(), null);
    }

    public async Task<(bool Success, string? UserId, string? Role, string? Error)> ValidateCredentialsAsync(
        string email,
        string password,
        CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByEmailAsync(email);
        if (user is null || user.IsDeleted)
            return (false, null, null, "Invalid credentials.");

        var isValid = await userManager.CheckPasswordAsync(user, password);
        if (!isValid)
            return (false, null, null, "Invalid credentials.");

        return (true, user.Id.ToString(), user.Role.ToString(), null);
    }

    public async Task UpdateFcmTokenAsync(Guid userId, string fcmToken, CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null) return;

        user.FcmToken = fcmToken;
        await userManager.UpdateAsync(user);
    }
}
