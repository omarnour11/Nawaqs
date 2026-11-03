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
/// to waiting subscribers in FIFO order with a 15-minute claim window.
/// </summary>
public sealed class InventoryAvailabilityNotificationJob(
    IServiceProvider serviceProvider,
    ILogger<InventoryAvailabilityNotificationJob> logger)
{
    private const int OfferWindowMinutes = 15;

    [AutomaticRetry(Attempts = 3, DelaysInSeconds = [10, 60, 300])]
    public async Task NotifyAvailabilityAsync(Guid inventoryItemId, CancellationToken cancellationToken)
    {
        await AllocateQueueSlotsAsync(inventoryItemId, cancellationToken);
    }

    [DisableConcurrentExecution(timeoutInSeconds: 60)]
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

        var oneMinAgo = DateTime.UtcNow.AddMinutes(-1);
        var itemMedLower = item.MedicationName.Trim().ToLowerInvariant();
        var itemNormLower = item.MedicationNameNormalized.Trim().ToLowerInvariant();
        var itemNormUpper = item.MedicationNameNormalized.Trim().ToUpperInvariant();
        var brandToken = itemNormUpper.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? itemNormUpper;
        var brandTokenLower = itemNormLower.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? itemNormLower;

        // Pre-filter active waiting subscribers in SQL before fine-grained in-memory matching
        var candidateSubs = await context.Subscriptions
            .Where(s => s.IsActive &&
                        s.QueueStatus == QueueStatus.Waiting &&
                        (s.LastNotifiedAt == null || s.LastNotifiedAt < oneMinAgo) &&
                        ((s.MedicationNameNormalized != null &&
                          (s.MedicationNameNormalized == itemNormUpper ||
                           s.MedicationNameNormalized == itemNormLower ||
                           s.MedicationNameNormalized.Contains(brandToken) ||
                           s.MedicationNameNormalized.Contains(brandTokenLower) ||
                           itemNormUpper.Contains(s.MedicationNameNormalized) ||
                           itemNormLower.Contains(s.MedicationNameNormalized))) ||
                         (s.MedicationName != null &&
                          (s.MedicationName.Contains(item.MedicationName) ||
                           item.MedicationName.Contains(s.MedicationName)))))
            .OrderBy(s => s.QueuePosition)
            .ThenBy(s => s.CreatedAt)
            .ToListAsync(cancellationToken);

        var waiting = candidateSubs.Where(s =>
        {
            var sNorm = (s.MedicationNameNormalized ?? string.Empty).Trim().ToLowerInvariant();
            var sName = (s.MedicationName ?? string.Empty).Trim().ToLowerInvariant();

            if (string.IsNullOrWhiteSpace(sNorm) && string.IsNullOrWhiteSpace(sName)) return false;

            var matches = (sNorm.Length > 0 && itemNormLower.Length > 0 && sNorm == itemNormLower) ||
                          (sNorm.Length > 0 && itemNormLower.Contains(sNorm)) ||
                          (itemNormLower.Length > 0 && sNorm.Contains(itemNormLower)) ||
                          (sName.Length > 0 && itemMedLower.Contains(sName)) ||
                          (itemMedLower.Length > 0 && sName.Contains(itemMedLower));

            if (!matches) return false;

            // Geospatial check
            if (item.Pharmacy?.GeoPoint != null && s.GeoPoint != null)
            {
                var distKm = HaversineDistanceKm(s.GeoPoint, item.Pharmacy.GeoPoint);
                if (s.RadiusKm > 0 && distKm > (double)s.RadiusKm)
                {
                    return false;
                }
            }

            return true;
        }).ToList();

        if (waiting.Count == 0)
        {
            logger.LogInformation("No waiting subscribers for Item {ItemId} ({Name}).", inventoryItemId, item.MedicationName);
            return;
        }

        var offerCount = Math.Min(Math.Max(item.Quantity, 1), waiting.Count);
        var offeredUserIds = new List<Guid>();
        var offeredSubscriptions = new List<(Domain.Entities.Subscription Sub, DateTime ExpiresAt)>();

        for (var i = 0; i < offerCount; i++)
        {
            var sub = waiting[i];
            var expiresAt = DateTime.UtcNow.AddMinutes(OfferWindowMinutes);

            sub.QueueStatus = QueueStatus.Offered;
            sub.OfferedAt = DateTime.UtcNow;
            sub.OfferExpiresAt = expiresAt;
            sub.OfferedInventoryItemId = item.Id;
            sub.LastNotifiedAt = DateTime.UtcNow;

            offeredSubscriptions.Add((sub, expiresAt));

            context.Notifications.Add(new Domain.Entities.UserNotification
            {
                UserId = sub.UserId,
                Type = NotificationType.AvailabilityOfferSent,
                Title = "الدواء الذي تتابعه أصبح متوفراً!",
                Body = $"دواء {item.MedicationName} متوفر الآن في {item.Pharmacy?.Name ?? "الصيدلية"} — لديك 15 دقيقة لتأكيد الحجز.",
                RelatedEntityId = sub.Id
            });

            offeredUserIds.Add(sub.UserId);
        }

        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException ex)
        {
            logger.LogWarning(ex,
                "Concurrent queue allocation detected for Item {ItemId}; this run backed out.",
                inventoryItemId);
            return;
        }

        var realtimeNotifier = scope.ServiceProvider.GetService<IRealtimeReservationNotifier>();
        foreach (var (sub, expiresAt) in offeredSubscriptions)
        {
            try
            {
                var jobId = offerScheduler.ScheduleOfferExpiry(
                    sub.Id, new DateTimeOffset(expiresAt, TimeSpan.Zero));
                sub.OfferExpiryHangfireJobId = jobId;
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex,
                    "Failed to schedule expiry job for offer {SubId}.", sub.Id);
            }

            if (realtimeNotifier is not null)
            {
                await realtimeNotifier.NotifyQueueOfferSentAsync(
                    new QueueOfferDispatchedEvent(
                        sub.Id,
                        sub.UserId,
                        item.Id,
                        item.PharmacyId,
                        item.Pharmacy?.Name ?? "الصيدلية",
                        item.MedicationName,
                        item.Price,
                        expiresAt),
                    cancellationToken);
            }
        }

        await context.SaveChangesAsync(cancellationToken);

        // FCM push (if configured)
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
                    "الدواء الذي تتابعه أصبح متوفراً!",
                    $"دواء {item.MedicationName} متوفر الآن في {item.Pharmacy?.Name ?? "الصيدلية"} — لديك 15 دقيقة لتأكيد الحجز.",
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


    private static double HaversineDistanceKm(NetTopologySuite.Geometries.Point p1, NetTopologySuite.Geometries.Point p2)
    {
        const double R = 6371.0;
        var lat1 = p1.Y * Math.PI / 180.0;
        var lat2 = p2.Y * Math.PI / 180.0;
        var dLat = (p2.Y - p1.Y) * Math.PI / 180.0;
        var dLon = (p2.X - p1.X) * Math.PI / 180.0;

        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(lat1) * Math.Cos(lat2) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return R * c;
    }
}
