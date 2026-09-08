using MediatR;
using Nawakes.Application.Pharmacy.Dtos;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.AddInventoryItem;

/// <summary>
/// Adds a new inventory item to the caller's pharmacy.
/// </summary>
public sealed record AddInventoryItemCommand(
    string MedicationName,
    decimal Price,
    InventoryStatus Status) : IRequest<InventoryItemDto>;
