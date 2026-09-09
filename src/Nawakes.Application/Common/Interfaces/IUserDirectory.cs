namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// Read-only access to Identity user data for the Application layer
/// (implemented over EF Core in Infrastructure). Keeps ApplicationUser out of Domain/Application.
/// </summary>
public interface IUserDirectory
{
    Task<int> CountByRoleAsync(Domain.Enums.UserRole role, CancellationToken cancellationToken = default);
    Task<Dictionary<Guid, string>> GetEmailsAsync(IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken = default);

    /// <summary>Phone number if present, else email — for pharmacist order contact.</summary>
    Task<Dictionary<Guid, string>> GetContactAsync(IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken = default);
}
