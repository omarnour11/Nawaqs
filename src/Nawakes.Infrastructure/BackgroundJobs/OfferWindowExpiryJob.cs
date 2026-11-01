using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.BackgroundJobs;

/// <summary>
/// Fires at Subscription.OfferExpiresAt. If the offer is still in Offered status,
/// marks it Skipped and immediately triggers AllocateQueueSlotsAsync on the
/// freed item so the next person in line gets the opportunity without waiting
/// for a polling sweep.
/// </summary>
public sealed class OfferWindowExpiryJob(
    IServiceProvider serviceProvider,
    ILogger<OfferWindowExpiryJob> logger)
{
    [AutomaticRetry(Attempts = 3, DelaysInSeconds = [10, 60, 300])]
    [DisableConcurrentExecution(timeoutInSeconds: 60)]
    public async Task ExpireOfferAsync(Guid subscriptionId, CancellationToken cancellationToken)
    {
        using var scope = serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        var subscription = await context.Subscriptions
            .FirstOrDefaultAsync(s => s.Id == subscriptionId, cancellationToken);

        if (subscription is null || subscription.QueueStatus != QueueStatus.Offered)
        {
            logger.LogInformation("Offer expiry skipped: subscription {SubId} missing or not Offered.", subscriptionId);
            return;
        }

        if (subscription.OfferExpiresAt is null ||
            subscription.OfferExpiresAt > DateTime.UtcNow)
        {
            logger.LogInformation(
                "Offer expiry skipped: subscription {SubId} window still open until {ExpiresAt}.",
                subscriptionId, subscription.OfferExpiresAt);
            return;
        }

        subscription.QueueStatus = QueueStatus.Skipped;

        var offeredItemId = subscription.OfferedInventoryItemId;

        context.Notifications.Add(new Nawakes.Domain.Entities.UserNotification
        {
            UserId = subscription.UserId,
            Type = Nawakes.Domain.Enums.NotificationType.OfferExpired,
            Title = "انتهت مهلة العرض",
            Body = "انتهت مهلة الـ 15 دقيقة لتأكيد الحجز وتم تمرير العرض للمشترك التالي في قائمة الانتظار.",
            RelatedEntityId = subscription.Id
        });

        await context.SaveChangesAsync(cancellationToken);

        logger.LogInformation("Offer {SubId} expired; re-allocating item {ItemId}.", subscriptionId, offeredItemId);

        if (offeredItemId.HasValue)
        {
            var allocator = scope.ServiceProvider.GetRequiredService<InventoryAvailabilityNotificationJob>();
            await allocator.AllocateQueueSlotsAsync(offeredItemId.Value, CancellationToken.None);
        }
    }
}
