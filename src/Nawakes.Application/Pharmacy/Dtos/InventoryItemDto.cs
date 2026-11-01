namespace Nawakes.Application.Pharmacy.Dtos;

/// <summary>
/// Shared DTO returned from AddInventoryItem, ToggleStatus, and SetAvailability mutations.
/// Includes all fields needed by the pharmacy dashboard so a follow-up GET is not required.
/// </summary>
public sealed record InventoryItemDto(
    Guid Id,
    string MedicationName,
    decimal Price,
    int Quantity,
    string Status,
    string? PatientNote,
    DateTime UpdatedAt,
    DateTime CreatedAt = default
);
