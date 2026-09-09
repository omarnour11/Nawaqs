using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reservations.Dtos;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using System.Security.Cryptography;

namespace Nawakes.Application.Reservations.Commands.CreateReservation;

/// <summary>
/// Creates a 2-hour reservation hold on an inventory item.
///
/// Race-condition guard — Optimistic Concurrency via EF Core RowVersion:
///   EF generates: UPDATE InventoryItems SET Status=Reserved
///                 WHERE Id=@id AND RowVersion=@original
///   If 0 rows affected (another request won the race) → DbUpdateConcurrencyException → 409.
/// </summary>
public sealed class CreateReservationCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    IReservationJobScheduler jobScheduler,
    ILogger<CreateReservationCommandHandler> logger)
    : IRequestHandler<CreateReservationCommand, ReservationDto>
{
    private const int HoldDurationHours = 2;

    public async Task<ReservationDto> Handle(
        CreateReservationCommand request,
        CancellationToken cancellationToken)
    {
        // 1. Load InventoryItem WITH TRACKING — essential for RowVersion concurrency check
        var item = await context.InventoryItems
            .Include(i => i.Pharmacy)
            .FirstOrDefaultAsync(i => i.Id == request.InventoryItemId, cancellationToken);

        if (item is null)
            throw new NotFoundException(nameof(InventoryItem), request.InventoryItemId);

        // 2. Business rule: must be InStock to reserve
        if (item.Status != InventoryStatus.InStock)
            throw new ConflictException(
                item.Status == InventoryStatus.Reserved
                    ? "This item was just reserved. Please try again shortly."
                    : "This item is currently out of stock.");

        // 3. Mutate status — EF tracks the original RowVersion automatically
        item.Status = InventoryStatus.Reserved;

        // 4. Create the reservation record with a unique pickup code
        var expiresAt = DateTime.UtcNow.AddHours(HoldDurationHours);
        var reservation = new Reservation
        {
            UserId          = currentUser.UserId,
            InventoryItemId = item.Id,
            PharmacyId      = item.PharmacyId,
            Status          = ReservationStatus.Active,
            ExpiresAt       = expiresAt,
            ReservationCode = GenerateCode()
        };
        context.Reservations.Add(reservation);

        // 5. Persist — optimistic concurrency fires here if two requests race
        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException ex)
        {
            logger.LogWarning(ex,
                "Reservation race condition detected for InventoryItemId={ItemId}. Returning 409.",
                request.InventoryItemId);

            throw new ConflictException("This item was just reserved. Please try again shortly.");
        }

        // 6. In-app notification (durable history; FCM push is handled by pharmacy flows)
        context.Notifications.Add(new UserNotification
        {
            UserId = currentUser.UserId,
            Type = NotificationType.ReservationCreated,
            Title = "Reservation Confirmed",
            Body = $"Your hold on {item.MedicationName} at {item.Pharmacy.Name} is active for 2 hours.",
            RelatedEntityId = reservation.Id
        });

        // 7. Schedule Hangfire expiry job (after successful commit)
        var jobId = jobScheduler.ScheduleExpiryJob(reservation.Id, new DateTimeOffset(expiresAt, TimeSpan.Zero));

        // 8. Store job ID for later deletion on cancel/complete
        reservation.HangfireJobId = jobId;
        await context.SaveChangesAsync(cancellationToken);

        logger.LogInformation(
            "Reservation {ReservationId} created for Item {ItemId}, expires at {ExpiresAt}, HangfireJob={JobId}",
            reservation.Id, item.Id, expiresAt, jobId);

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

    /// <summary>6 hex chars from a crypto-random source — 16.7M combinations, collision risk negligible at this scale.</summary>
    private static string GenerateCode()
    {
        Span<byte> bytes = stackalloc byte[3];
        RandomNumberGenerator.Fill(bytes);
        return $"NWQ-{bytes[0]:X2}{bytes[1]:X2}{bytes[2]:X2}";
    }
}
