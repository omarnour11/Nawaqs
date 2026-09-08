import 'package:freezed_annotation/freezed_annotation.dart';

part 'pharmacy_dashboard_models.g.dart';

@JsonSerializable()
class PharmacyReservationResponse {
  final String id;
  final String patientDisplayName;
  final String medicationName;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;

  PharmacyReservationResponse({
    required this.id,
    required this.patientDisplayName,
    required this.medicationName,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  factory PharmacyReservationResponse.fromJson(Map<String, dynamic> json) => _$PharmacyReservationResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PharmacyReservationResponseToJson(this);
}

@JsonSerializable()
class PharmacyInventoryItemDto {
  final String id;
  final String medicationName;
  final double price;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PharmacyInventoryItemDto({
    required this.id,
    required this.medicationName,
    required this.price,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory PharmacyInventoryItemDto.fromJson(Map<String, dynamic> json) => _$PharmacyInventoryItemDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PharmacyInventoryItemDtoToJson(this);
}

@JsonSerializable()
class ToggleStatusRequest {
  final int status; // 0 = InStock, 1 = OutOfStock

  ToggleStatusRequest({required this.status});

  factory ToggleStatusRequest.fromJson(Map<String, dynamic> json) => _$ToggleStatusRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ToggleStatusRequestToJson(this);
}

@JsonSerializable()
class AddInventoryItemRequest {
  final String medicationName;
  final double price;
  final int status; // 0 = InStock, 1 = OutOfStock

  AddInventoryItemRequest({
    required this.medicationName,
    required this.price,
    required this.status,
  });

  factory AddInventoryItemRequest.fromJson(Map<String, dynamic> json) => _$AddInventoryItemRequestFromJson(json);
  Map<String, dynamic> toJson() => _$AddInventoryItemRequestToJson(this);
}
