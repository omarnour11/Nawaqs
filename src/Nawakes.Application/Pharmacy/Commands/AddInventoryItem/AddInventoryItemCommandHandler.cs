using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacy.Dtos;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.AddInventoryItem;

public sealed class AddInventoryItemCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    ICacheService cacheService,
    IInventoryJobScheduler jobScheduler)
    : IRequestHandler<AddInventoryItemCommand, InventoryItemDto>
{
    public async Task<InventoryItemDto> Handle(AddInventoryItemCommand request, CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken);

        if (pharmacy is null)
            throw new NotFoundException(nameof(Domain.Entities.Pharmacy), currentUser.UserId);

        if (pharmacy.VerificationStatus != VerificationStatus.Approved)
            throw new ForbiddenException("Only approved pharmacies can manage inventory.");

        var item = new InventoryItem
        {
            PharmacyId = pharmacy.Id,
            MedicationName = request.MedicationName,
            Price = request.Price,
            Status = request.Status
        };

        context.InventoryItems.Add(item);
        await context.SaveChangesAsync(cancellationToken);

        // Invalidate specific pharmacy inventory cache
        await cacheService.RemoveAsync($"nawakes:pharmacy:inventory:{pharmacy.Id}", cancellationToken);

        // Invalidate relevant search cache matching this medication
        var medNormalized = request.MedicationName.Trim().ToLowerInvariant();
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
