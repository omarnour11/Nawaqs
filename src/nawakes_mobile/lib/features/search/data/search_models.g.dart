// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PharmacySearchResultDto _$PharmacySearchResultDtoFromJson(
  Map<String, dynamic> json,
) => PharmacySearchResultDto(
  pharmacyId: json['pharmacyId'] as String,
  pharmacyName: json['pharmacyName'] as String,
  addressLine: json['addressLine'] as String,
  phone: json['phone'] as String,
  trustScore: (json['trustScore'] as num).toDouble(),
  distanceKm: (json['distanceKm'] as num).toDouble(),
  inventoryItemId: json['inventoryItemId'] as String,
  medicationName: json['medicationName'] as String,
  price: (json['price'] as num).toDouble(),
  status: json['status'] as String,
  lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
);

Map<String, dynamic> _$PharmacySearchResultDtoToJson(
  PharmacySearchResultDto instance,
) => <String, dynamic>{
  'pharmacyId': instance.pharmacyId,
  'pharmacyName': instance.pharmacyName,
  'addressLine': instance.addressLine,
  'phone': instance.phone,
  'trustScore': instance.trustScore,
  'distanceKm': instance.distanceKm,
  'inventoryItemId': instance.inventoryItemId,
  'medicationName': instance.medicationName,
  'price': instance.price,
  'status': instance.status,
  'lastUpdatedAt': instance.lastUpdatedAt.toIso8601String(),
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};

SearchMedicationResponse _$SearchMedicationResponseFromJson(
  Map<String, dynamic> json,
) => SearchMedicationResponse(
  results: (json['results'] as List<dynamic>)
      .map((e) => PharmacySearchResultDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalCount: (json['totalCount'] as num).toInt(),
  cacheHit: json['cacheHit'] as bool,
  radiusKm: (json['radiusKm'] as num).toDouble(),
);

Map<String, dynamic> _$SearchMedicationResponseToJson(
  SearchMedicationResponse instance,
) => <String, dynamic>{
  'results': instance.results,
  'totalCount': instance.totalCount,
  'cacheHit': instance.cacheHit,
  'radiusKm': instance.radiusKm,
};
