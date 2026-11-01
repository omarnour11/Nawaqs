using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Profile.Queries.GetProfile;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.Identity;

/// <summary>
/// Wraps ASP.NET Core Identity's UserManager to implement IIdentityService.
/// Keeps UserManager completely out of the Application layer.
/// </summary>
public sealed class IdentityService(
    UserManager<ApplicationUser> userManager,
    ApplicationDbContext context) : IIdentityService
{
    public async Task<(bool Success, string? UserId, string? Error)> RegisterAsync(
        string email,
        string password,
        string fullName,
        string? fcmToken,
        string? encryptedHealthJson,
        string role = "Patient",
        CancellationToken cancellationToken = default)
    {
        var existingUser = await userManager.FindByEmailAsync(email);
        if (existingUser is not null)
            return (false, null, "An account with this email already exists.");

        var parsedRole = Enum.TryParse<UserRole>(role, true, out var r) ? r : UserRole.Patient;

        var user = new ApplicationUser
        {
            UserName = email,
            Email = email,
            FullName = string.IsNullOrWhiteSpace(fullName) ? null : fullName.Trim(),
            FcmToken = fcmToken,
            HealthQuestionnaireJson = encryptedHealthJson,
            Role = parsedRole
        };

        var result = await userManager.CreateAsync(user, password);
        if (!result.Succeeded)
        {
            var errors = string.Join("; ", result.Errors.Select(e => e.Description));
            return (false, null, errors);
        }

        await userManager.AddToRoleAsync(user, parsedRole.ToString());

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

    public async Task ClearFcmTokenAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null || user.FcmToken is null) return;

        user.FcmToken = null;
        await userManager.UpdateAsync(user);
    }

    public async Task<ProfileDto> GetProfileAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await context.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new UnauthorizedAccessException("User not found.");

        return new ProfileDto(
            user.Id,
            user.Email ?? string.Empty,
            user.FullName,
            user.PhoneNumber,
            user.MedicalHistoryNotes,
            user.CreatedAt,
            user.AllowPharmacistViewActiveMedications);
    }

    public async Task UpdateProfileAsync(
        Guid userId,
        string? fullName,
        string? phone,
        string? medicalHistoryNotes,
        bool? allowPharmacistViewActiveMedications = null,
        CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByIdAsync(userId.ToString())
            ?? throw new UnauthorizedAccessException("User not found.");

        if (fullName is not null) user.FullName = fullName.Trim();
        if (phone is not null) user.PhoneNumber = phone.Trim();
        if (medicalHistoryNotes is not null) user.MedicalHistoryNotes = medicalHistoryNotes.Trim();
        if (allowPharmacistViewActiveMedications.HasValue)
            user.AllowPharmacistViewActiveMedications = allowPharmacistViewActiveMedications.Value;

        await userManager.UpdateAsync(user);
    }

    public async Task<(string Role, string Email)> GetRoleAndEmailAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null) throw new UnauthorizedAccessException("User not found.");
        return (user.Role.ToString(), user.Email ?? string.Empty);
    }

    public async Task<string?> GeneratePasswordResetTokenAsync(
        string email, CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByEmailAsync(email);
        return user is null ? null : await userManager.GeneratePasswordResetTokenAsync(user);
    }

    public async Task<string?> ResetPasswordAsync(
        string email, string resetToken, string newPassword, CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByEmailAsync(email);
        if (user is null) return "الحساب غير موجود.";

        var result = await userManager.ResetPasswordAsync(user, resetToken, newPassword);
        return result.Succeeded
            ? null
            : string.Join("; ", result.Errors.Select(e => e.Description));
    }
}
