using Hangfire;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Infrastructure.BackgroundJobs;

public sealed class HangfireInventoryJobScheduler(IBackgroundJobClient backgroundJobClient)
    : IInventoryJobScheduler
{
    public void EnqueueAvailabilityNotification(Guid inventoryItemId)
    {
        // Enqueue the notification job. The actual job implementation will be built in Story 4.1.
        backgroundJobClient.Enqueue<InventoryAvailabilityNotificationJob>(
            job => job.NotifyAvailabilityAsync(inventoryItemId, CancellationToken.None));
    }
}
