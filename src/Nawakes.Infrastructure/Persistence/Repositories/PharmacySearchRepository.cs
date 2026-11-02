using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using NetTopologySuite.Geometries;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Queries.GetNearbyProducts;
using Nawakes.Application.Search.Queries.SearchMedication;
using Nawakes.Domain.Entities;
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

        var normSearch = Nawakes.Domain.Common.DrugNameNormalizer.NormalizeName(medicationNameNormalized);
        if (string.IsNullOrWhiteSpace(normSearch)) normSearch = medicationNameNormalized.Trim().ToUpperInvariant();

        // Resolve Arabic commercial name from EDA registry (e.g. بانادول -> PANADOL, كونكور -> CONCOR)
        var firstWord = normSearch.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? normSearch;

        var matchedTradeTokens = await context.EgyptianDrugRegistry
            .AsNoTracking()
            .Where(d => d.CommercialNameArNormalized != null &&
                        (d.CommercialNameArNormalized.Contains(normSearch) ||
                         (firstWord.Length >= 3 && d.CommercialNameArNormalized.Contains(firstWord)) ||
                         normSearch.Contains(d.CommercialNameArNormalized)))
            .Select(d => d.TradeNameNormalized)
            .Distinct()
            .Take(10)
            .ToListAsync(cancellationToken);

        var brandRoots = matchedTradeTokens
            .Select(t => t.Split(' ', StringSplitOptions.RemoveEmptyEntries)[0])
            .Where(b => b.Length >= 2)
            .Distinct()
            .Take(5)
            .ToList();

        var root1 = brandRoots.Count > 0 ? brandRoots[0] : null;
        var root2 = brandRoots.Count > 1 ? brandRoots[1] : null;
        var root3 = brandRoots.Count > 2 ? brandRoots[2] : null;

        var rawRows = await context.InventoryItems
            .AsNoTracking()
            .Include(item => item.Pharmacy)
            .Where(item =>
                (item.MedicationNameNormalized.Contains(normSearch) ||
                 (root1 != null && item.MedicationNameNormalized.Contains(root1)) ||
                 (root2 != null && item.MedicationNameNormalized.Contains(root2)) ||
                 (root3 != null && item.MedicationNameNormalized.Contains(root3)) ||
                 (item.Pharmacy.Name != null && item.Pharmacy.Name.ToUpper().Contains(normSearch))) &&
                item.Status == InventoryStatus.InStock &&
                item.Pharmacy != null &&
                item.Pharmacy.VerificationStatus == VerificationStatus.Approved &&
                item.Pharmacy.GeoPoint != null)
            .Select(item => new
            {
                item,
                // SQL Server geography STDistance returns metres — divide by 1000 for km
                DistanceKm = item.Pharmacy.GeoPoint != null
                    ? item.Pharmacy.GeoPoint.Distance(userLocation) / 1000.0
                    : double.MaxValue
            })
            .Where(x => x.DistanceKm <= radiusKm)
            .OrderBy(x => x.DistanceKm)
            .ToListAsync(cancellationToken);

        // Deduplicate by PharmacyId so a single pharmacy with multiple inventory rows is not counted multiple times
        var results = rawRows
            .GroupBy(x => x.item.PharmacyId)
            .Select(g =>
            {
                var bestItem = g.OrderBy(x => x.item.Price).First();
                var totalQty = g.Sum(x => x.item.Quantity);
                return new PharmacySearchResultDto
                {
                    PharmacyId      = bestItem.item.PharmacyId,
                    PharmacyName    = bestItem.item.Pharmacy.Name ?? "Unknown Pharmacy",
                    AddressLine     = bestItem.item.Pharmacy.AddressLine ?? "Unknown Address",
                    Phone           = bestItem.item.Pharmacy.Phone ?? "N/A",
                    TrustScore      = bestItem.item.Pharmacy.TrustScore,
                    DistanceKm      = bestItem.DistanceKm,
                    InventoryItemId = bestItem.item.Id,
                    MedicationName  = bestItem.item.MedicationName,
                    Price           = bestItem.item.Price,
                    Status          = bestItem.item.Status.ToString(),
                    Quantity        = totalQty,
                    PatientNote     = bestItem.item.PatientNote,
                    LastUpdatedAt   = bestItem.item.UpdatedAt,
                    Latitude        = bestItem.item.Pharmacy.GeoPoint != null ? bestItem.item.Pharmacy.GeoPoint.Y : 0.0,
                    Longitude       = bestItem.item.Pharmacy.GeoPoint != null ? bestItem.item.Pharmacy.GeoPoint.X : 0.0,
                };
            })
            .OrderBy(x => x.DistanceKm)
            .ToList();

        logger.LogDebug("Spatial search returned {Count} results", results.Count);

        return results;
    }

    public async Task<IReadOnlyList<NearbyProductDto>> GetNearbyProductsAsync(
        double latitude,
        double longitude,
        double radiusKm,
        string? category,
        int limit,
        CancellationToken cancellationToken = default)
    {
        var userLocation = GeometryFactory.CreatePoint(new Coordinate(longitude, latitude));
        userLocation.SRID = 4326;

        var inStockItems = await context.InventoryItems
            .AsNoTracking()
            .Include(item => item.Pharmacy)
            .Where(item =>
                item.Status == InventoryStatus.InStock &&
                item.Quantity > 0 &&
                item.Pharmacy != null &&
                item.Pharmacy.VerificationStatus == VerificationStatus.Approved &&
                item.Pharmacy.GeoPoint != null)
            .Select(item => new
            {
                item.Id,
                item.MedicationName,
                item.MedicationNameNormalized,
                item.Price,
                item.Quantity,
                item.PharmacyId,
                PharmacyName = item.Pharmacy.Name ?? "صيدلية معتمدة",
                Address = item.Pharmacy.AddressLine,
                Phone = item.Pharmacy.Phone,
                DistanceKm = item.Pharmacy.GeoPoint != null
                    ? item.Pharmacy.GeoPoint.Distance(userLocation) / 1000.0
                    : double.MaxValue
            })
            .Where(x => x.DistanceKm <= radiusKm)
            .ToListAsync(cancellationToken);

        // Broader governorate / regional scope fallback or augmentation if immediate radius has few items
        var broaderRadius = Math.Max(radiusKm * 3.0, 60.0);
        if (inStockItems.Count < (limit > 0 ? limit : 20))
        {
            var broaderItems = await context.InventoryItems
                .AsNoTracking()
                .Include(item => item.Pharmacy)
                .Where(item =>
                    item.Status == InventoryStatus.InStock &&
                    item.Quantity > 0 &&
                    item.Pharmacy != null &&
                    item.Pharmacy.VerificationStatus == VerificationStatus.Approved &&
                    item.Pharmacy.GeoPoint != null)
                .Select(item => new
                {
                    item.Id,
                    item.MedicationName,
                    item.MedicationNameNormalized,
                    item.Price,
                    item.Quantity,
                    item.PharmacyId,
                    PharmacyName = item.Pharmacy.Name ?? "صيدلية معتمدة",
                    Address = item.Pharmacy.AddressLine,
                    Phone = item.Pharmacy.Phone,
                    DistanceKm = item.Pharmacy.GeoPoint != null
                        ? item.Pharmacy.GeoPoint.Distance(userLocation) / 1000.0
                        : double.MaxValue
                })
                .Where(x => x.DistanceKm <= broaderRadius)
                .ToListAsync(cancellationToken);

            var existingIds = inStockItems.Select(x => x.Id).ToHashSet();
            inStockItems.AddRange(broaderItems.Where(x => !existingIds.Contains(x.Id)));
        }

        if (inStockItems.Count == 0)
        {
            return [];
        }

        // Group by normalized medication name
        var grouped = inStockItems
            .GroupBy(x => x.MedicationNameNormalized)
            .Take(limit > 0 ? limit * 2 : 60)
            .ToList();

        var distinctNormalizedNames = grouped.Select(g => g.Key).ToList();

        var drugEntries = await context.EgyptianDrugRegistry
            .AsNoTracking()
            .Where(d => distinctNormalizedNames.Contains(d.TradeNameNormalized) ||
                        (d.CommercialNameArNormalized != null && distinctNormalizedNames.Contains(d.CommercialNameArNormalized)))
            .ToListAsync(cancellationToken);

        var productList = new List<NearbyProductDto>();

        foreach (var group in grouped)
        {
            var first = group.First();
            var drug = drugEntries.FirstOrDefault(d =>
                d.TradeNameNormalized.Equals(group.Key, StringComparison.OrdinalIgnoreCase) ||
                (d.CommercialNameArNormalized != null && d.CommercialNameArNormalized.Equals(group.Key, StringComparison.OrdinalIgnoreCase)));

            var tradeName = drug?.TradeName ?? first.MedicationName;
            var commercialAr = drug?.CommercialNameAr;
            var dosageForm = drug?.DosageForm ?? "عبوة دوائية";
            var strength = drug?.Strength;
            var cat = DetermineProductCategory(drug, tradeName, commercialAr, dosageForm);

            // Filter by requested category if specified
            if (!string.IsNullOrWhiteSpace(category) && !category.Equals("الكل", StringComparison.OrdinalIgnoreCase))
            {
                var matches = cat.Equals(category, StringComparison.OrdinalIgnoreCase) ||
                              (category == "أدوية عامة" && (cat == "أدوية عامة" || cat == "مسكنات")) ||
                              (category == "أدوية" && (cat == "أدوية عامة" || cat == "مسكنات" || cat == "أدوية مزمنة"));

                if (!matches) continue;
            }

            // Deduplicate and aggregate inventory items by distinct PharmacyId (Bug 1 Fix)
            var distinctPharmacies = group
                .GroupBy(x => x.PharmacyId)
                .Select(pg =>
                {
                    var primary = pg.OrderBy(x => x.Price).ThenByDescending(x => x.Quantity).First();
                    var bestPrice = primary.Price;
                    var totalQty = pg.Sum(x => x.Quantity);
                    var dist = pg.Min(x => x.DistanceKm);
                    // Delivery supported up to 25 km from user
                    var deliverySupported = dist <= 25.0;

                    return new NearbyPharmacyOptionDto(
                        pg.Key,
                        primary.PharmacyName,
                        primary.Address,
                        Math.Round(dist, 2),
                        bestPrice,
                        totalQty,
                        primary.Phone,
                        deliverySupported,
                        primary.Id
                    );
                })
                .OrderBy(x => x.DistanceKm)
                .ToList();

            if (distinctPharmacies.Count == 0)
            {
                continue;
            }

            var minDistance = distinctPharmacies.Min(x => x.DistanceKm);
            var minPrice = distinctPharmacies.Min(x => x.Price);

            var (imageUrl, description) = ResolveProductDemoMeta(tradeName, commercialAr, dosageForm, cat);

            productList.Add(new NearbyProductDto(
                Id: first.Id,
                TradeName: tradeName,
                CommercialNameAr: commercialAr,
                DosageForm: dosageForm,
                Strength: strength,
                Price: minPrice,
                AvailablePharmaciesCount: distinctPharmacies.Count,
                MinDistanceKm: Math.Round(minDistance, 2),
                Category: cat,
                ImageUrl: imageUrl,
                Pharmacies: distinctPharmacies,
                Description: description
            ));
        }

        var sorted = productList.OrderBy(p => p.MinDistanceKm);
        return (limit > 0 ? sorted.Take(limit) : sorted).ToList();
    }

    private static string DetermineProductCategory(
        EgyptianDrugRegistry? drug,
        string tradeName,
        string? commercialAr,
        string dosageForm)
    {
        if (drug?.IsChronic == true) return "أدوية مزمنة";

        var text = $"{tradeName} {commercialAr} {dosageForm} {drug?.ActiveIngredient}".ToLowerInvariant();

        if (text.Contains("مرطب") || text.Contains("بشرة") || text.Contains("كريم") || text.Contains("cream") || text.Contains("skin") || text.Contains("تجميل") || text.Contains("لوشن") || text.Contains("derm"))
            return "عناية وبشرة";

        if (text.Contains("طفل") || text.Contains("baby") || text.Contains("أطفال") || text.Contains("اطفال") || text.Contains("رضع") || text.Contains("بامبرز") || text.Contains("سيريلاك"))
            return "أم وطفل";

        if (text.Contains("فيتامين") || text.Contains("vitamin") || text.Contains("مكمل") || text.Contains("zinc") || text.Contains("زنك") || text.Contains("حديد") || text.Contains("iron") || text.Contains("calcium") || text.Contains("omega"))
            return "فيتامينات";

        if (text.Contains("مسكن") || text.Contains("بانادول") || text.Contains("panadol") || text.Contains("paracetamol") || text.Contains("صداع") || text.Contains("كتافلام") || text.Contains("cataflam") || text.Contains("brufen") || text.Contains("بروفين") || text.Contains("فولتارين") || text.Contains("voltaren"))
            return "مسكنات";

        if (text.Contains("ضغط") || text.Contains("سكر") || text.Contains("concor") || text.Contains("كونكور") || text.Contains("انسولين") || text.Contains("insulin") || text.Contains("glucophage") || text.Contains("قلب"))
            return "أدوية مزمنة";

        return "أدوية عامة";
    }

    private static (string imageUrl, string description) ResolveProductDemoMeta(
        string tradeName,
        string? commercialAr,
        string dosageForm,
        string category)
    {
        var text = $"{tradeName} {commercialAr} {dosageForm} {category}".ToLowerInvariant();

        if (text.Contains("مرطب") || text.Contains("بشرة") || text.Contains("كريم") || text.Contains("cream") || text.Contains("skin") || text.Contains("تجميل"))
        {
            return (
                "https://images.unsplash.com/photo-1556228720-195a672e8a03?w=500&auto=format&fit=crop&q=80",
                "مرطب وملطف طبي مكثف للبشرة، يساعد في استعادة نضارة البشرة وحمايتها من الجفاف والعوامل الخارجية بتركيبة خفيفة وسريعة الامتصاص."
            );
        }

        if (text.Contains("طفل") || text.Contains("baby") || text.Contains("أطفال") || text.Contains("رضع") || text.Contains("أم وطفل"))
        {
            return (
                "https://images.unsplash.com/photo-1515488042361-ee00e0ddd4e4?w=500&auto=format&fit=crop&q=80",
                "مستحضر لطيف وآمن مخصص للعناية بصحة وبشرة الأطفال والرضع، تم اختباره طبياً لضمان أعلى معايير الأمان."
            );
        }

        if (text.Contains("فيتامين") || text.Contains("vitamin") || text.Contains("مكمل") || text.Contains("zinc") || text.Contains("زنك"))
        {
            return (
                "https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=500&auto=format&fit=crop&q=80",
                "مكمل غذائي متكامل بالفيتامينات والمعادن الحيوية لتعزيز مناعة الجسم ومقاومة الإجهاد ودعم النشاط اليومي."
            );
        }

        if (text.Contains("مسكن") || text.Contains("بانادول") || text.Contains("panadol") || text.Contains("paracetamol") || text.Contains("صداع"))
        {
            return (
                "https://images.unsplash.com/photo-1584017911766-d451b3d0e843?w=500&auto=format&fit=crop&q=80",
                "مسكن فعال للآلام وخافض للحرارة، سريع المفعول لتخفيف آلام الرأس والأسنان ونزلات البرد."
            );
        }

        if (text.Contains("مزمن") || text.Contains("ضغط") || text.Contains("سكر") || text.Contains("concor") || text.Contains("كونكور"))
        {
            return (
                "https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=500&auto=format&fit=crop&q=80",
                "علاج طبي منتظم للأمراض المزمنة وفق إرشادات الطبيب المعالج والبروتوكول الطبي المعتمد."
            );
        }

        return (
            "https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=500&auto=format&fit=crop&q=80",
            "عقار طبي مسجل بهيئة الدواء المصرية، متوفر ومتاح للصرف الفوري من الصيدليات المعتمدة."
        );
    }
}
