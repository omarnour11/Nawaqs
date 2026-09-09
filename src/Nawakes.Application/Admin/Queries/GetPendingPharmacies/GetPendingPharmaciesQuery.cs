using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Admin.Queries.GetPendingPharmacies;

public sealed record GetPendingPharmaciesQuery(bool IncludeAll = false)
    : IRequest<IReadOnlyList<AdminPharmacyDto>>;

public sealed record AdminPharmacyDto(
    Guid Id,
    Guid OwnerId,
    string OwnerEmail,
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
    int InventoryCount,
    DateTime CreatedAt);

public sealed class GetPendingPharmaciesQueryHandler(IApplicationDbContext context, IUserDirectory users)
    : IRequestHandler<GetPendingPharmaciesQuery, IReadOnlyList<AdminPharmacyDto>>
{
    public async Task<IReadOnlyList<AdminPharmacyDto>> Handle(
        GetPendingPharmaciesQuery request, CancellationToken cancellationToken)
    {
        var query = context.Pharmacies.AsNoTracking();

        if (!request.IncludeAll)
            query = query.Where(p => p.VerificationStatus == VerificationStatus.Pending);

        var rows = await query
            .OrderBy(p => p.VerificationStatus == VerificationStatus.Pending ? 0 : 1)
            .ThenBy(p => p.CreatedAt)
            .Select(p => new
            {
                p.Id,
                p.OwnerId,
                p.Name,
                p.AddressLine,
                p.City,
                p.Phone,
                Lat = p.GeoPoint.Y,
                Lng = p.GeoPoint.X,
                Status = p.VerificationStatus,
                p.RejectionReason,
                p.LicenseDocUrl,
                p.NationalIdDocUrl,
                p.TrustScore,
                InventoryCount = context.InventoryItems.Count(i => i.PharmacyId == p.Id),
                p.CreatedAt
            })
            .ToListAsync(cancellationToken);

        var emails = await users.GetEmailsAsync(rows.Select(r => r.OwnerId).ToList(), cancellationToken);

        return rows.Select(r => new AdminPharmacyDto(
            r.Id, r.OwnerId,
            emails.GetValueOrDefault(r.OwnerId, ""),
            r.Name, r.AddressLine, r.City, r.Phone, r.Lat, r.Lng,
            r.Status.ToString(), r.RejectionReason, r.LicenseDocUrl, r.NationalIdDocUrl,
            r.TrustScore, r.InventoryCount, r.CreatedAt)).ToList();
    }
}
