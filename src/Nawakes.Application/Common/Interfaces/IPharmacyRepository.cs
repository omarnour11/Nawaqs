using Nawakes.Application.Search.Queries.SearchMedication;

namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// General-purpose pharmacy repository for non-search operations.
/// Search-specific queries use IPharmacySearchRepository.
/// </summary>
public interface IPharmacyRepository
{
    Task<PharmacyDetailDto?> GetByIdAsync(Guid pharmacyId, CancellationToken cancellationToken = default);
    Task<bool> ExistsByOwnerIdAsync(Guid ownerId, CancellationToken cancellationToken = default);
}
