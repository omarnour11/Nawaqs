// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pharmacy_profile_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyPharmacyDto _$MyPharmacyDtoFromJson(Map<String, dynamic> json) =>
    MyPharmacyDto(
      id: json['id'] as String,
      name: json['name'] as String,
      addressLine: json['addressLine'] as String,
      city: json['city'] as String,
      phone: json['phone'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      verificationStatus: json['verificationStatus'] as String,
      rejectionReason: json['rejectionReason'] as String?,
      licenseDocUrl: json['licenseDocUrl'] as String?,
      nationalIdDocUrl: json['nationalIdDocUrl'] as String?,
      trustScore: (json['trustScore'] as num).toDouble(),
      averageRating: (json['averageRating'] as num).toDouble(),
      ratingCount: (json['ratingCount'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$MyPharmacyDtoToJson(MyPharmacyDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'addressLine': instance.addressLine,
      'city': instance.city,
      'phone': instance.phone,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'verificationStatus': instance.verificationStatus,
      'rejectionReason': instance.rejectionReason,
      'licenseDocUrl': instance.licenseDocUrl,
      'nationalIdDocUrl': instance.nationalIdDocUrl,
      'trustScore': instance.trustScore,
      'averageRating': instance.averageRating,
      'ratingCount': instance.ratingCount,
      'createdAt': instance.createdAt.toIso8601String(),
    };

RegisterPharmacyRequest _$RegisterPharmacyRequestFromJson(
  Map<String, dynamic> json,
) => RegisterPharmacyRequest(
  name: json['name'] as String,
  addressLine: json['addressLine'] as String,
  city: json['city'] as String,
  phone: json['phone'] as String,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  licenseDocUrl: json['licenseDocUrl'] as String?,
  nationalIdDocUrl: json['nationalIdDocUrl'] as String?,
);

Map<String, dynamic> _$RegisterPharmacyRequestToJson(
  RegisterPharmacyRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'addressLine': instance.addressLine,
  'city': instance.city,
  'phone': instance.phone,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'licenseDocUrl': instance.licenseDocUrl,
  'nationalIdDocUrl': instance.nationalIdDocUrl,
};
