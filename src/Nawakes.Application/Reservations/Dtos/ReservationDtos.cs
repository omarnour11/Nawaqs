using Nawakes.Application.Common.Interfaces;

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
    Guid? RecommendedAlternativeItemId = null,
    string? PrescriptionCropUrl = null,
    string? FulfillmentType = "Pickup",
    string? DeliveryAddress = null,
    double? DeliveryLatitude = null,
    double? DeliveryLongitude = null,
    string? DeliveryContactPhone = null,
    string? DeliveryNotes = null,
    string? DeliveryStatus = null,
    IReadOnlyList<SafetyAlertDto>? SafetyAlerts = null,
    double? PharmacyLatitude = null,
    double? PharmacyLongitude = null
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
    string? RecommendedAlternativeMedication = null,
    string? PrescriptionCropUrl = null,
    string? FulfillmentType = "Pickup",
    string? DeliveryAddress = null,
    double? DeliveryLatitude = null,
    double? DeliveryLongitude = null,
    string? DeliveryContactPhone = null,
    string? DeliveryNotes = null,
    string? DeliveryStatus = null,
    string? PatientGender = null,
    int? PatientAge = null
);
