using MediatR;
using Nawakes.Application.Pharmacy.Dtos;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.ToggleInventoryItemStatus;

public sealed record ToggleInventoryItemStatusCommand(
    Guid Id,
    InventoryStatus TargetStatus) : IRequest<InventoryItemDto>;
