using Hangfire;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Infrastructure.BackgroundJobs;

namespace Nawakes.Infrastructure.BackgroundJobs;

/// <summary>
/// Hangfire implementation of IReservationJobScheduler.
/// Application layer calls the interface; this class owns the Hangfire dependency.
/// </summary>
public sealed class HangfireReservationJobScheduler : IReservationJobScheduler
{
    public string ScheduleExpiryJob(Guid reservationId, DateTimeOffset expiresAt)
    {
        var delay = expiresAt - DateTimeOffset.UtcNow;
        if (delay < TimeSpan.Zero) delay = TimeSpan.Zero;

        return BackgroundJob.Schedule<ReservationExpiryJob>(
            job => job.ExecuteAsync(reservationId, CancellationToken.None),
            delay);
    }

    public void DeleteJob(string hangfireJobId)
    {
        BackgroundJob.Delete(hangfireJobId);
    }
}
