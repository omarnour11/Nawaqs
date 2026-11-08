import 'package:freezed_annotation/freezed_annotation.dart';

part 'reservation_models.g.dart';

@JsonSerializable()
class CreateReservationRequest {
  final String inventoryItemId;
  final String? prescriptionCropBase64;
  final String? prescriptionCropUrl;
  final String fulfillmentType;
  final String? deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? deliveryContactPhone;
  final String? deliveryNotes;

  CreateReservationRequest({
    required this.inventoryItemId,
    this.prescriptionCropBase64,
    this.prescriptionCropUrl,
    this.fulfillmentType = 'Pickup',
    this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryContactPhone,
    this.deliveryNotes,
  });

  factory CreateReservationRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateReservationRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateReservationRequestToJson(this);
}

@JsonSerializable()
class ReservationResponse {
  final String id;
  final String inventoryItemId;
  final String pharmacyId;
  final String pharmacyName;
  final String pharmacyPhone;
  final String medicationName;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String reservationCode;
  final String? clinicalContraindicationReason;
  final String? recommendedAlternativeMedication;
  final String? recommendedAlternativeItemId;
  final String? prescriptionCropUrl;
  final String fulfillmentType;
  final String? deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? deliveryContactPhone;
  final String? deliveryNotes;
  final String? deliveryStatus;
  final double? pharmacyLatitude;
  final double? pharmacyLongitude;

  ReservationResponse({
    required this.id,
    required this.inventoryItemId,
    required this.pharmacyId,
    required this.pharmacyName,
    this.pharmacyPhone = '',
    required this.medicationName,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.reservationCode,
    this.clinicalContraindicationReason,
    this.recommendedAlternativeMedication,
    this.recommendedAlternativeItemId,
    this.prescriptionCropUrl,
    this.fulfillmentType = 'Pickup',
    this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryContactPhone,
    this.deliveryNotes,
    this.deliveryStatus,
    this.pharmacyLatitude,
    this.pharmacyLongitude,
  });

  factory ReservationResponse.fromJson(Map<String, dynamic> json) =>
      _$ReservationResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ReservationResponseToJson(this);
}
