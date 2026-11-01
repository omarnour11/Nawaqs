namespace Nawakes.Application.Reservations.Dtos;

public sealed record ReservationDto(
    Guid Id,
    Guid InventoryItemId,
    Guid PharmacyId,
    string PharmacyName,
    string PharmacyPhone,
    string MedicationName,
    string Status,
    DateTime ExpiresAt,
    DateTime CreatedAt,
    string ReservationCode,
    string? ClinicalContraindicationReason = null,
    string? RecommendedAlternativeMedication = null,
    Guid? RecommendedAlternativeItemId = null
);

public sealed record PharmacyReservationDto(
    Guid Id,
    string PatientDisplayName,   // Anonymized: "مريض #XXXX"
    string MedicationName,
    string Status,
    DateTime ExpiresAt,
    DateTime CreatedAt,
    string ReservationCode,
    string? ChronicConditions = null,
    string? Allergies = null,
    bool AllowPharmacistViewActiveMedications = false,
    IReadOnlyList<string>? ActiveMedications = null,
    string? ClinicalContraindicationReason = null,
    string? RecommendedAlternativeMedication = null
);
