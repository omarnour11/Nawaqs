using Hangfire;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Infrastructure.BackgroundJobs;

public sealed class HangfireTrustScoreJobScheduler(IBackgroundJobClient backgroundJobClient) : ITrustScoreJobScheduler
{
    public void ScheduleTrustScoreRecalculation(Guid pharmacyId)
    {
        // Debounce: we just schedule it to run in 5 minutes.
        // If there are multiple jobs within 5 mins, they will all eventually run.
        // Since it's idempotent, it's safe. 
        // For strict debouncing, we could use Hangfire AddOrUpdate for a named job.
        backgroundJobClient.Schedule<TrustScoreRecalculationJob>(
            job => job.RecalculateAsync(pharmacyId, CancellationToken.None), 
            TimeSpan.FromMinutes(5));
    }
}
