using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Shortage.Commands.ClaimShortageRequest;

/// <summary>
/// Pharmacy claims an open shortage request: creates a reservation + QR pass
/// for the patient and marks the request Claimed. First claim wins (row-level guard).
/// </summary>
public sealed record ClaimShortageRequestCommand(Guid RequestId) : IRequest<Guid>;

public sealed class ClaimShortageRequestCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<ClaimShortageRequestCommand, Guid>
{
    public async Task<Guid> Handle(ClaimShortageRequestCommand request, CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.Pharmacy), currentUser.UserId);

        if (pharmacy.VerificationStatus != VerificationStatus.Approved)
            throw new ForbiddenException("لازم تكون صيدلية موثقة عشان تطالب بطلبات النواقص.");

        var req = await context.ShortageRequests
            .FirstOrDefaultAsync(r => r.Id == request.RequestId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.ShortageRequest), request.RequestId);

        if (req.Status != ShortageRequestStatus.Open || req.ExpiresAt <= DateTime.UtcNow)
            throw new ConflictException("الطلب مأخوذ أو منتهي.");

        // Find the best matching in-stock item at this pharmacy
        var item = await context.InventoryItems
            .FirstOrDefaultAsync(i => i.PharmacyId == pharmacy.Id &&
                                      i.MedicationNameNormalized == req.MedicationNameNormalized &&
                                      i.Status == InventoryStatus.InStock &&
                                      i.Quantity >= req.QuantityNeeded, cancellationToken);

        if (item is null)
            throw new ConflictException("مفيش مخزون كفاية عندك من هذا الدواء دلوقتي.");

        // Race guard: flip status first — EF concurrency on SaveChanges if two claim simultaneously
        req.Status = ShortageRequestStatus.Claimed;
        req.ClaimedByPharmacyId = pharmacy.Id;
        req.ClaimedAt = DateTime.UtcNow;

        // Create the hold + reservation for the patient
        item.Status = InventoryStatus.Reserved;
        var expiresAt = DateTime.UtcNow.AddHours(2);
        var code = $"NWQ-{Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(3))}";

        var reservation = new Domain.Entities.Reservation
        {
            UserId = req.UserId,
            InventoryItemId = item.Id,
            PharmacyId = pharmacy.Id,
            Status = ReservationStatus.Active,
            ExpiresAt = expiresAt,
            ReservationCode = code
        };
        context.Reservations.Add(reservation);

        req.FulfilledReservationId = reservation.Id;

        context.Notifications.Add(new Domain.Entities.UserNotification
        {
            UserId = req.UserId,
            Type = NotificationType.MedicationAvailable,
            Title = "اتوجد ليكم الدواء!",
            Body = $"{pharmacy.Name} جاوبت على طلبكم لـ{req.MedicationName}. التصريح جاهز في تبويب التصاريح لمدة ساعتين.",
            RelatedEntityId = reservation.Id
        });

        await context.SaveChangesAsync(cancellationToken);
        return reservation.Id;
    }
}
