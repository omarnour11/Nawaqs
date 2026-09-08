using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reservations.Dtos;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.CompleteReservation;

/// <summary>
/// Marks a reservation as Completed (sold) by the pharmacy owner.
///
/// Rules:
/// - Only the pharmacy owner of the associated pharmacy can complete (403 otherwise)
/// - Reservation must be Active (409 if already completed/expired)
/// - Idempotent: if already Completed, returns 409 with clear message (Hangfire job checks this too)
/// - On success: sets InventoryItem.Status = OutOfStock, deletes Hangfire expiry job
/// </summary>
public sealed class CompleteReservationCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    IReservationJobScheduler jobScheduler)
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

        // Verify caller owns the pharmacy
        if (reservation.Pharmacy.OwnerId != currentUser.UserId)
            throw new ForbiddenException("This reservation does not belong to your pharmacy.");

        // State guard
        if (reservation.Status != ReservationStatus.Active)
            throw new ConflictException($"Reservation is already {reservation.Status}.");

        // Transition
        reservation.Status = ReservationStatus.Completed;
        reservation.CompletedAt = DateTime.UtcNow;
        reservation.InventoryItem.Status = InventoryStatus.OutOfStock;

        await context.SaveChangesAsync(cancellationToken);

        // Delete scheduled expiry job — no longer needed
        if (!string.IsNullOrWhiteSpace(reservation.HangfireJobId))
            jobScheduler.DeleteJob(reservation.HangfireJobId);

        // Anonymize patient display name: "Patient #XXXX" (last 4 chars of UserId)
        var displayName = $"Patient #{reservation.UserId.ToString()[^4..].ToUpperInvariant()}";

        return new PharmacyReservationDto(
            reservation.Id,
            displayName,
            reservation.InventoryItem.MedicationName,
            nameof(ReservationStatus.Completed),
            reservation.ExpiresAt,
            reservation.CreatedAt);
    }
}
