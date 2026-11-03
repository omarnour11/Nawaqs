using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reservations.Dtos;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.CompleteReservation;

/// <summary>
/// Marks a reservation as Completed (sold) by the pharmacy owner.
///
/// Rules:
/// - Only the pharmacy owner of the associated pharmacy can complete (403 otherwise)
/// - Reservation must be Active and not expired (409 if already completed or expired)
/// - On success: sets InventoryItem.Status = OutOfStock, deletes Hangfire expiry job
/// </summary>
public sealed class CompleteReservationCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    IReservationJobScheduler jobScheduler,
    IRealtimeReservationNotifier? realtimeNotifier = null)
    : IRequestHandler<CompleteReservationCommand, PharmacyReservationDto>
{
    public async Task<PharmacyReservationDto> Handle(
        CompleteReservationCommand request,
        CancellationToken cancellationToken)
    {
        var reservation = await context.Reservations
            .Include(r => r.InventoryItem)
            .Include(r => r.Pharmacy)
            .FirstOrDefaultAsync(r => r.Id == request.ReservationId, cancellationToken);

        if (reservation is null)
            throw new NotFoundException(nameof(Domain.Entities.Reservation), request.ReservationId);

        if (reservation.Pharmacy.OwnerId != currentUser.UserId)
            throw new ForbiddenException("This reservation does not belong to your pharmacy.");

        if (reservation.Status != ReservationStatus.Active &&
            reservation.Status != ReservationStatus.Ready)
        {
            throw new ConflictException($"Reservation is already {reservation.Status} and cannot be completed.");
        }

        if (reservation.ExpiresAt > DateTime.MinValue && reservation.ExpiresAt <= DateTime.UtcNow)
        {
            reservation.Status = ReservationStatus.Expired;
            reservation.InventoryItem.Status = InventoryStatus.InStock;
            await context.SaveChangesAsync(cancellationToken);
            throw new ConflictException("انتهت صلاحية الحجز تلقائياً ولا يمكن استلامه.");
        }

        reservation.Status = ReservationStatus.Completed;
        reservation.CompletedAt = DateTime.UtcNow;

        // Deduct 1 unit from stock. If units still remain, keep item InStock!
        reservation.InventoryItem.Quantity = Math.Max(0, reservation.InventoryItem.Quantity - 1);
        if (reservation.InventoryItem.Quantity == 0)
        {
            reservation.InventoryItem.Status = InventoryStatus.OutOfStock;
        }
        else
        {
            reservation.InventoryItem.Status = InventoryStatus.InStock;
        }

        context.Notifications.Add(new UserNotification
        {
            UserId = reservation.UserId,
            Type = NotificationType.ReservationCompleted,
            Title = "تم استلام الدواء بنجاح ✓",
            Body = $"تم تأكيد استلام دواء {reservation.InventoryItem.MedicationName} بنجاح من صيدلية {reservation.Pharmacy.Name}. نتمنى لك دوام الصحة والعافية!",
            RelatedEntityId = reservation.Id
        });

        await context.SaveChangesAsync(cancellationToken);

        if (!string.IsNullOrWhiteSpace(reservation.HangfireJobId))
            jobScheduler.DeleteJob(reservation.HangfireJobId);

        if (realtimeNotifier is not null)
        {
            await realtimeNotifier.NotifyReservationUpdatedAsync(
                new ReservationStatusUpdatedEvent(
                    reservation.Id,
                    reservation.UserId,
                    reservation.PharmacyId,
                    reservation.Pharmacy.Name ?? string.Empty,
                    reservation.InventoryItem.MedicationName,
                    nameof(ReservationStatus.Completed),
                    reservation.DeliveryStatus?.ToString(),
                    reservation.ReservationCode,
                    reservation.ExpiresAt),
                cancellationToken);
        }

        var displayName = $"مريض #{reservation.UserId.ToString()[^4..].ToUpperInvariant()}";

        return new PharmacyReservationDto(
            reservation.Id,
            displayName,
            reservation.InventoryItem.MedicationName,
            nameof(ReservationStatus.Completed),
            reservation.ExpiresAt,
            reservation.CreatedAt,
            reservation.ReservationCode);
    }
}

