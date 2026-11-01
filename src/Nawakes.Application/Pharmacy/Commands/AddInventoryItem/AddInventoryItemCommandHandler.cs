using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacy.Dtos;
using Nawakes.Domain.Common;
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

        var (effectiveName, normalized) = DrugNameNormalizer.BuildCanonicalInventoryMedication(
            request.MedicationName,
            request.Strength,
            request.DosageForm);
        var qty = Math.Clamp(request.Quantity, 0, 100_000);
        var status = qty == 0 ? InventoryStatus.OutOfStock : InventoryStatus.InStock;

        // Fast index-backed lookup: matches PharmacyId + Normalized Name + Price
        // Uses the database index without scanning the entire pharmacy inventory
        var existingItem = await context.InventoryItems
            .FirstOrDefaultAsync(i =>
                i.PharmacyId == pharmacy.Id &&
                i.MedicationNameNormalized == normalized &&
                i.Price == request.Price,
                cancellationToken);

        InventoryItem targetItem;

        if (existingItem != null)
        {
            // Fast in-place merge: add quantity to existing inventory item
            existingItem.Quantity = Math.Clamp(existingItem.Quantity + qty, 0, 100_000);
            if (existingItem.Quantity > 0 && existingItem.Status == InventoryStatus.OutOfStock)
            {
                existingItem.Status = InventoryStatus.InStock;
            }
            if (!string.IsNullOrWhiteSpace(request.PatientNote))
            {
                existingItem.PatientNote = request.PatientNote.Trim();
            }
            existingItem.UpdatedAt = DateTime.UtcNow;
            targetItem = existingItem;
        }
        else
        {
            targetItem = new InventoryItem
            {
                PharmacyId = pharmacy.Id,
                MedicationName = effectiveName,
                MedicationNameNormalized = normalized,
                Price = request.Price,
                Quantity = qty,
                PatientNote = string.IsNullOrWhiteSpace(request.PatientNote)
                    ? null
                    : request.PatientNote.Trim(),
                Status = status
            };
            context.InventoryItems.Add(targetItem);
        }

        await context.SaveChangesAsync(cancellationToken);

        // Invalidate specific pharmacy inventory cache
        await cacheService.RemoveAsync($"nawakes:pharmacy:inventory:{pharmacy.Id}", cancellationToken);

        // Invalidate relevant search cache matching this medication (both raw and underscored patterns)
        var medLookup = DrugNameNormalizer.NormalizeLookup(request.MedicationName);
        var medUnderscored = medLookup.Replace(' ', '_');
        await cacheService.RemoveByPatternAsync($"nawakes:search:{medUnderscored}:*", cancellationToken);
        if (medUnderscored != medLookup)
        {
            await cacheService.RemoveByPatternAsync($"nawakes:search:{medLookup}:*", cancellationToken);
        }

        if (targetItem.Status == InventoryStatus.InStock)
        {
            jobScheduler.EnqueueAvailabilityNotification(targetItem.Id);
        }

        return new InventoryItemDto(
            targetItem.Id,
            targetItem.MedicationName,
            targetItem.Price,
            targetItem.Quantity,
            targetItem.Status.ToString(),
            targetItem.PatientNote,
            targetItem.UpdatedAt,
            targetItem.CreatedAt);
    }
}
