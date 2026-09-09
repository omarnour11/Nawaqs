using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.CancelReservationByPharmacy;

/// <summary>
/// Pharmacist-side cancellation: frees the held item, notifies the patient.
/// Allowed for Active and Ready reservations (e.g. patient never showed up).
/// </summary>
public sealed record CancelReservationByPharmacyCommand(
    Guid ReservationId,
    string? Reason) : IRequest;

public sealed class CancelReservationByPharmacyCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    IReservationJobScheduler jobScheduler)
    : IRequestHandler<CancelReservationByPharmacyCommand>
{
    public async Task Handle(CancelReservationByPharmacyCommand request, CancellationToken cancellationToken)
    {
        var reservation = await context.Reservations
            .Include(r => r.InventoryItem)
            .Include(r => r.Pharmacy)
            .FirstOrDefaultAsync(r => r.Id == request.ReservationId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.Reservation), request.ReservationId);

        if (reservation.Pharmacy.OwnerId != currentUser.UserId)
            throw new ForbiddenException("هذا الحجز لا يتبع صيدليتك.");

        if (reservation.Status != ReservationStatus.Active &&
            reservation.Status != ReservationStatus.Ready)
            throw new ConflictException($"الحجز حالته {reservation.Status} ومش قابل للإلغاء.");

        reservation.Status = ReservationStatus.Cancelled;
        reservation.CancelledAt = DateTime.UtcNow;

        // Freed stock returns to shelves
        if (reservation.InventoryItem.Status == InventoryStatus.Reserved)
            reservation.InventoryItem.Status = InventoryStatus.InStock;

        context.Notifications.Add(new Domain.Entities.UserNotification
        {
            UserId = reservation.UserId,
            Type = NotificationType.ReservationCancelled,
            Title = "تم إلغاء حجزك",
            Body = string.IsNullOrWhiteSpace(request.Reason)
                ? $"صيدلية {reservation.Pharmacy.Name} ألغت حجزك على {reservation.InventoryItem.MedicationName}."
                : $"صيدلية {reservation.Pharmacy.Name} ألغت حجزك. السبب: {request.Reason}",
            RelatedEntityId = reservation.Id
        });

        await context.SaveChangesAsync(cancellationToken);

        if (!string.IsNullOrWhiteSpace(reservation.HangfireJobId))
            jobScheduler.DeleteJob(reservation.HangfireJobId);
    }
}
