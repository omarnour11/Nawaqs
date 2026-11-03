using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.BackgroundJobs;

public sealed class TrustScoreRecalculationJob(
    ApplicationDbContext context,
    ILogger<TrustScoreRecalculationJob> logger)
{
    [AutomaticRetry(Attempts = 2)]
    public async Task RecalculateAsync(Guid pharmacyId, CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.Id == pharmacyId, cancellationToken);

        if (pharmacy is null)
            return;

        var thirtyDaysAgo = DateTime.UtcNow.AddDays(-30);

        var recentReports = await context.Reports
            .AsNoTracking()
            .Where(r => r.PharmacyId == pharmacyId && r.CreatedAt >= thirtyDaysAgo)
            .ToListAsync(cancellationToken);

        int inaccurateCount = recentReports.Count(r => r.Type == ReportType.Inaccurate);
        int foundCount = recentReports.Count(r => r.Type == ReportType.Found);
        int priceGougingReportsCount = recentReports.Count(r =>
            r.Type == ReportType.PriceGouging || r.ReportedPrice is > 0);

        // Audit active inventory items against official EDA ceiling prices
        var activeItems = await context.InventoryItems
            .AsNoTracking()
            .Where(i => i.PharmacyId == pharmacyId && i.Status == InventoryStatus.InStock)
            .Select(i => new { i.MedicationNameNormalized, i.Price })
            .ToListAsync(cancellationToken);

        int gougedItemsCount = 0;
        int compliantItemsCount = 0;

        if (activeItems.Count > 0)
        {
            var normNames = activeItems.Select(i => i.MedicationNameNormalized).Distinct().ToList();
            var edaPrices = await context.EgyptianDrugRegistry
                .AsNoTracking()
                .Where(d => d.OfficialPriceEGP != null &&
                            d.OfficialPriceEGP > 0 &&
                            (normNames.Contains(d.TradeNameNormalized) ||
                             (d.CommercialNameArNormalized != null && normNames.Contains(d.CommercialNameArNormalized))))
                .Select(d => new
                {
                    d.TradeNameNormalized,
                    d.CommercialNameArNormalized,
                    OfficialPrice = d.OfficialPriceEGP!.Value
                })
                .ToListAsync(cancellationToken);

            foreach (var item in activeItems)
            {
                var eda = edaPrices.FirstOrDefault(d =>
                    d.TradeNameNormalized.Equals(item.MedicationNameNormalized, StringComparison.OrdinalIgnoreCase) ||
                    (d.CommercialNameArNormalized != null &&
                     d.CommercialNameArNormalized.Equals(item.MedicationNameNormalized, StringComparison.OrdinalIgnoreCase)));

                if (eda is null)
                    continue;

                // >10% above official EDA ceiling price is flagged as price gouging
                if (item.Price > eda.OfficialPrice * 1.10m)
                {
                    gougedItemsCount++;
                }
                else if (item.Price <= eda.OfficialPrice * 1.02m)
                {
                    compliantItemsCount++;
                }
            }
        }

        decimal score = CalculateTrustScore(
            inaccurateCount,
            foundCount,
            priceGougingReportsCount,
            gougedItemsCount,
            compliantItemsCount);

        pharmacy.TrustScore = score;
        pharmacy.TrustScoreUpdatedAt = DateTime.UtcNow;

        await context.SaveChangesAsync(cancellationToken);

        logger.LogInformation(
            "Trust score for Pharmacy {PharmacyId} recalculated to {Score} (GougedItems={Gouged}, CompliantItems={Compliant}).",
            pharmacyId, score, gougedItemsCount, compliantItemsCount);
    }

    public static decimal CalculateTrustScore(
        int inaccurateCount,
        int foundCount,
        int priceGougingReportsCount = 0,
        int gougedInventoryItemsCount = 0,
        int compliantCatalogItemsCount = 0)
    {
        decimal score = 100m;

        // Accuracy & fulfillment reports
        score -= inaccurateCount * 5m;
        score += foundCount * 2m;

        // Anti-gouging penalties: -8 per patient price-gouging report, -4 per inventory item >10% over EDA official price (capped at -20)
        score -= priceGougingReportsCount * 8m;
        score -= Math.Min(20m, gougedInventoryItemsCount * 4m);

        // Official EDA price compliance bonus (+5 points when 0 gouged items and >= 3 verified EDA items)
        if (gougedInventoryItemsCount == 0 && priceGougingReportsCount == 0 && compliantCatalogItemsCount >= 3)
        {
            score += 5m;
        }

        return Math.Max(0m, Math.Min(100m, score));
    }
}

