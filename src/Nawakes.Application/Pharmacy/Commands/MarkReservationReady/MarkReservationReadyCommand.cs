using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reservations.Dtos;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.MarkReservationReady;

/// <summary>
/// Pharmacist marks a held reservation as "ready for pickup" — step 2 of the pass tracker.
/// </summary>
public sealed record MarkReservationReadyCommand(Guid ReservationId) : IRequest<PharmacyReservationDto>;

public sealed class MarkReservationReadyCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<MarkReservationReadyCommand, PharmacyReservationDto>
{
    public async Task<PharmacyReservationDto> Handle(
        MarkReservationReadyCommand request, CancellationToken cancellationToken)
    {
        var reservation = await context.Reservations
            .Include(r => r.InventoryItem)
            .Include(r => r.Pharmacy)
            .FirstOrDefaultAsync(r => r.Id == request.ReservationId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.Reservation), request.ReservationId);

        if (reservation.Pharmacy.OwnerId != currentUser.UserId)
            throw new ForbiddenException("هذا الحجز لا يتبع صيدليتك.");

        if (reservation.Status != ReservationStatus.Active)
            throw new ConflictException($"الحجز حالته {reservation.Status} بالفعل.");

        reservation.Status = ReservationStatus.Ready;

        context.Notifications.Add(new Domain.Entities.UserNotification
        {
            UserId = reservation.UserId,
            Type = NotificationType.ReservationCreated,
            Title = "جاهز للاستلام",
            Body = $"طلبك من {reservation.Pharmacy.Name} جاهز. اعرض التصريح والروشتة عند الكاشير.",
            RelatedEntityId = reservation.Id
        });

        await context.SaveChangesAsync(cancellationToken);

        var displayName = $"مريض #{reservation.UserId.ToString()[^4..].ToUpperInvariant()}";
        return new PharmacyReservationDto(
            reservation.Id,
            displayName,
            reservation.InventoryItem.MedicationName,
            nameof(ReservationStatus.Ready),
            reservation.ExpiresAt,
            reservation.CreatedAt,
            reservation.ReservationCode);
    }
}
