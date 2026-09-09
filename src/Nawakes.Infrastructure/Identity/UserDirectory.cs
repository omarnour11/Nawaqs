using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Identity;
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
}
