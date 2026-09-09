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
class AlertDto {
  final String id;
  final String medicationName;
  final double radiusKm;
  final double latitude;
  final double longitude;
  final bool isActive;
  final DateTime? lastNotifiedAt;
  final DateTime createdAt;

  AlertDto({
    required this.id,
    required this.medicationName,
    required this.radiusKm,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    this.lastNotifiedAt,
    required this.createdAt,
  });

  factory AlertDto.fromJson(Map<String, dynamic> json) => _$AlertDtoFromJson(json);
  Map<String, dynamic> toJson() => _$AlertDtoToJson(this);
}
