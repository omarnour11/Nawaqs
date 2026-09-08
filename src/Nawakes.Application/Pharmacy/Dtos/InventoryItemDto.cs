using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Dtos;

public sealed record InventoryItemDto(
    Guid Id,
    string MedicationName,
    decimal Price,
    string Status,
    DateTime UpdatedAt
);
