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
/// Operations are wrapped in the configured execution strategy for retry resilience.
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

        var strategy = context.Database.CreateExecutionStrategy();
        await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await context.Database.BeginTransactionAsync(cancellationToken);
            try
            {
                reservation.Status = ReservationStatus.Expired;
                reservation.InventoryItem.Status = InventoryStatus.InStock;

                // Durable in-app record (FCM push below is best-effort)
                context.Notifications.Add(new Nawakes.Domain.Entities.UserNotification
                {
                    UserId = reservation.UserId,
                    Type = Nawakes.Domain.Enums.NotificationType.ReservationExpired,
                    Title = "انتهت صلاحية الحجز",
                    Body = $"انتهت مهلة استلام دواء {reservation.InventoryItem.MedicationName} وأصبح متاحاً للآخرين.",
                    RelatedEntityId = reservation.Id
                });

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
        });

        // FCM notification — best effort
        if (!string.IsNullOrWhiteSpace(fcmToken))
        {
            await notifications.SendAsync(
                fcmToken: fcmToken,
                title: "انتهت صلاحية الحجز",
                body: $"انتهت مهلة حجزك لدواء {reservation.InventoryItem.MedicationName}.",
                data: new Dictionary<string, string>
                {
                    ["reservationId"] = reservationId.ToString(),
                    ["type"] = "reservation_expired"
                },
                cancellationToken: cancellationToken);
        }
    }
}
