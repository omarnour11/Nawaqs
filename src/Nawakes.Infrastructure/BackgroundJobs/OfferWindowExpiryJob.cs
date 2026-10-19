using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.BackgroundJobs;

/// <summary>
/// Expires a queue offer still in Offered status after the 15-minute window,
/// marks it Skipped, and re-triggers allocation so the next person in line
/// gets the offer.
/// </summary>
public sealed class OfferWindowExpiryJob(
    IServiceProvider serviceProvider,
    ILogger<OfferWindowExpiryJob> logger)
{
    [AutomaticRetry(Attempts = 3, DelaysInSeconds = [10, 60, 300])]
    public async Task ExpireOfferAsync(Guid subscriptionId, CancellationToken cancellationToken)
    {
        // Own scope — Hangfire jobs outlive the request scope
        using var scope = serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        var subscription = await context.Subscriptions
            .FirstOrDefaultAsync(s => s.Id == subscriptionId, cancellationToken);

        if (subscription is null || subscription.QueueStatus != QueueStatus.Offered)
        {
            logger.LogInformation("Offer expiry skipped: subscription {SubId} missing or not Offered.", subscriptionId);
            return;
        }

        // The job is scheduled for the deadline, but Hangfire can fire late or
        // a retry can arrive after the offer was already re-issued. Never expire
        // an offer whose window is still open.
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
            Title = "Offer Expired",
            Body = "The 15-minute claim window expired and the offer passed to the next person in line.",
            RelatedEntityId = subscription.Id
        });

        // One save so the status flip and the notification are atomic.
        await context.SaveChangesAsync(cancellationToken);

        logger.LogInformation("Offer {SubId} expired; re-allocating item {ItemId}.", subscriptionId, offeredItemId);

        if (offeredItemId.HasValue)
        {
            var allocator = scope.ServiceProvider.GetRequiredService<InventoryAvailabilityNotificationJob>();
            await allocator.AllocateQueueSlotsAsync(offeredItemId.Value, CancellationToken.None);
        }
    }
}
