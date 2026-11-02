using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Admin.Queries.GetPatients;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.Identity;

public sealed class UserDirectory(ApplicationDbContext context) : IUserDirectory
{
    public async Task<int> CountByRoleAsync(UserRole role, CancellationToken cancellationToken = default)
        => await context.Users.CountAsync(u => u.Role == role && !u.IsDeleted, cancellationToken);

    public async Task<Dictionary<Guid, string>> GetEmailsAsync(
        IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken = default)
        => await context.Users
            .AsNoTracking()
            .Where(u => userIds.Contains(u.Id))
            .Select(u => new { u.Id, Email = u.Email ?? string.Empty })
            .ToDictionaryAsync(u => u.Id, u => u.Email, cancellationToken);

    public async Task<Dictionary<Guid, string>> GetContactAsync(
        IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken = default)
        => await context.Users
            .AsNoTracking()
            .Where(u => userIds.Contains(u.Id))
            .Select(u => new { u.Id, Contact = u.PhoneNumber ?? u.Email ?? string.Empty })
            .ToDictionaryAsync(u => u.Id, u => u.Contact, cancellationToken);

    public async Task<Dictionary<Guid, PatientClinicalSummaryDto>> GetClinicalSummariesAsync(
        IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken = default)
        => await context.Users
            .AsNoTracking()
            .Where(u => userIds.Contains(u.Id))
            .Select(u => new PatientClinicalSummaryDto(
                u.Id,
                u.MedicalHistoryNotes,
                u.AllowPharmacistViewActiveMedications,
                u.Gender,
                u.Age,
                u.ChronicConditions,
                u.KnownAllergies))
            .ToDictionaryAsync(u => u.UserId, cancellationToken);

    public async Task<Guid?> FindUserIdByPhoneAsync(
        string phoneNumber, CancellationToken cancellationToken = default)
    {
        var normalized = phoneNumber.Trim();
        if (normalized.Length == 0) return null;

        return await context.Users
            .AsNoTracking()
            .Where(u => !u.IsDeleted && u.PhoneNumber == normalized)
            .Select(u => (Guid?)u.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }

    /// <summary>
    /// Paginated patient search for the admin console.
    /// Matches against email, full name, and phone number (case-insensitive).
    /// Returns only Patient-role accounts, never PharmacyOwner or Admin records.
    /// </summary>
    public async Task<PagedPatientsResult> GetPatientPageAsync(
        string? search,
        int pageNumber,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var query = context.Users
            .AsNoTracking()
            .Where(u => u.Role == UserRole.Patient && !u.IsDeleted);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim().ToLower();
            query = query.Where(u =>
                (u.Email != null && u.Email.ToLower().Contains(term)) ||
                (u.FullName != null && u.FullName.ToLower().Contains(term)) ||
                (u.PhoneNumber != null && u.PhoneNumber.Contains(term)));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var raw = await query
            .OrderByDescending(u => u.CreatedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .Select(u => new PatientSummaryDto(
                u.Id,
                u.Email ?? string.Empty,
                u.FullName,
                u.PhoneNumber,
                u.CreatedAt,
                0, // enriched by caller
                0))
            .ToListAsync(cancellationToken);

        var totalPages = (int)Math.Ceiling(totalCount / (double)pageSize);

        return new PagedPatientsResult(raw, totalCount, pageNumber, pageSize, totalPages);
    }
}
