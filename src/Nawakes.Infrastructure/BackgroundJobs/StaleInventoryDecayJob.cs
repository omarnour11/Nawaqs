using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.BackgroundJobs;

/// <summary>
/// Slice 1.5: Egyptian Pharmacy Inventory Freshness
/// Daily Hangfire recurring job that flags inventory items not updated or verified for > 14 days
/// as 'Unconfirmed' to prevent misleading patients with stale stock data.
/// </summary>
public sealed class StaleInventoryDecayJob(
    ApplicationDbContext context,
    ILogger<StaleInventoryDecayJob> logger)
{
    [DisableConcurrentExecution(timeoutInSeconds: 60)]
    [AutomaticRetry(Attempts = 3, DelaysInSeconds = [30, 120, 300])]
    public async Task DecayStaleInventoryAsync(CancellationToken cancellationToken = default)
    {
        var cutoff = DateTime.UtcNow.AddDays(-14);
        logger.LogInformation("StaleInventoryDecayJob running: identifying items older than {Cutoff}", cutoff);

        var staleItems = await context.InventoryItems
            .Where(i => i.Status == InventoryStatus.InStock && i.UpdatedAt < cutoff && !i.IsDeleted)
            .ToListAsync(cancellationToken);

        if (staleItems.Count == 0)
        {
            logger.LogInformation("StaleInventoryDecayJob completed: no stale items found.");
            return;
        }

        foreach (var item in staleItems)
        {
            item.Status = InventoryStatus.Unconfirmed;
            item.UpdatedAt = DateTime.UtcNow;
        }

        await context.SaveChangesAsync(cancellationToken);

        logger.LogWarning(
            "StaleInventoryDecayJob: Marked {Count} stale inventory items as Unconfirmed",
            staleItems.Count);
    }
}
