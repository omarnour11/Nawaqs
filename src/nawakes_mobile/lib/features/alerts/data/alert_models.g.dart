// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAlertRequest _$CreateAlertRequestFromJson(Map<String, dynamic> json) =>
    CreateAlertRequest(
      medicationName: json['medicationName'] as String,
      radiusKm: (json['radiusKm'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );

Map<String, dynamic> _$CreateAlertRequestToJson(CreateAlertRequest instance) =>
    <String, dynamic>{
      'medicationName': instance.medicationName,
      'radiusKm': instance.radiusKm,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };

AlertDto _$AlertDtoFromJson(Map<String, dynamic> json) => AlertDto(
  id: json['id'] as String,
  medicationName: json['medicationName'] as String,
  radiusKm: (json['radiusKm'] as num).toDouble(),
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  isActive: json['isActive'] as bool,
  lastNotifiedAt: json['lastNotifiedAt'] == null
      ? null
      : DateTime.parse(json['lastNotifiedAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$AlertDtoToJson(AlertDto instance) => <String, dynamic>{
  'id': instance.id,
  'medicationName': instance.medicationName,
  'radiusKm': instance.radiusKm,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'isActive': instance.isActive,
  'lastNotifiedAt': instance.lastNotifiedAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
};
