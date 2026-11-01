import 'package:freezed_annotation/freezed_annotation.dart';

part 'pharmacy_dashboard_models.g.dart';

// ─── Reservation Models ──────────────────────────────────────────────────────

@JsonSerializable()
class PharmacyReservationResponse {
  final String id;
  final String patientDisplayName;
  final String medicationName;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String reservationCode;
  final String? chronicConditions;
  final String? allergies;
  final bool allowPharmacistViewActiveMedications;
  final List<String>? activeMedications;
  final String? clinicalContraindicationReason;
  final String? recommendedAlternativeMedication;

  PharmacyReservationResponse({
    required this.id,
    required this.patientDisplayName,
    required this.medicationName,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.reservationCode = '',
    this.chronicConditions,
    this.allergies,
    this.allowPharmacistViewActiveMedications = false,
    this.activeMedications,
    this.clinicalContraindicationReason,
    this.recommendedAlternativeMedication,
  });

  factory PharmacyReservationResponse.fromJson(Map<String, dynamic> json) =>
      _$PharmacyReservationResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PharmacyReservationResponseToJson(this);
}

@JsonSerializable()
class ClinicalRejectRequest {
  final String reason;
  final String recommendedMedicationName;
  final String? recommendedInventoryItemId;

  ClinicalRejectRequest({
    required this.reason,
    required this.recommendedMedicationName,
    this.recommendedInventoryItemId,
  });

  factory ClinicalRejectRequest.fromJson(Map<String, dynamic> json) =>
      _$ClinicalRejectRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ClinicalRejectRequestToJson(this);
}

// ─── Inventory Models ────────────────────────────────────────────────────────

@JsonSerializable(createFactory: false)
class PharmacyInventoryItemDto {
  final String id;
  final String medicationName;
  final double price;
  final int quantity;
  final String status;
  final String? patientNote;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime? lastUpdatedAt;

  PharmacyInventoryItemDto({
    required this.id,
    required this.medicationName,
    required this.price,
    this.quantity = 0,
    required this.status,
    this.patientNote,
    this.expiryDate,
    required this.createdAt,
    this.lastUpdatedAt,
  });

  factory PharmacyInventoryItemDto.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreatedAt;
    if (json['createdAt'] != null) {
      try {
        parsedCreatedAt = DateTime.parse(json['createdAt'].toString());
      } catch (_) {
        parsedCreatedAt = DateTime.now();
      }
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return PharmacyInventoryItemDto(
      id: (json['id'] ?? '').toString(),
      medicationName: (json['medicationName'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'InStock').toString(),
      patientNote: json['patientNote'] as String?,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'].toString())
          : null,
      createdAt: parsedCreatedAt,
      lastUpdatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : (json['lastUpdatedAt'] != null
              ? DateTime.tryParse(json['lastUpdatedAt'].toString())
              : null),
    );
  }

  Map<String, dynamic> toJson() => _$PharmacyInventoryItemDtoToJson(this);
}

@JsonSerializable()
class PagedInventoryResult {
  final List<PharmacyInventoryItemDto> items;
  final int totalCount;
  final int pageNumber;
  final int pageSize;
  final int totalPages;

  PagedInventoryResult({
    required this.items,
    required this.totalCount,
    required this.pageNumber,
    required this.pageSize,
    required this.totalPages,
  });

  factory PagedInventoryResult.fromJson(Map<String, dynamic> json) =>
      _$PagedInventoryResultFromJson(json);
  Map<String, dynamic> toJson() => _$PagedInventoryResultToJson(this);
}

class AddInventoryItemRequest {
  final String medicationName;
  final double price;
  final int quantity;
  final String? patientNote;
  final int? status;
  final String? dosageForm;
  final String? strength;

  AddInventoryItemRequest({
    required this.medicationName,
    required this.price,
    required this.quantity,
    this.patientNote,
    this.status,
    this.dosageForm,
    this.strength,
  });

  factory AddInventoryItemRequest.fromJson(Map<String, dynamic> json) =>
      AddInventoryItemRequest(
        medicationName: json['medicationName'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 10,
        patientNote: json['patientNote'] as String?,
        status: (json['status'] as num?)?.toInt(),
        dosageForm: json['dosageForm'] as String?,
        strength: json['strength'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'medicationName': medicationName,
        'price': price,
        'quantity': quantity,
        if (patientNote != null) 'patientNote': patientNote,
        if (status != null) 'status': status,
        if (dosageForm != null) 'dosageForm': dosageForm,
        if (strength != null) 'strength': strength,
      };
}

@JsonSerializable()
class ToggleStatusRequest {
  final int status; // 0 = InStock, 1 = OutOfStock

  ToggleStatusRequest({required this.status});

  factory ToggleStatusRequest.fromJson(Map<String, dynamic> json) =>
      _$ToggleStatusRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ToggleStatusRequestToJson(this);
}

@JsonSerializable()
class SetAvailabilityRequest {
  final int quantity;
  final bool? inStock;
  final double? price;
  final String? patientNote;

  SetAvailabilityRequest({
    required this.quantity,
    this.inStock,
    this.price,
    this.patientNote,
  });

  factory SetAvailabilityRequest.fromJson(Map<String, dynamic> json) =>
      _$SetAvailabilityRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SetAvailabilityRequestToJson(this);
}

@JsonSerializable()
class BulkImportResultDto {
  final int importedCount;
  final int skippedCount;
  final List<String> errors;

  int get imported => importedCount;
  int get skipped => skippedCount;

  BulkImportResultDto({
    this.importedCount = 0,
    this.skippedCount = 0,
    this.errors = const [],
  });

  factory BulkImportResultDto.fromJson(Map<String, dynamic> json) =>
      _$BulkImportResultDtoFromJson(json);
  Map<String, dynamic> toJson() => _$BulkImportResultDtoToJson(this);
}

@JsonSerializable()
class CancelByPharmacyRequest {
  final String? reason;

  CancelByPharmacyRequest({this.reason});

  factory CancelByPharmacyRequest.fromJson(Map<String, dynamic> json) =>
      _$CancelByPharmacyRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CancelByPharmacyRequestToJson(this);
}
