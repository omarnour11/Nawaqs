using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Shortage.Queries.GetOpenShortageRequests;

/// <summary>Open shortage requests near a pharmacy (for the pharmacist's queue).</summary>
public sealed record GetOpenShortageRequestsQuery(double Latitude, double Longitude, double RadiusKm = 15)
    : IRequest<IReadOnlyList<ShortageRequestDto>>;

public sealed record ShortageRequestDto(
    Guid Id,
    string MedicationName,
    string? Strength,
    int QuantityNeeded,
    string? Notes,
    double DistanceKm,
    DateTime CreatedAt,
    DateTime ExpiresAt);

public sealed class GetOpenShortageRequestsQueryHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<GetOpenShortageRequestsQuery, IReadOnlyList<ShortageRequestDto>>
{
    public async Task<IReadOnlyList<ShortageRequestDto>> Handle(
        GetOpenShortageRequestsQuery request, CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken);

        if (pharmacy?.GeoPoint is null) return [];

        var userLoc = NetTopologySuite.Geometries.GeometryFactory.Default
            .CreatePoint(new NetTopologySuite.Geometries.Coordinate(request.Longitude, request.Latitude));
        userLoc.SRID = 4326;

        // Use the patient's posted location as the anchor: distance from THIS pharmacy
        // to each request's origin point.
        var rows = await context.ShortageRequests
            .AsNoTracking()
            .Where(r => r.Status == ShortageRequestStatus.Open && r.ExpiresAt > DateTime.UtcNow)
            .Select(r => new
            {
                r.Id,
                r.MedicationName,
                r.Strength,
                r.QuantityNeeded,
                r.Notes,
                r.CreatedAt,
                r.ExpiresAt,
                DistanceKm = r.GeoPoint.Distance(pharmacy.GeoPoint) / 1000.0
            })
            .Where(r => r.DistanceKm <= request.RadiusKm)
            .OrderBy(r => r.DistanceKm)
            .ToListAsync(cancellationToken);

        return rows.Select(r => new ShortageRequestDto(
            r.Id, r.MedicationName, r.Strength, r.QuantityNeeded,
            r.Notes, r.DistanceKm, r.CreatedAt, r.ExpiresAt)).ToList();
    }
}
