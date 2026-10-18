namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// Schedules the 15-minute priority claim window for queue offers (Phase 3).
/// </summary>
public interface IOfferWindowScheduler
{
    /// <summary>Schedules an offer expiry at <paramref name="expiresAt"/> and returns the Hangfire job ID.</summary>
    string ScheduleOfferExpiry(Guid subscriptionId, DateTimeOffset expiresAt);

    /// <summary>Deletes a previously scheduled offer expiry (called when the offer is claimed).</summary>
    void DeleteOfferExpiry(string hangfireJobId);
}
