using MediatR;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacy.Dtos;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.SetAvailability;

/// <summary>
/// Pharmacy availability setter: available / limited / unavailable with unit quantity.
/// Replaces the binary toggle — quantity semantics: 0 = unavailable, 1-4 = limited, 5+ = available.
/// </summary>
public sealed record SetAvailabilityCommand(
    Guid Id,
    int Quantity,
    decimal? Price,
    string? PatientNote) : IRequest<InventoryItemDto>;

public sealed class SetAvailabilityCommandValidator : AbstractValidator<SetAvailabilityCommand>
{
    public SetAvailabilityCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Quantity).InclusiveBetween(0, 100000);
        RuleFor(x => x.PatientNote).MaximumLength(300);
    }
}

public sealed class SetAvailabilityCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    ICacheService cacheService,
    IInventoryJobScheduler jobScheduler)
    : IRequestHandler<SetAvailabilityCommand, InventoryItemDto>
{
    public async Task<InventoryItemDto> Handle(SetAvailabilityCommand request, CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.Pharmacy), currentUser.UserId);

        var item = await context.InventoryItems
            .FirstOrDefaultAsync(i => i.Id == request.Id && i.PharmacyId == pharmacy.Id, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.InventoryItem), request.Id);

        var wasInStock = item.Status == InventoryStatus.InStock;

        // Cannot go unavailable while an active reservation holds the item
        if (request.Quantity == 0 && item.Status == InventoryStatus.Reserved)
        {
            var hasActiveReservation = await context.Reservations.AnyAsync(
                r => r.InventoryItemId == item.Id && r.Status == ReservationStatus.Active, cancellationToken);
            if (hasActiveReservation)
                throw new ConflictException("لا يمكن تعديل التوفر أثناء وجود حجز نشط على هذا الدواء.");
        }

        item.Quantity = request.Quantity;
        if (request.Price is not null) item.Price = request.Price.Value;
        item.PatientNote = string.IsNullOrWhiteSpace(request.PatientNote) ? null : request.PatientNote.Trim();

        var previousStatus = item.Status;
        item.Status = request.Quantity switch
        {
            0 => InventoryStatus.OutOfStock,
            <= 4 => InventoryStatus.InStock, // limited — quantity signals it
            _ => InventoryStatus.InStock
        };

        await context.SaveChangesAsync(cancellationToken);

        // Cache invalidation
        await cacheService.RemoveAsync($"nawakes:pharmacy:inventory:{pharmacy.Id}", cancellationToken);
        var medNormalized = item.MedicationName.Trim().ToLowerInvariant();
        await cacheService.RemoveByPatternAsync($"nawakes:search:{medNormalized}:*", cancellationToken);

        // Restock notifications fire when going 0 → in stock
        if (previousStatus == InventoryStatus.OutOfStock && item.Status == InventoryStatus.InStock)
            jobScheduler.EnqueueAvailabilityNotification(item.Id);

        return new InventoryItemDto(item.Id, item.MedicationName, item.Price, item.Status.ToString(), item.UpdatedAt);
    }
}
