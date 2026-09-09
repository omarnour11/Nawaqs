// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FavoritePharmacyDto _$FavoritePharmacyDtoFromJson(Map<String, dynamic> json) =>
    FavoritePharmacyDto(
      pharmacyId: json['pharmacyId'] as String,
      name: json['name'] as String,
      addressLine: json['addressLine'] as String,
      city: json['city'] as String,
      phone: json['phone'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      trustScore: (json['trustScore'] as num).toDouble(),
      averageRating: (json['averageRating'] as num).toDouble(),
      ratingCount: (json['ratingCount'] as num).toInt(),
    );

Map<String, dynamic> _$FavoritePharmacyDtoToJson(
  FavoritePharmacyDto instance,
) => <String, dynamic>{
  'pharmacyId': instance.pharmacyId,
  'name': instance.name,
  'addressLine': instance.addressLine,
  'city': instance.city,
  'phone': instance.phone,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'trustScore': instance.trustScore,
  'averageRating': instance.averageRating,
  'ratingCount': instance.ratingCount,
};
