using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacy.Dtos;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.ToggleInventoryItemStatus;

public sealed class ToggleInventoryItemStatusCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    ICacheService cacheService,
    IInventoryJobScheduler jobScheduler)
    : IRequestHandler<ToggleInventoryItemStatusCommand, InventoryItemDto>
{
    public async Task<InventoryItemDto> Handle(ToggleInventoryItemStatusCommand request, CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken);

        if (pharmacy is null)
            throw new NotFoundException(nameof(Domain.Entities.Pharmacy), currentUser.UserId);

        var item = await context.InventoryItems
            .FirstOrDefaultAsync(i => i.Id == request.Id && i.PharmacyId == pharmacy.Id, cancellationToken);

        if (item is null)
            throw new NotFoundException(nameof(Domain.Entities.InventoryItem), request.Id);

        if (item.Status == request.TargetStatus)
        {
            return new InventoryItemDto(item.Id, item.MedicationName, item.Price, item.Status.ToString(), item.UpdatedAt);
        }

        // Toggle to OutOfStock blocked if item has Active reservation
        if (request.TargetStatus == InventoryStatus.OutOfStock && item.Status == InventoryStatus.Reserved)
        {
            var hasActiveReservation = await context.Reservations.AnyAsync(r => 
                r.InventoryItemId == item.Id && r.Status == ReservationStatus.Active, cancellationToken);
                
            if (hasActiveReservation)
            {
                throw new ConflictException("Cannot change status to OutOfStock while there is an active reservation.");
            }
        }

        item.Status = request.TargetStatus;
        await context.SaveChangesAsync(cancellationToken);

        // Invalidate specific pharmacy inventory cache
        await cacheService.RemoveAsync($"nawakes:pharmacy:inventory:{pharmacy.Id}", cancellationToken);

        // Invalidate relevant search cache matching this medication
        var medNormalized = item.MedicationName.Trim().ToLowerInvariant();
        await cacheService.RemoveByPatternAsync($"nawakes:search:{medNormalized}:*", cancellationToken);

        if (item.Status == InventoryStatus.InStock)
        {
            jobScheduler.EnqueueAvailabilityNotification(item.Id);
        }

        return new InventoryItemDto(
            item.Id,
            item.MedicationName,
            item.Price,
            item.Status.ToString(),
            item.UpdatedAt);
    }
}
