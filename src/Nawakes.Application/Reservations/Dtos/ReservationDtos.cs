using Nawakes.Domain.Enums;

namespace Nawakes.Application.Reservations.Dtos;

public sealed record ReservationDto(
    Guid Id,
    Guid InventoryItemId,
    Guid PharmacyId,
    string PharmacyName,
    string MedicationName,
    string Status,
    DateTime ExpiresAt,
    DateTime CreatedAt
);

public sealed record PharmacyReservationDto(
    Guid Id,
    string PatientDisplayName,   // Anonymized: "Patient #XXXX"
    string MedicationName,
    string Status,
    DateTime ExpiresAt,
    DateTime CreatedAt
);
