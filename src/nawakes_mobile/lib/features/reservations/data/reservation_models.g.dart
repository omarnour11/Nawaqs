// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateReservationRequest _$CreateReservationRequestFromJson(
  Map<String, dynamic> json,
) => CreateReservationRequest(
  inventoryItemId: json['inventoryItemId'] as String,
  prescriptionCropBase64: json['prescriptionCropBase64'] as String?,
  prescriptionCropUrl: json['prescriptionCropUrl'] as String?,
  fulfillmentType: json['fulfillmentType'] as String? ?? 'Pickup',
  deliveryAddress: json['deliveryAddress'] as String?,
  deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
  deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
  deliveryContactPhone: json['deliveryContactPhone'] as String?,
  deliveryNotes: json['deliveryNotes'] as String?,
);

Map<String, dynamic> _$CreateReservationRequestToJson(
  CreateReservationRequest instance,
) => <String, dynamic>{
  'inventoryItemId': instance.inventoryItemId,
  'prescriptionCropBase64': instance.prescriptionCropBase64,
  'prescriptionCropUrl': instance.prescriptionCropUrl,
  'fulfillmentType': instance.fulfillmentType,
  'deliveryAddress': instance.deliveryAddress,
  'deliveryLatitude': instance.deliveryLatitude,
  'deliveryLongitude': instance.deliveryLongitude,
  'deliveryContactPhone': instance.deliveryContactPhone,
  'deliveryNotes': instance.deliveryNotes,
};

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
      clinicalContraindicationReason:
          json['clinicalContraindicationReason'] as String?,
      recommendedAlternativeMedication:
          json['recommendedAlternativeMedication'] as String?,
      recommendedAlternativeItemId:
          json['recommendedAlternativeItemId'] as String?,
      prescriptionCropUrl: json['prescriptionCropUrl'] as String?,
      fulfillmentType: json['fulfillmentType'] as String? ?? 'Pickup',
      deliveryAddress: json['deliveryAddress'] as String?,
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
      deliveryContactPhone: json['deliveryContactPhone'] as String?,
      deliveryNotes: json['deliveryNotes'] as String?,
      deliveryStatus: json['deliveryStatus'] as String?,
      pharmacyLatitude: (json['pharmacyLatitude'] as num?)?.toDouble(),
      pharmacyLongitude: (json['pharmacyLongitude'] as num?)?.toDouble(),
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
  'clinicalContraindicationReason': instance.clinicalContraindicationReason,
  'recommendedAlternativeMedication': instance.recommendedAlternativeMedication,
  'recommendedAlternativeItemId': instance.recommendedAlternativeItemId,
  'prescriptionCropUrl': instance.prescriptionCropUrl,
  'fulfillmentType': instance.fulfillmentType,
  'deliveryAddress': instance.deliveryAddress,
  'deliveryLatitude': instance.deliveryLatitude,
  'deliveryLongitude': instance.deliveryLongitude,
  'deliveryContactPhone': instance.deliveryContactPhone,
  'deliveryNotes': instance.deliveryNotes,
  'deliveryStatus': instance.deliveryStatus,
  'pharmacyLatitude': instance.pharmacyLatitude,
  'pharmacyLongitude': instance.pharmacyLongitude,
};
