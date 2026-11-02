using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.DeleteInventoryItem;

public sealed record DeleteInventoryItemCommand(Guid Id) : IRequest;

public sealed class DeleteInventoryItemCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    ICacheService cacheService)
    : IRequestHandler<DeleteInventoryItemCommand>
{
    public async Task Handle(DeleteInventoryItemCommand request, CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken);

        if (pharmacy is null)
            throw new NotFoundException(nameof(Domain.Entities.Pharmacy), currentUser.UserId);

        var item = await context.InventoryItems
            .FirstOrDefaultAsync(i => i.Id == request.Id && i.PharmacyId == pharmacy.Id, cancellationToken);

        if (item is null)
            throw new NotFoundException(nameof(Domain.Entities.InventoryItem), request.Id);

        // Check if there are active or ready reservations holding this item
        var hasActiveReservations = await context.Reservations
            .AnyAsync(r => r.InventoryItemId == item.Id &&
                           (r.Status == ReservationStatus.Active || r.Status == ReservationStatus.Ready), cancellationToken);

        if (hasActiveReservations)
        {
            throw new ConflictException("لا يمكن حذف هذا الصنف لوجود حجز نشط مرتبط به حالياً. يرجى إتمام أو إلغاء الحجز أولاً.");
        }

        // Soft delete the item
        item.IsDeleted = true;
        item.Status = InventoryStatus.OutOfStock;
        item.Quantity = 0;
        item.UpdatedAt = DateTime.UtcNow;

        await context.SaveChangesAsync(cancellationToken);

        // Invalidate caches
        await cacheService.RemoveAsync($"nawakes:pharmacy:inventory:{pharmacy.Id}", cancellationToken);
        foreach (var pattern in Nawakes.Domain.Common.DrugNameNormalizer.GetSearchCachePatterns(item.MedicationName))
        {
            await cacheService.RemoveByPatternAsync(pattern, cancellationToken);
        }
    }
}

