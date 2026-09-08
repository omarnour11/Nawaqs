using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.BackgroundJobs;

/// <summary>
/// Fans out FCM notifications to matching subscribers within radius when an item becomes InStock.
/// </summary>
public sealed class InventoryAvailabilityNotificationJob(
    ApplicationDbContext context,
    INotificationService notificationService,
    ILogger<InventoryAvailabilityNotificationJob> logger)
{
    // Maximum 3 retries, exponential backoff
    [AutomaticRetry(Attempts = 3, DelaysInSeconds = [10, 60, 300])]
    public async Task NotifyAvailabilityAsync(Guid inventoryItemId, CancellationToken cancellationToken)
    {
        var item = await context.InventoryItems
            .Include(i => i.Pharmacy)
            .FirstOrDefaultAsync(i => i.Id == inventoryItemId, cancellationToken);

        if (item is null || item.Status != InventoryStatus.InStock)
        {
            logger.LogInformation("Job skipped: Item {ItemId} not found or not InStock.", inventoryItemId);
            return;
        }

        var normalizedName = item.MedicationName.Trim().ToLowerInvariant();
        var tenMinsAgo = DateTime.UtcNow.AddMinutes(-10);

        // Find matching active subscriptions where pharmacy is within radius
        // SQL Server geography distance is in meters, so RadiusKm * 1000
        var subscriptions = await context.Subscriptions
            .Where(s => s.IsActive && 
                        s.MedicationNameNormalized == normalizedName &&
                        (s.LastNotifiedAt == null || s.LastNotifiedAt < tenMinsAgo) &&
                        s.GeoPoint.Distance(item.Pharmacy.GeoPoint) <= (double)s.RadiusKm * 1000)
            .ToListAsync(cancellationToken);

        if (subscriptions.Count == 0)
        {
            logger.LogInformation("No matching subscribers found for Item {ItemId}.", inventoryItemId);
            return;
        }

        var userIds = subscriptions.Select(s => s.UserId).ToList();

        var users = await context.Users
            .Where(u => userIds.Contains(u.Id) && u.FcmToken != null)
            .Select(u => new { u.Id, u.FcmToken })
            .ToListAsync(cancellationToken);

        var tokenMap = users.ToDictionary(u => u.Id, u => u.FcmToken!);

        int sentCount = 0;
        foreach (var sub in subscriptions)
        {
            if (tokenMap.TryGetValue(sub.UserId, out var fcmToken))
            {
                var title = "Medication Available!";
                var body = $"{item.MedicationName} is now in stock at {item.Pharmacy.Name}.";
                
                // We fire and forget or await without failing the batch if one fails.
                // The INotificationService implementation usually handles its own retries or we just catch here.
                try
                {
                    await notificationService.SendAsync(fcmToken, title, body, null, cancellationToken);
                    sentCount++;
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "Failed to send FCM to user {UserId} for subscription {SubId}", sub.UserId, sub.Id);
                }
            }

            sub.LastNotifiedAt = DateTime.UtcNow;
        }

        await context.SaveChangesAsync(cancellationToken);

        logger.LogInformation("Job completed: Sent {SentCount} notifications for Item {ItemId}.", sentCount, inventoryItemId);
    }
}
