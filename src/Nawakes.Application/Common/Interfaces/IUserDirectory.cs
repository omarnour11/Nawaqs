using Nawakes.Application.Admin.Queries.GetPatients;

namespace Nawakes.Application.Common.Interfaces;

public sealed record PatientClinicalSummaryDto(
    Guid UserId,
    string? MedicalHistoryNotes,
    bool AllowPharmacistViewActiveMedications,
    string? Gender = null,
    int? Age = null,
    string? ChronicConditions = null,
    string? KnownAllergies = null);

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

    /// <summary>Clinical summary (medical notes, consent) for pharmacist verification.</summary>
    Task<Dictionary<Guid, PatientClinicalSummaryDto>> GetClinicalSummariesAsync(
        IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken = default);

    /// <summary>
    /// Finds an active, non-deleted account by phone number. Returns null when
    /// no account matches so callers can avoid leaking account existence.
    /// </summary>
    Task<Guid?> FindUserIdByPhoneAsync(string phoneNumber, CancellationToken cancellationToken = default);

    /// <summary>
    /// Paginated patient search for the admin console.
    /// Searches email, full name, and phone number.
    /// </summary>
    Task<PagedPatientsResult> GetPatientPageAsync(
        string? search,
        int pageNumber,
        int pageSize,
        CancellationToken cancellationToken = default);
}
