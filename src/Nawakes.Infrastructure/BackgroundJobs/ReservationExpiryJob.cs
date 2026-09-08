using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.BackgroundJobs;

/// <summary>
/// Hangfire job that auto-expires a reservation after 2 hours.
/// Idempotency: checks Status == Active before proceeding.
/// Both entity writes are wrapped in a single DB transaction.
/// </summary>
public sealed class ReservationExpiryJob(
    ApplicationDbContext context,
    INotificationService notifications,
    ILogger<ReservationExpiryJob> logger)
{
    [DisableConcurrentExecution(timeoutInSeconds: 30)]
    [AutomaticRetry(Attempts = 3, DelaysInSeconds = [10, 60, 300])]
    public async Task ExecuteAsync(Guid reservationId, CancellationToken cancellationToken = default)
    {
        logger.LogInformation("ReservationExpiryJob starting for ReservationId={ReservationId}", reservationId);

        var reservation = await context.Reservations
            .Include(r => r.InventoryItem)
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(r => r.Id == reservationId, cancellationToken);

        if (reservation is null)
        {
            logger.LogWarning("ReservationExpiryJob: Reservation {ReservationId} not found. Skipping.", reservationId);
            return;
        }

        // Idempotency guard
        if (reservation.Status != ReservationStatus.Active)
        {
            logger.LogInformation(
                "ReservationExpiryJob: Reservation {ReservationId} already in status {Status}. Skipping.",
                reservationId, reservation.Status);
            return;
        }

        // Load the user's FCM token separately (ApplicationUser is in Identity tables)
        var fcmToken = await context.Users
            .Where(u => u.Id == reservation.UserId)
            .Select(u => u.FcmToken)
            .FirstOrDefaultAsync(cancellationToken);

        await using var transaction = await context.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            reservation.Status = ReservationStatus.Expired;
            reservation.InventoryItem.Status = InventoryStatus.InStock;

            await context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            logger.LogInformation("ReservationExpiryJob: Reservation {ReservationId} expired successfully.", reservationId);
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync(cancellationToken);
            logger.LogError(ex, "ReservationExpiryJob: Transaction failed for Reservation {ReservationId}.", reservationId);
            throw;
        }

        // FCM notification — best effort
        if (!string.IsNullOrWhiteSpace(fcmToken))
        {
            await notifications.SendAsync(
                fcmToken: fcmToken,
                title: "Reservation Expired",
                body: $"Your hold on {reservation.InventoryItem.MedicationName} has expired.",
                data: new Dictionary<string, string>
                {
                    ["reservationId"] = reservationId.ToString(),
                    ["type"] = "reservation_expired"
                },
                cancellationToken: cancellationToken);
        }
    }
}
