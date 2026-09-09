using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Pharmacy.Queries.GetMyPharmacy;

public sealed record GetMyPharmacyQuery : IRequest<MyPharmacyDto?>;

public sealed record MyPharmacyDto(
    Guid Id,
    string Name,
    string AddressLine,
    string City,
    string Phone,
    double Latitude,
    double Longitude,
    string VerificationStatus,
    string? RejectionReason,
    string? LicenseDocUrl,
    string? NationalIdDocUrl,
    decimal TrustScore,
    double AverageRating,
    int RatingCount,
    DateTime CreatedAt);

public sealed class GetMyPharmacyQueryHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<GetMyPharmacyQuery, MyPharmacyDto?>
{
    public async Task<MyPharmacyDto?> Handle(GetMyPharmacyQuery request, CancellationToken cancellationToken)
    {
        return await context.Pharmacies
            .AsNoTracking()
            .Where(p => p.OwnerId == currentUser.UserId)
            .Select(p => new MyPharmacyDto(
                p.Id,
                p.Name,
                p.AddressLine,
                p.City,
                p.Phone,
                p.GeoPoint.Y,
                p.GeoPoint.X,
                p.VerificationStatus.ToString(),
                p.RejectionReason,
                p.LicenseDocUrl,
                p.NationalIdDocUrl,
                p.TrustScore,
                context.Ratings.Where(r => r.PharmacyId == p.Id).Any()
                    ? context.Ratings.Where(r => r.PharmacyId == p.Id).Average(r => (double)r.Score)
                    : 0d,
                context.Ratings.Count(r => r.PharmacyId == p.Id),
                p.CreatedAt))
            .FirstOrDefaultAsync(cancellationToken);
    }
}
