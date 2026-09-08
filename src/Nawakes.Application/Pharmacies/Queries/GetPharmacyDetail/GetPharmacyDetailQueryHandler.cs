using MediatR;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Queries.SearchMedication;

namespace Nawakes.Application.Pharmacies.Queries.GetPharmacyDetail;

/// <summary>
/// Returns pharmacy detail from Redis cache, falls back to DB on miss.
/// Cache key: nawakes:pharmacy:detail:{id}   TTL: 10 minutes.
/// Only Approved, non-deleted pharmacies are returned (404 otherwise).
/// </summary>
public sealed class GetPharmacyDetailQueryHandler(
    IPharmacyRepository pharmacyRepository,
    ICacheService cache,
    ILogger<GetPharmacyDetailQueryHandler> logger)
    : IRequestHandler<GetPharmacyDetailQuery, PharmacyDetailDto>
{
    private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(10);

    public async Task<PharmacyDetailDto> Handle(
        GetPharmacyDetailQuery request,
        CancellationToken cancellationToken)
    {
        var cacheKey = $"nawakes:pharmacy:detail:{request.PharmacyId}";

        // 1. Redis check
        var cached = await cache.GetAsync<PharmacyDetailDto>(cacheKey, cancellationToken);
        if (cached is not null)
        {
            logger.LogDebug("Cache HIT pharmacy detail {PharmacyId}", request.PharmacyId);
            return cached;
        }

        // 2. DB lookup
        var pharmacy = await pharmacyRepository.GetByIdAsync(request.PharmacyId, cancellationToken);

        if (pharmacy is null)
            throw new NotFoundException(nameof(Nawakes.Domain.Entities.Pharmacy), request.PharmacyId);

        // 3. Cache result
        await cache.SetAsync(cacheKey, pharmacy, CacheTtl, cancellationToken);

        return pharmacy;
    }
}
