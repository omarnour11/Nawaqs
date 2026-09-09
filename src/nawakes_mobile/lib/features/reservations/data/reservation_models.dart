import 'package:freezed_annotation/freezed_annotation.dart';

part 'reservation_models.g.dart';

@JsonSerializable()
class CreateReservationRequest {
  final String inventoryItemId;

  CreateReservationRequest({required this.inventoryItemId});

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
  });

  factory ReservationResponse.fromJson(Map<String, dynamic> json) =>
      _$ReservationResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ReservationResponseToJson(this);
}
