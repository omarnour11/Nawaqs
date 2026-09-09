// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateReservationRequest _$CreateReservationRequestFromJson(
  Map<String, dynamic> json,
) => CreateReservationRequest(
  inventoryItemId: json['inventoryItemId'] as String,
);

Map<String, dynamic> _$CreateReservationRequestToJson(
  CreateReservationRequest instance,
) => <String, dynamic>{'inventoryItemId': instance.inventoryItemId};

ReservationResponse _$ReservationResponseFromJson(Map<String, dynamic> json) =>
    ReservationResponse(
      id: json['id'] as String,
      inventoryItemId: json['inventoryItemId'] as String,
      pharmacyId: json['pharmacyId'] as String,
      pharmacyName: json['pharmacyName'] as String,
      pharmacyPhone: json['pharmacyPhone'] as String? ?? '',
      medicationName: json['medicationName'] as String,
      status: json['status'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      reservationCode: json['reservationCode'] as String,
    );

Map<String, dynamic> _$ReservationResponseToJson(
  ReservationResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'inventoryItemId': instance.inventoryItemId,
  'pharmacyId': instance.pharmacyId,
  'pharmacyName': instance.pharmacyName,
  'pharmacyPhone': instance.pharmacyPhone,
  'medicationName': instance.medicationName,
  'status': instance.status,
  'expiresAt': instance.expiresAt.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'reservationCode': instance.reservationCode,
};
