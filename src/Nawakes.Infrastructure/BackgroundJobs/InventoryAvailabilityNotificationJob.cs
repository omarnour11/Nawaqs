using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.BackgroundJobs;

/// <summary>
/// Fair availability queue (Phase 3): when an item becomes InStock, offers it
/// to the first N waiting subscribers in FIFO order with a 15-minute claim
/// window. Unclaimed offers auto-pass to the next person in line via
/// OfferWindowExpiryJob. Durable in-app notification on day one, FCM push
/// ready to activate when Firebase keys are configured.
/// </summary>
public sealed class InventoryAvailabilityNotificationJob(
    IServiceProvider serviceProvider,
    ILogger<InventoryAvailabilityNotificationJob> logger)
{
    private const int OfferWindowMinutes = 15;

    // Maximum 3 retries, exponential backoff
    [AutomaticRetry(Attempts = 3, DelaysInSeconds = [10, 60, 300])]
    public async Task NotifyAvailabilityAsync(Guid inventoryItemId, CancellationToken cancellationToken)
    {
        await AllocateQueueSlotsAsync(inventoryItemId, cancellationToken);
    }

    /// <summary>
    /// Offers stock to waiting subscribers, up to the available quantity.
    /// Each offer gets a 15-minute window and a scheduled expiry job.
    /// </summary>
    public async Task AllocateQueueSlotsAsync(Guid inventoryItemId, CancellationToken cancellationToken)
    {
        using var scope = serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();
        var offerScheduler = scope.ServiceProvider.GetRequiredService<IOfferWindowScheduler>();

        var item = await context.InventoryItems
            .Include(i => i.Pharmacy)
            .FirstOrDefaultAsync(i => i.Id == inventoryItemId, cancellationToken);

        if (item is null || item.Status != InventoryStatus.InStock)
        {
            logger.LogInformation("Queue allocation skipped: Item {ItemId} not found or not InStock.", inventoryItemId);
            return;
        }

        var tenMinsAgo = DateTime.UtcNow.AddMinutes(-10);

        var waiting = await context.Subscriptions
            .Where(s => s.IsActive &&
                        s.QueueStatus == QueueStatus.Waiting &&
                        s.MedicationNameNormalized == item.MedicationNameNormalized.ToLower() &&
                        (s.LastNotifiedAt == null || s.LastNotifiedAt < tenMinsAgo) &&
                        s.GeoPoint.Distance(item.Pharmacy.GeoPoint) <= (double)s.RadiusKm * 1000)
            .OrderBy(s => s.QueuePosition)
            .ThenBy(s => s.CreatedAt)
            .ToListAsync(cancellationToken);

        if (waiting.Count == 0)
        {
            logger.LogInformation("No waiting subscribers for Item {ItemId}.", inventoryItemId);
            return;
        }

        var offerCount = Math.Min(item.Quantity, waiting.Count);
        var offeredUserIds = new List<Guid>();

        for (var i = 0; i < offerCount; i++)
        {
            var sub = waiting[i];
            var expiresAt = DateTime.UtcNow.AddMinutes(OfferWindowMinutes);

            sub.QueueStatus = QueueStatus.Offered;
            sub.OfferedAt = DateTime.UtcNow;
            sub.OfferExpiresAt = expiresAt;
            sub.OfferedInventoryItemId = item.Id;
            sub.LastNotifiedAt = DateTime.UtcNow;

            var jobId = offerScheduler.ScheduleOfferExpiry(sub.Id, new DateTimeOffset(expiresAt, TimeSpan.Zero));
            sub.OfferExpiryHangfireJobId = jobId;

            context.Notifications.Add(new Nawakes.Domain.Entities.UserNotification
            {
                UserId = sub.UserId,
                Type = NotificationType.AvailabilityOfferSent,
                Title = "الدواء اتاح تاني!",
                Body = $"{item.MedicationName} متاح في {item.Pharmacy.Name} — عندك 15 دقيقة لتأكيد الحجز.",
                RelatedEntityId = sub.Id
            });

            offeredUserIds.Add(sub.UserId);
        }

        await context.SaveChangesAsync(cancellationToken);

        // FCM push (free tier, activates when Firebase keys are configured)
        var users = await context.Users
            .Where(u => offeredUserIds.Contains(u.Id) && u.FcmToken != null)
            .Select(u => new { u.Id, u.FcmToken })
            .ToListAsync(cancellationToken);

        foreach (var u in users)
        {
            try
            {
                await notificationService.SendAsync(
                    u.FcmToken!,
                    "الدواء اتاح تاني!",
                    $"{item.MedicationName} متاح في {item.Pharmacy.Name} — عندك 15 دقيقة لتأكيد الحجز.",
                    cancellationToken: CancellationToken.None);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "FCM push failed for user {UserId}", u.Id);
            }
        }

        logger.LogInformation("Queue allocation done for Item {ItemId}: {Count} offers sent.",
            inventoryItemId, offerCount);
    }
}
