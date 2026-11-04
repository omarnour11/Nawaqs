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

ToggleAlertRequest _$ToggleAlertRequestFromJson(Map<String, dynamic> json) =>
    ToggleAlertRequest(isActive: json['isActive'] as bool);

Map<String, dynamic> _$ToggleAlertRequestToJson(ToggleAlertRequest instance) =>
    <String, dynamic>{'isActive': instance.isActive};

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
  queueStatus: json['queueStatus'] as String? ?? 'Waiting',
  queuePosition: (json['queuePosition'] as num?)?.toInt() ?? 0,
  offerExpiresAt: json['offerExpiresAt'] == null
      ? null
      : DateTime.parse(json['offerExpiresAt'] as String),
  offeredInventoryItemId: json['offeredInventoryItemId'] as String?,
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
  'queueStatus': instance.queueStatus,
  'queuePosition': instance.queuePosition,
  'offerExpiresAt': instance.offerExpiresAt?.toIso8601String(),
  'offeredInventoryItemId': instance.offeredInventoryItemId,
};
