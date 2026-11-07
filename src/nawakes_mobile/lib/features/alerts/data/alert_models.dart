import 'package:freezed_annotation/freezed_annotation.dart';

part 'alert_models.g.dart';

@JsonSerializable()
class CreateAlertRequest {
  final String medicationName;
  final double radiusKm;
  final double latitude;
  final double longitude;

  CreateAlertRequest({
    required this.medicationName,
    required this.radiusKm,
    required this.latitude,
    required this.longitude,
  });

  factory CreateAlertRequest.fromJson(Map<String, dynamic> json) => _$CreateAlertRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateAlertRequestToJson(this);
}

@JsonSerializable()
class ToggleAlertRequest {
  final bool isActive;

  ToggleAlertRequest({required this.isActive});

  factory ToggleAlertRequest.fromJson(Map<String, dynamic> json) => _$ToggleAlertRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ToggleAlertRequestToJson(this);
}

@JsonSerializable()
class AlertDto {
  final String id;
  final String medicationName;
  final double radiusKm;
  final double latitude;
  final double longitude;
  final bool isActive;
  final DateTime? lastNotifiedAt;
  final DateTime createdAt;
  // Queue state (populated by newer backend; defaults keep old payloads working)
  @JsonKey(defaultValue: 'Waiting')
  final String queueStatus; // Waiting | Offered | Claimed | Skipped
  @JsonKey(defaultValue: 0)
  final int queuePosition;
  final DateTime? offerExpiresAt;
  final String? offeredInventoryItemId;

  AlertDto({
    required this.id,
    required this.medicationName,
    required this.radiusKm,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    this.lastNotifiedAt,
    required this.createdAt,
    this.queueStatus = 'Waiting',
    this.queuePosition = 0,
    this.offerExpiresAt,
    this.offeredInventoryItemId,
  });

  bool get hasActiveOffer =>
      queueStatus == 'Offered' &&
      offerExpiresAt != null &&
      offerExpiresAt!.isAfter(DateTime.now());

  factory AlertDto.fromJson(Map<String, dynamic> json) => _$AlertDtoFromJson(json);
  Map<String, dynamic> toJson() => _$AlertDtoToJson(this);
}
