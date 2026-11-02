// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pharmacy_dashboard_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PharmacyReservationResponse _$PharmacyReservationResponseFromJson(
  Map<String, dynamic> json,
) => PharmacyReservationResponse(
  id: json['id'] as String,
  patientDisplayName: json['patientDisplayName'] as String,
  medicationName: json['medicationName'] as String,
  status: json['status'] as String,
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  reservationCode: json['reservationCode'] as String? ?? '',
  chronicConditions: json['chronicConditions'] as String?,
  allergies: json['allergies'] as String?,
  allowPharmacistViewActiveMedications:
      json['allowPharmacistViewActiveMedications'] as bool? ?? false,
  activeMedications: (json['activeMedications'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  clinicalContraindicationReason:
      json['clinicalContraindicationReason'] as String?,
  recommendedAlternativeMedication:
      json['recommendedAlternativeMedication'] as String?,
  fulfillmentType: json['fulfillmentType'] as String?,
  deliveryAddress: json['deliveryAddress'] as String?,
  deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
  deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
  deliveryContactPhone: json['deliveryContactPhone'] as String?,
  deliveryNotes: json['deliveryNotes'] as String?,
  deliveryStatus: json['deliveryStatus'] as String?,
  patientGender: json['patientGender'] as String?,
  patientAge: (json['patientAge'] as num?)?.toInt(),
);

Map<String, dynamic> _$PharmacyReservationResponseToJson(
  PharmacyReservationResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'patientDisplayName': instance.patientDisplayName,
  'medicationName': instance.medicationName,
  'status': instance.status,
  'expiresAt': instance.expiresAt.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'reservationCode': instance.reservationCode,
  'chronicConditions': instance.chronicConditions,
  'allergies': instance.allergies,
  'allowPharmacistViewActiveMedications':
      instance.allowPharmacistViewActiveMedications,
  'activeMedications': instance.activeMedications,
  'clinicalContraindicationReason': instance.clinicalContraindicationReason,
  'recommendedAlternativeMedication': instance.recommendedAlternativeMedication,
  'fulfillmentType': instance.fulfillmentType,
  'deliveryAddress': instance.deliveryAddress,
  'deliveryLatitude': instance.deliveryLatitude,
  'deliveryLongitude': instance.deliveryLongitude,
  'deliveryContactPhone': instance.deliveryContactPhone,
  'deliveryNotes': instance.deliveryNotes,
  'deliveryStatus': instance.deliveryStatus,
  'patientGender': instance.patientGender,
  'patientAge': instance.patientAge,
};

ClinicalRejectRequest _$ClinicalRejectRequestFromJson(
  Map<String, dynamic> json,
) => ClinicalRejectRequest(
  reason: json['reason'] as String,
  recommendedMedicationName: json['recommendedMedicationName'] as String,
  recommendedInventoryItemId: json['recommendedInventoryItemId'] as String?,
);

Map<String, dynamic> _$ClinicalRejectRequestToJson(
  ClinicalRejectRequest instance,
) => <String, dynamic>{
  'reason': instance.reason,
  'recommendedMedicationName': instance.recommendedMedicationName,
  'recommendedInventoryItemId': instance.recommendedInventoryItemId,
};

Map<String, dynamic> _$PharmacyInventoryItemDtoToJson(
  PharmacyInventoryItemDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'medicationName': instance.medicationName,
  'price': instance.price,
  'quantity': instance.quantity,
  'status': instance.status,
  'patientNote': instance.patientNote,
  'expiryDate': instance.expiryDate?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'lastUpdatedAt': instance.lastUpdatedAt?.toIso8601String(),
};

PagedInventoryResult _$PagedInventoryResultFromJson(
  Map<String, dynamic> json,
) => PagedInventoryResult(
  items: (json['items'] as List<dynamic>)
      .map((e) => PharmacyInventoryItemDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalCount: (json['totalCount'] as num).toInt(),
  pageNumber: (json['pageNumber'] as num).toInt(),
  pageSize: (json['pageSize'] as num).toInt(),
  totalPages: (json['totalPages'] as num).toInt(),
);

Map<String, dynamic> _$PagedInventoryResultToJson(
  PagedInventoryResult instance,
) => <String, dynamic>{
  'items': instance.items,
  'totalCount': instance.totalCount,
  'pageNumber': instance.pageNumber,
  'pageSize': instance.pageSize,
  'totalPages': instance.totalPages,
};

ToggleStatusRequest _$ToggleStatusRequestFromJson(Map<String, dynamic> json) =>
    ToggleStatusRequest(status: (json['status'] as num).toInt());

Map<String, dynamic> _$ToggleStatusRequestToJson(
  ToggleStatusRequest instance,
) => <String, dynamic>{'status': instance.status};

SetAvailabilityRequest _$SetAvailabilityRequestFromJson(
  Map<String, dynamic> json,
) => SetAvailabilityRequest(
  quantity: (json['quantity'] as num).toInt(),
  inStock: json['inStock'] as bool?,
  price: (json['price'] as num?)?.toDouble(),
  patientNote: json['patientNote'] as String?,
);

Map<String, dynamic> _$SetAvailabilityRequestToJson(
  SetAvailabilityRequest instance,
) => <String, dynamic>{
  'quantity': instance.quantity,
  'inStock': instance.inStock,
  'price': instance.price,
  'patientNote': instance.patientNote,
};

BulkImportResultDto _$BulkImportResultDtoFromJson(Map<String, dynamic> json) =>
    BulkImportResultDto(
      importedCount: (json['importedCount'] as num?)?.toInt() ?? 0,
      skippedCount: (json['skippedCount'] as num?)?.toInt() ?? 0,
      errors:
          (json['errors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$BulkImportResultDtoToJson(
  BulkImportResultDto instance,
) => <String, dynamic>{
  'importedCount': instance.importedCount,
  'skippedCount': instance.skippedCount,
  'errors': instance.errors,
};

CancelByPharmacyRequest _$CancelByPharmacyRequestFromJson(
  Map<String, dynamic> json,
) => CancelByPharmacyRequest(reason: json['reason'] as String?);

Map<String, dynamic> _$CancelByPharmacyRequestToJson(
  CancelByPharmacyRequest instance,
) => <String, dynamic>{'reason': instance.reason};
