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
            .Where(r => r.PharmacyId == pharmacyId && r.CreatedAt >= thirtyDaysAgo)
            .ToListAsync(cancellationToken);

        int inaccurateCount = recentReports.Count(r => r.Type == ReportType.Inaccurate);
        int foundCount = recentReports.Count(r => r.Type == ReportType.Found);

        // Base score
        decimal score = 100m;

        // Apply rules
        score -= (inaccurateCount * 5m);
        score += (foundCount * 2m);

        // Clamp 0-100
        score = Math.Max(0m, Math.Min(100m, score));

        pharmacy.TrustScore = score;
        pharmacy.TrustScoreUpdatedAt = DateTime.UtcNow;

        await context.SaveChangesAsync(cancellationToken);

        logger.LogInformation("Trust score for Pharmacy {PharmacyId} recalculated to {Score}.", pharmacyId, score);
    }
}
