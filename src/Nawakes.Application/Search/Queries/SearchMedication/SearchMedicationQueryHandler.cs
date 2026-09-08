using MediatR;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Search.Queries.SearchMedication;

/// <summary>
/// Handles the geospatial medication search.
/// Flow: Redis check → DB spatial query on miss → cache result → return.
/// Redis failure is caught and logged; falls through to DB transparently.
/// </summary>
public sealed class SearchMedicationQueryHandler(
    IPharmacySearchRepository searchRepository,
    ICacheService cache,
    ILogger<SearchMedicationQueryHandler> logger)
    : IRequestHandler<SearchMedicationQuery, SearchMedicationResponse>
{
    // TTL as per Redis strategy: 3 minutes
    private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(3);

    // TrustScore threshold below which pharmacies are de-ranked
    private const decimal DeRankThreshold = 40m;

    public async Task<SearchMedicationResponse> Handle(
        SearchMedicationQuery request,
        CancellationToken cancellationToken)
    {
        var cacheKey = BuildCacheKey(request);

        // 1. Attempt Redis cache read (never throws — graceful degradation inside ICacheService)
        var cached = await cache.GetAsync<SearchMedicationResponse>(cacheKey, cancellationToken);
        if (cached is not null)
        {
            logger.LogDebug("Cache HIT for key {CacheKey}", cacheKey);
            // Return with CacheHit flag flipped to true
            return cached with { CacheHit = true };
        }

        logger.LogDebug("Cache MISS for key {CacheKey}. Querying database.", cacheKey);

        // 2. DB spatial query via repository (Infrastructure concern)
        var rawResults = await searchRepository.SearchAsync(
            medicationNameNormalized: request.Medication.Trim().ToUpperInvariant(),
            latitude: request.Lat,
            longitude: request.Lng,
            radiusKm: (double)request.RadiusKm,
            cancellationToken: cancellationToken);

        // 3. Apply sort
        var sorted = ApplySort(rawResults, request.SortBy);

        // 4. De-rank low-trust pharmacies (appear after normal results)
        var deRanked = sorted
            .Where(r => r.TrustScore >= DeRankThreshold)
            .Concat(sorted.Where(r => r.TrustScore < DeRankThreshold))
            .ToList();

        var response = new SearchMedicationResponse
        {
            Results = deRanked,
            TotalCount = deRanked.Count,
            CacheHit = false,
            RadiusKm = request.RadiusKm
        };

        // 5. Write to cache (failure is silently swallowed in ICacheService impl)
        await cache.SetAsync(cacheKey, response, CacheTtl, cancellationToken);

        return response;
    }

    private static string BuildCacheKey(SearchMedicationQuery q)
    {
        // Round coordinates to 2 decimal places (~1.1 km grid) for cache sharing
        var latRounded = Math.Round(q.Lat, 2);
        var lngRounded = Math.Round(q.Lng, 2);
        var medNorm = q.Medication.Trim().ToLowerInvariant().Replace(' ', '_');
        return $"nawakes:search:{medNorm}:{latRounded}:{lngRounded}:{q.RadiusKm}:{q.SortBy}";
    }

    private static IReadOnlyList<PharmacySearchResultDto> ApplySort(
        IEnumerable<PharmacySearchResultDto> results,
        string sortBy) => sortBy switch
    {
        "Price"   => [.. results.OrderBy(r => r.Price)],
        "Rating"  => [.. results.OrderByDescending(r => r.TrustScore)],
        _         => [.. results.OrderBy(r => r.DistanceKm)]  // Distance (default)
    };
}
