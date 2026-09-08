namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// Abstracts Hangfire scheduling from the Application layer.
/// Application knows the contract; Infrastructure owns the Hangfire dependency.
/// </summary>
public interface IReservationJobScheduler
{
    /// <summary>Schedules the expiry job at <paramref name="expiresAt"/> and returns the Hangfire job ID.</summary>
    string ScheduleExpiryJob(Guid reservationId, DateTimeOffset expiresAt);

    /// <summary>Deletes a previously scheduled expiry job (called on cancel/complete).</summary>
    void DeleteJob(string hangfireJobId);
}
