using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Queries.SearchMedication;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.Persistence.Repositories;

/// <summary>
/// General-purpose pharmacy repository.
/// Only exposes Approved, non-soft-deleted pharmacies.
/// The global HasQueryFilter(e => !e.IsDeleted) is applied automatically by EF Core.
/// </summary>
public sealed class PharmacyRepository(ApplicationDbContext context) : IPharmacyRepository
{
    public async Task<PharmacyDetailDto?> GetByIdAsync(
        Guid pharmacyId,
        CancellationToken cancellationToken = default)
    {
        return await context.Pharmacies
            .AsNoTracking()
            .Where(p => p.Id == pharmacyId &&
                        p.VerificationStatus == VerificationStatus.Approved)
            .Select(p => new PharmacyDetailDto
            {
                Id                 = p.Id,
                Name               = p.Name,
                AddressLine        = p.AddressLine,
                City               = p.City,
                Phone              = p.Phone,
                TrustScore         = p.TrustScore,
                VerificationStatus = nameof(VerificationStatus.Approved),
                Latitude           = p.GeoPoint.Y,   // NTS: Y = latitude
                Longitude          = p.GeoPoint.X,   // NTS: X = longitude
                DirectionsUrl      = $"https://www.google.com/maps/dir/?api=1&destination={p.GeoPoint.Y},{p.GeoPoint.X}",
                CreatedAt          = p.CreatedAt
            })
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<bool> ExistsByOwnerIdAsync(
        Guid ownerId,
        CancellationToken cancellationToken = default)
    {
        return await context.Pharmacies
            .AnyAsync(p => p.OwnerId == ownerId, cancellationToken);
    }
}
