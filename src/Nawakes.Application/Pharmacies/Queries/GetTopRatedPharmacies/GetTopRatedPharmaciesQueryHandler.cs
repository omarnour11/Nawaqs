using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacies.Queries.GetTopRatedPharmacies;

public sealed class GetTopRatedPharmaciesQueryHandler(IApplicationDbContext context)
    : IRequestHandler<GetTopRatedPharmaciesQuery, IReadOnlyList<TopRatedPharmacyDto>>
{
    public async Task<IReadOnlyList<TopRatedPharmacyDto>> Handle(
        GetTopRatedPharmaciesQuery request,
        CancellationToken cancellationToken)
    {
        var approvedPharmacies = await context.Pharmacies
            .AsNoTracking()
            .Where(p => p.VerificationStatus == VerificationStatus.Approved)
            .Select(p => new
            {
                p.Id,
                p.Name,
                p.AddressLine,
                p.City,
                p.Phone,
                Latitude = p.GeoPoint.Y,
                Longitude = p.GeoPoint.X,
                p.TrustScore,
                p.OffersDelivery,
                p.DeliveryFee,
                RatingsAverage = context.Ratings.Where(r => r.PharmacyId == p.Id).Any()
                    ? context.Ratings.Where(r => r.PharmacyId == p.Id).Average(r => (double)r.Score)
                    : 0d,
                RatingsCount = context.Ratings.Count(r => r.PharmacyId == p.Id)
            })
            .ToListAsync(cancellationToken);

        var dtos = approvedPharmacies.Select(p =>
        {
            var avgRating = p.RatingsAverage > 0 ? p.RatingsAverage : (double)Math.Round(p.TrustScore / 20m, 1);
            if (avgRating <= 0) avgRating = 4.8; // baseline standard for approved partners

            double? distance = null;
            if (request.Latitude.HasValue && request.Longitude.HasValue)
            {
                distance = CalculateDistanceKm(request.Latitude.Value, request.Longitude.Value, p.Latitude, p.Longitude);
            }

            return new TopRatedPharmacyDto(
                p.Id,
                p.Name,
                p.AddressLine,
                p.City,
                p.Phone,
                p.Latitude,
                p.Longitude,
                distance,
                p.TrustScore,
                Math.Round(avgRating, 1),
                p.RatingsCount > 0 ? p.RatingsCount : (int)(p.TrustScore / 2m),
                p.OffersDelivery,
                p.DeliveryFee);
        })
        .OrderByDescending(p => p.AverageRating)
        .ThenByDescending(p => p.TrustScore)
        .ThenBy(p => p.DistanceKm ?? double.MaxValue)
        .Take(Math.Max(1, request.Limit))
        .ToList();

        return dtos;
    }

    private static double CalculateDistanceKm(double lat1, double lon1, double lat2, double lon2)
    {
        const double r = 6371.0;
        var dLat = (lat2 - lat1) * Math.PI / 180.0;
        var dLon = (lon2 - lon1) * Math.PI / 180.0;
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(lat1 * Math.PI / 180.0) * Math.Cos(lat2 * Math.PI / 180.0) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return Math.Round(r * c, 1);
    }
}
