using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Pharmacies.Queries.GetMyFavorites;

public sealed record GetMyFavoritesQuery : IRequest<IReadOnlyList<FavoritePharmacyDto>>;

public sealed record FavoritePharmacyDto(
    Guid PharmacyId,
    string Name,
    string AddressLine,
    string City,
    string Phone,
    double Latitude,
    double Longitude,
    decimal TrustScore,
    double AverageRating,
    int RatingCount);

public sealed class GetMyFavoritesQueryHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<GetMyFavoritesQuery, IReadOnlyList<FavoritePharmacyDto>>
{
    public async Task<IReadOnlyList<FavoritePharmacyDto>> Handle(GetMyFavoritesQuery request, CancellationToken cancellationToken)
    {
        return await context.Favorites
            .AsNoTracking()
            .Where(f => f.UserId == currentUser.UserId)
            .Select(f => new FavoritePharmacyDto(
                f.PharmacyId,
                context.Pharmacies.Where(p => p.Id == f.PharmacyId).Select(p => p.Name).First(),
                context.Pharmacies.Where(p => p.Id == f.PharmacyId).Select(p => p.AddressLine).First(),
                context.Pharmacies.Where(p => p.Id == f.PharmacyId).Select(p => p.City).First(),
                context.Pharmacies.Where(p => p.Id == f.PharmacyId).Select(p => p.Phone).First(),
                context.Pharmacies.Where(p => p.Id == f.PharmacyId).Select(p => p.GeoPoint.Y).First(),
                context.Pharmacies.Where(p => p.Id == f.PharmacyId).Select(p => p.GeoPoint.X).First(),
                context.Pharmacies.Where(p => p.Id == f.PharmacyId).Select(p => p.TrustScore).First(),
                context.Ratings.Where(r => r.PharmacyId == f.PharmacyId).Any()
                    ? context.Ratings.Where(r => r.PharmacyId == f.PharmacyId).Average(r => (double)r.Score)
                    : 0d,
                context.Ratings.Count(r => r.PharmacyId == f.PharmacyId)))
            .ToListAsync(cancellationToken);
    }
}
