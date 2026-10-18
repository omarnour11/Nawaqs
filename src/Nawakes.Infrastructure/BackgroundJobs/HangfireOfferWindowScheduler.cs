using Hangfire;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Infrastructure.BackgroundJobs;

namespace Nawakes.Infrastructure.BackgroundJobs;

/// <summary>
/// Hangfire implementation of IOfferWindowScheduler (Phase 3).
/// </summary>
public sealed class HangfireOfferWindowScheduler : IOfferWindowScheduler
{
    public string ScheduleOfferExpiry(Guid subscriptionId, DateTimeOffset expiresAt)
    {
        var delay = expiresAt - DateTimeOffset.UtcNow;
        if (delay < TimeSpan.Zero) delay = TimeSpan.Zero;

        return BackgroundJob.Schedule<OfferWindowExpiryJob>(
            job => job.ExpireOfferAsync(subscriptionId, CancellationToken.None),
            delay);
    }

    public void DeleteOfferExpiry(string hangfireJobId)
    {
        BackgroundJob.Delete(hangfireJobId);
    }
}
