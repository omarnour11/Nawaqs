using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Common;
using Nawakes.Domain.Enums;
using NetTopologySuite.Geometries;

namespace Nawakes.Application.Search.Queries.GetMedicationEquivalents;

/// <summary>
/// Deterministic bioequivalent substitution (Phase 4). Matching is strictly
/// SQL: same active ingredient + same strength + same dosage form — zero AI.
/// Joins nearby in-stock inventory and computes price savings vs. the
/// original's official price.
/// </summary>
public sealed class GetMedicationEquivalentsQueryHandler(
    IApplicationDbContext context)
    : IRequestHandler<GetMedicationEquivalentsQuery, MedicationEquivalentsResponse>
{
    public const string LegalDisclaimerText =
        "⚠️ تنبيه طبي: هذا بديل متطابق بنفس المادة الفعالة والتركيز. استشر الصيدلي أو الطبيب دائماً قبل الاستبدال";

    public async Task<MedicationEquivalentsResponse> Handle(
        GetMedicationEquivalentsQuery request, CancellationToken cancellationToken)
    {
        var sourceNorm = DrugNameNormalizer.NormalizeName(request.MedicationName);
        if (sourceNorm.Length == 0)
        {
            return new MedicationEquivalentsResponse(null, [], LegalDisclaimerText);
        }

        var source = await context.EgyptianDrugRegistry
            .AsNoTracking()
            .FirstOrDefaultAsync(d => d.TradeNameNormalized == sourceNorm, cancellationToken);

        // No active ingredient on file → substitute feature stays hidden (never guess)
        if (source?.ActiveIngredientNormalized is null)
        {
            return new MedicationEquivalentsResponse(
                source is null ? null : ToOriginal(source, false),
                [], LegalDisclaimerText);
        }

        var searcherLocation = new Point(request.Lng, request.Lat) { SRID = 4326 };

        var equivalents = await context.EgyptianDrugRegistry
            .AsNoTracking()
            .Where(d => d.ActiveIngredientNormalized == source.ActiveIngredientNormalized &&
                        d.Strength == source.Strength &&
                        d.DosageForm == source.DosageForm &&
                        d.Id != source.Id)
            .Select(d => new { d.Id, d.TradeName, d.Manufacturer, d.OfficialPriceEGP })
            .ToListAsync(cancellationToken);

        if (equivalents.Count == 0)
        {
            return new MedicationEquivalentsResponse(ToOriginal(source, false), [], LegalDisclaimerText);
        }

        var equivalentNames = equivalents
            .Select(e => DrugNameNormalizer.NormalizeLookup(e.TradeName))
            .ToHashSet();

        var radiusMeters = (double)request.RadiusKm * 1000;

        var inStockNearby = await context.InventoryItems
            .AsNoTracking()
            .Where(i => i.Status == InventoryStatus.InStock &&
                        i.Quantity > 0 &&
                        equivalentNames.Contains(i.MedicationNameNormalized.ToLower()) &&
                        i.Pharmacy.VerificationStatus == VerificationStatus.Approved &&
                        i.Pharmacy.GeoPoint.Distance(searcherLocation) <= radiusMeters &&
                        !i.Pharmacy.IsDeleted)
            .Select(i => new
            {
                i.Id,
                i.MedicationName,
                i.Price,
                PharmacyId = i.Pharmacy.Id,
                PharmacyName = i.Pharmacy.Name,
                Distance = i.Pharmacy.GeoPoint.Distance(searcherLocation)
            })
            .OrderBy(i => i.Distance)
            .Take(20)
            .ToListAsync(cancellationToken);

        var originalOfficialPrice = source.OfficialPriceEGP;

        var results = inStockNearby
            .Select(i =>
            {
                var match = equivalents.FirstOrDefault(e =>
                    DrugNameNormalizer.NormalizeLookup(e.TradeName) == i.MedicationName.Trim().ToLowerInvariant());
                var saving = originalOfficialPrice is > 0 && i.Price < originalOfficialPrice
                    ? Math.Round((originalOfficialPrice.Value - i.Price) / originalOfficialPrice.Value * 100m, 0)
                    : 0m;
                return new EquivalentPharmacyResult(
                    i.MedicationName,
                    match?.Manufacturer,
                    match?.OfficialPriceEGP ?? i.Price,
                    saving,
                    i.PharmacyId,
                    i.PharmacyName,
                    Math.Round(i.Distance / 1000, 2),
                    i.Id,
                    i.Price);
            })
            .ToList();

        var isAvailableNearby = await context.InventoryItems
            .AsNoTracking()
            .AnyAsync(i => i.Status == InventoryStatus.InStock &&
                           i.Quantity > 0 &&
                           i.MedicationNameNormalized.ToLower() == source.TradeNameNormalized.ToLower() &&
                           i.Pharmacy.VerificationStatus == VerificationStatus.Approved &&
                           i.Pharmacy.GeoPoint.Distance(searcherLocation) <= radiusMeters &&
                           !i.Pharmacy.IsDeleted, cancellationToken);

        return new MedicationEquivalentsResponse(
            ToOriginal(source, isAvailableNearby),
            results,
            LegalDisclaimerText);
    }

    private static OriginalMedicationInfo ToOriginal(Domain.Entities.EgyptianDrugRegistry source, bool isAvailableNearby) =>
        new(source.TradeName, source.ActiveIngredient, source.Strength,
            source.DosageForm, source.OfficialPriceEGP, isAvailableNearby);
}
