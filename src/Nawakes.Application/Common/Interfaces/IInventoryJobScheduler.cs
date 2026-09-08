namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// Abstracts Hangfire scheduling for inventory-related background jobs.
/// </summary>
public interface IInventoryJobScheduler
{
    /// <summary>
    /// Enqueues a background job to notify subscribed users that an item is now InStock.
    /// </summary>
    void EnqueueAvailabilityNotification(Guid inventoryItemId);
}
