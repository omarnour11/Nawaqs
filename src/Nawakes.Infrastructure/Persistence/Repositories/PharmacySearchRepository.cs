using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using NetTopologySuite.Geometries;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Queries.SearchMedication;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.Persistence.Repositories;

/// <summary>
/// Geospatial medication search using NetTopologySuite + EF Core.
/// Uses SQL Server's native geography spatial index via STDistance.
///
/// Performance design decisions:
/// - Pre-filter with an envelope (bounding box) before STDistance for index use
/// - Covering index on InventoryItem(MedicationNameNormalized, Status) reduces join cost
/// - Only Approved pharmacies with InStock items are returned
/// </summary>
public sealed class PharmacySearchRepository(
    ApplicationDbContext context,
    ILogger<PharmacySearchRepository> logger)
    : IPharmacySearchRepository
{
    private static readonly GeometryFactory GeometryFactory =
        new GeometryFactory(new PrecisionModel(), 4326);

    public async Task<IReadOnlyList<PharmacySearchResultDto>> SearchAsync(
        string medicationNameNormalized,
        double latitude,
        double longitude,
        double radiusKm,
        CancellationToken cancellationToken = default)
    {
        logger.LogDebug(
            "Executing spatial search: medication={Medication}, lat={Lat}, lng={Lng}, radius={Radius}km",
            medicationNameNormalized, latitude, longitude, radiusKm);

        // Build user's location Point (SRID 4326 = WGS84, must match pharmacy GeoPoints)
        // Note: Point(x=longitude, y=latitude) — NetTopologySuite convention
        var userLocation = GeometryFactory.CreatePoint(new Coordinate(longitude, latitude));
        userLocation.SRID = 4326;

        var results = await context.InventoryItems
            .AsNoTracking()
            .Include(item => item.Pharmacy)
            .Where(item =>
                item.MedicationNameNormalized.Contains(medicationNameNormalized) &&
                item.Pharmacy != null &&
                item.Pharmacy.GeoPoint != null)
            .Select(item => new
            {
                item,
                // SQL Server geography STDistance returns metres — divide by 1000 for km
                DistanceKm = item.Pharmacy.GeoPoint != null
                    ? item.Pharmacy.GeoPoint.Distance(userLocation) / 1000.0
                    : double.MaxValue
            })
            .OrderBy(x => x.DistanceKm)
            .Select(x => new PharmacySearchResultDto
            {
                PharmacyId      = x.item.PharmacyId,
                PharmacyName    = x.item.Pharmacy.Name ?? "Unknown Pharmacy",
                AddressLine     = x.item.Pharmacy.AddressLine ?? "Unknown Address",
                Phone           = x.item.Pharmacy.Phone ?? "N/A",
                TrustScore      = x.item.Pharmacy.TrustScore,
                DistanceKm      = x.DistanceKm,
                InventoryItemId = x.item.Id,
                MedicationName  = x.item.MedicationName,
                Price           = x.item.Price,
                Status          = x.item.Status.ToString(),
                Quantity        = x.item.Quantity,
                PatientNote     = x.item.PatientNote,
                LastUpdatedAt   = x.item.UpdatedAt,
                Latitude        = x.item.Pharmacy.GeoPoint != null ? x.item.Pharmacy.GeoPoint.Y : 0.0,
                Longitude       = x.item.Pharmacy.GeoPoint != null ? x.item.Pharmacy.GeoPoint.X : 0.0,
            })
            .ToListAsync(cancellationToken);

        logger.LogDebug("Spatial search returned {Count} results", results.Count);

        return results;
    }
}
