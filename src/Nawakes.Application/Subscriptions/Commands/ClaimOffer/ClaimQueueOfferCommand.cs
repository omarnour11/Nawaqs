using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reservations.Dtos;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using System.Security.Cryptography;

namespace Nawakes.Application.Subscriptions.Commands.ClaimOffer;

/// <summary>
/// Claims a 15-minute queue offer and converts it into a 2-hour reservation
/// with a crypto pickup code (NWQ-XXXXXX). Optimistic concurrency on
/// InventoryItem.RowVersion guarantees two users can never claim the same box.
/// </summary>
public sealed record ClaimQueueOfferCommand(Guid SubscriptionId) : IRequest<ReservationDto>;

public sealed class ClaimQueueOfferCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    IReservationJobScheduler jobScheduler,
    IOfferWindowScheduler offerScheduler)
    : IRequestHandler<ClaimQueueOfferCommand, ReservationDto>
{
    private const int HoldDurationHours = 2;

    public async Task<ReservationDto> Handle(
        ClaimQueueOfferCommand request, CancellationToken cancellationToken)
    {
        var subscription = await context.Subscriptions
            .FirstOrDefaultAsync(s => s.Id == request.SubscriptionId, cancellationToken);

        if (subscription is null || subscription.UserId != currentUser.UserId)
            throw new NotFoundException(nameof(Subscription), request.SubscriptionId);

        if (subscription.QueueStatus != QueueStatus.Offered)
            throw new ConflictException("This offer is no longer active.");

        if (subscription.OfferExpiresAt is null || subscription.OfferExpiresAt <= DateTime.UtcNow)
            throw new ConflictException("The claim window for this offer has expired.");

        var itemId = subscription.OfferedInventoryItemId
            ?? throw new ConflictException("This offer has no inventory item attached.");

        var item = await context.InventoryItems
            .Include(i => i.Pharmacy)
            .FirstOrDefaultAsync(i => i.Id == itemId, cancellationToken);

        if (item is null)
            throw new NotFoundException(nameof(InventoryItem), itemId);

        if (item.Status != InventoryStatus.InStock)
            throw new ConflictException("This item was just reserved. Please try again shortly.");

        item.Status = InventoryStatus.Reserved;

        var expiresAt = DateTime.UtcNow.AddHours(HoldDurationHours);
        var reservation = new Reservation
        {
            UserId = currentUser.UserId,
            InventoryItemId = item.Id,
            PharmacyId = item.PharmacyId,
            Status = ReservationStatus.Active,
            ExpiresAt = expiresAt,
            ReservationCode = GenerateCode()
        };
        context.Reservations.Add(reservation);

        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new ConflictException("This item was just reserved. Please try again shortly.");
        }

        subscription.QueueStatus = QueueStatus.Claimed;
        if (subscription.OfferExpiryHangfireJobId is not null)
        {
            offerScheduler.DeleteOfferExpiry(subscription.OfferExpiryHangfireJobId);
        }

        context.Notifications.Add(new UserNotification
        {
            UserId = currentUser.UserId,
            Type = NotificationType.ReservationCreated,
            Title = "Reservation Confirmed",
            Body = $"Your hold on {item.MedicationName} at {item.Pharmacy.Name} is active for 2 hours.",
            RelatedEntityId = reservation.Id
        });

        await context.SaveChangesAsync(cancellationToken);

        var expiryJobId = jobScheduler.ScheduleExpiryJob(reservation.Id, new DateTimeOffset(expiresAt, TimeSpan.Zero));
        reservation.HangfireJobId = expiryJobId;
        await context.SaveChangesAsync(cancellationToken);

        return new ReservationDto(
            reservation.Id,
            item.Id,
            item.PharmacyId,
            item.Pharmacy.Name,
            item.Pharmacy.Phone,
            item.MedicationName,
            nameof(ReservationStatus.Active),
            expiresAt,
            reservation.CreatedAt,
            reservation.ReservationCode);
    }

    private static string GenerateCode()
    {
        Span<byte> bytes = stackalloc byte[3];
        RandomNumberGenerator.Fill(bytes);
        return $"NWQ-{bytes[0]:X2}{bytes[1]:X2}{bytes[2]:X2}";
    }
}
