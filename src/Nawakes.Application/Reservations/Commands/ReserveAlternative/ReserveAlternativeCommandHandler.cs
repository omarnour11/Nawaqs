using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reservations.Dtos;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using System.Security.Cryptography;

namespace Nawakes.Application.Reservations.Commands.ReserveAlternative;

public sealed class ReserveAlternativeCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    IReservationJobScheduler jobScheduler,
    ILogger<ReserveAlternativeCommandHandler> logger)
    : IRequestHandler<ReserveAlternativeCommand, ReservationDto>
{
    private const int HoldDurationHours = 2;

    public async Task<ReservationDto> Handle(
        ReserveAlternativeCommand request,
        CancellationToken cancellationToken)
    {
        // 1. Locate prior reservation
        var prior = await context.Reservations
            .Include(r => r.Pharmacy)
            .FirstOrDefaultAsync(r => r.Id == request.PriorReservationId, cancellationToken);

        if (prior is null)
            throw new NotFoundException(nameof(Reservation), request.PriorReservationId);

        // 2. Resolve alternative inventory item
        InventoryItem? item = null;

        if (prior.RecommendedAlternativeItemId.HasValue)
        {
            item = await context.InventoryItems
                .Include(i => i.Pharmacy)
                .FirstOrDefaultAsync(i => i.Id == prior.RecommendedAlternativeItemId.Value, cancellationToken);
        }

        if (item is null || item.Status != InventoryStatus.InStock)
        {
            var altName = prior.RecommendedAlternativeMedication?.Trim();
            if (string.IsNullOrWhiteSpace(altName))
            {
                throw new ConflictException("No alternative medication was recommended for this reservation.");
            }

            var altNormalized = altName.ToUpperInvariant();

            // Try same pharmacy first
            item = await context.InventoryItems
                .Include(i => i.Pharmacy)
                .FirstOrDefaultAsync(i => i.PharmacyId == prior.PharmacyId
                                          && i.Status == InventoryStatus.InStock
                                          && (i.MedicationName == altName || i.MedicationNameNormalized == altNormalized),
                    cancellationToken);

            // Fallback: search any approved pharmacy with this item in stock
            if (item is null)
            {
                item = await context.InventoryItems
                    .Include(i => i.Pharmacy)
                    .Where(i => i.Status == InventoryStatus.InStock
                                && i.Pharmacy.VerificationStatus == VerificationStatus.Approved
                                && (i.MedicationName.Contains(altName) || altName.Contains(i.MedicationName) || i.MedicationNameNormalized == altNormalized))
                    .OrderBy(i => i.PharmacyId == prior.PharmacyId ? 0 : 1)
                    .FirstOrDefaultAsync(cancellationToken);
            }
        }

        if (item is null)
            throw new NotFoundException(nameof(InventoryItem), prior.RecommendedAlternativeItemId ?? (object)(prior.RecommendedAlternativeMedication ?? request.PriorReservationId.ToString()));

        if (item.Status != InventoryStatus.InStock)
            throw new ConflictException(item.Status == InventoryStatus.Reserved
                ? "This alternative item was just reserved. Please try again shortly."
                : "This alternative item is currently out of stock.");

        if (item.Pharmacy is not null && item.Pharmacy.VerificationStatus != VerificationStatus.Approved)
        {
            throw new ConflictException("لا يمكن إتمام حجز جديد لأن الصيدلية معلقة أو قيد مراجعة الإدارة حالياً.");
        }

        // 3. Mutate status
        item.Status = InventoryStatus.Reserved;

        // 4. Create new reservation
        var expiresAt = DateTime.UtcNow.AddHours(HoldDurationHours);
        var reservation = new Reservation
        {
            UserId                = currentUser.UserId,
            InventoryItemId       = item.Id,
            PharmacyId            = item.PharmacyId,
            Status                = ReservationStatus.Active,
            ExpiresAt             = expiresAt,
            ReservationCode       = GenerateCode(),
            PrescriptionCropUrl   = prior.PrescriptionCropUrl,
            PrescriptionCropBytes = prior.PrescriptionCropBytes
        };
        context.Reservations.Add(reservation);

        // 5. Persist with optimistic concurrency
        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException ex)
        {
            logger.LogWarning(ex,
                "Reservation race condition detected for InventoryItemId={ItemId}. Returning 409.",
                item.Id);
            throw new ConflictException("This alternative item was just reserved. Please try again shortly.");
        }

        // 6. In-app notification
        var pharmacyName = item.Pharmacy?.Name ?? "الصيدلية";
        context.Notifications.Add(new UserNotification
        {
            UserId = currentUser.UserId,
            Type = NotificationType.ReservationCreated,
            Title = "تم تأكيد حجز البديل بنجاح ✓",
            Body = $"تم حجز البديل المقترح ({item.MedicationName}) بنجاح في صيدلية {pharmacyName} لمدة ساعتين. كود الحجز: #{reservation.ReservationCode}",
            RelatedEntityId = reservation.Id
        });

        // 7. Schedule Hangfire expiry job
        var jobId = jobScheduler.ScheduleExpiryJob(reservation.Id, new DateTimeOffset(expiresAt, TimeSpan.Zero));
        reservation.HangfireJobId = jobId;
        await context.SaveChangesAsync(cancellationToken);

        logger.LogInformation(
            "Alternative reservation {ReservationId} created for Item {ItemId} from PriorReservation {PriorId}, expires at {ExpiresAt}",
            reservation.Id, item.Id, prior.Id, expiresAt);

        return new ReservationDto(
            reservation.Id,
            item.Id,
            item.PharmacyId,
            item.Pharmacy?.Name ?? "",
            item.Pharmacy?.Phone ?? "",
            item.MedicationName,
            nameof(ReservationStatus.Active),
            expiresAt,
            reservation.CreatedAt,
            reservation.ReservationCode,
            PrescriptionCropUrl: reservation.PrescriptionCropUrl);
    }

    private static string GenerateCode()
    {
        Span<byte> bytes = stackalloc byte[3];
        RandomNumberGenerator.Fill(bytes);
        return $"NWQ-{bytes[0]:X2}{bytes[1]:X2}{bytes[2]:X2}";
    }
}
