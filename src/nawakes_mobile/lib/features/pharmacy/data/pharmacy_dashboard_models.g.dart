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
};

PharmacyInventoryItemDto _$PharmacyInventoryItemDtoFromJson(
  Map<String, dynamic> json,
) => PharmacyInventoryItemDto(
  id: json['id'] as String,
  medicationName: json['medicationName'] as String,
  price: (json['price'] as num).toDouble(),
  status: json['status'] as String,
  quantity: (json['quantity'] as num?)?.toInt() ?? 10,
  patientNote: json['patientNote'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$PharmacyInventoryItemDtoToJson(
  PharmacyInventoryItemDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'medicationName': instance.medicationName,
  'price': instance.price,
  'status': instance.status,
  'quantity': instance.quantity,
  'patientNote': instance.patientNote,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

ToggleStatusRequest _$ToggleStatusRequestFromJson(Map<String, dynamic> json) =>
    ToggleStatusRequest(status: (json['status'] as num).toInt());

Map<String, dynamic> _$ToggleStatusRequestToJson(
  ToggleStatusRequest instance,
) => <String, dynamic>{'status': instance.status};

AddInventoryItemRequest _$AddInventoryItemRequestFromJson(
  Map<String, dynamic> json,
) => AddInventoryItemRequest(
  medicationName: json['medicationName'] as String,
  price: (json['price'] as num).toDouble(),
  status: (json['status'] as num).toInt(),
  quantity: (json['quantity'] as num?)?.toInt(),
  patientNote: json['patientNote'] as String?,
);

Map<String, dynamic> _$AddInventoryItemRequestToJson(
  AddInventoryItemRequest instance,
) => <String, dynamic>{
  'medicationName': instance.medicationName,
  'price': instance.price,
  'status': instance.status,
  'quantity': instance.quantity,
  'patientNote': instance.patientNote,
};
