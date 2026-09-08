using Nawakes.Application.Search.Queries.SearchMedication;

namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// Repository interface for pharmacy spatial search queries.
/// Lives in Application so the handler can depend on it; implementation is in Infrastructure.
/// </summary>
public interface IPharmacySearchRepository
{
    /// <param name="medicationNameNormalized">UPPER-cased, trimmed medication name for case-insensitive match.</param>
    /// <param name="latitude">WGS84 latitude of the searcher.</param>
    /// <param name="longitude">WGS84 longitude of the searcher.</param>
    /// <param name="radiusKm">Search radius in kilometres.</param>
    Task<IReadOnlyList<PharmacySearchResultDto>> SearchAsync(
        string medicationNameNormalized,
        double latitude,
        double longitude,
        double radiusKm,
        CancellationToken cancellationToken = default);
}
