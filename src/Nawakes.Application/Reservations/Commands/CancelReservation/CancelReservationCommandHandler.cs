using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Reservations.Commands.CancelReservation;

/// <summary>
/// Cancels a patient's own Active reservation.
///
/// Rules:
/// - Only the owning patient can cancel (403 otherwise)
/// - Cannot cancel within 15 minutes of creation (400 — lock-in window)
/// - Reservation must be Active (409 if already completed/expired)
/// - On success: reverts InventoryItem.Status to InStock, deletes Hangfire job
/// </summary>
public sealed class CancelReservationCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    IReservationJobScheduler jobScheduler)
    : IRequestHandler<CancelReservationCommand>
{
    private static readonly TimeSpan LockInWindow = TimeSpan.FromMinutes(15);

    public async Task Handle(CancelReservationCommand request, CancellationToken cancellationToken)
    {
        var reservation = await context.Reservations
            .Include(r => r.InventoryItem)
            .FirstOrDefaultAsync(r => r.Id == request.ReservationId, cancellationToken);

        if (reservation is null)
            throw new NotFoundException(nameof(Domain.Entities.Reservation), request.ReservationId);

        // Ownership check
        if (reservation.UserId != currentUser.UserId)
            throw new ForbiddenException("You do not own this reservation.");

        // State check
        if (reservation.Status != ReservationStatus.Active)
            throw new ConflictException(
                $"Reservation is already {reservation.Status} and cannot be cancelled.");

        // Lock-in window: cannot cancel within first 15 minutes
        var lockInExpiry = reservation.CreatedAt.Add(LockInWindow);
        if (DateTime.UtcNow < lockInExpiry)
        {
            var remainingSeconds = (int)(lockInExpiry - DateTime.UtcNow).TotalSeconds;
            throw new InvalidOperationException(
                $"Reservations cannot be cancelled within {LockInWindow.TotalMinutes} minutes of creation. " +
                $"Please try again in {remainingSeconds} seconds.");
        }

        // Transition both entities
        reservation.Status = ReservationStatus.Cancelled;
        reservation.CancelledAt = DateTime.UtcNow;
        reservation.InventoryItem.Status = InventoryStatus.InStock;

        await context.SaveChangesAsync(cancellationToken);

        // Remove the scheduled Hangfire expiry job
        if (!string.IsNullOrWhiteSpace(reservation.HangfireJobId))
            jobScheduler.DeleteJob(reservation.HangfireJobId);
    }
}
