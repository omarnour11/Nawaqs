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
  quantity: (json['quantity'] as num).toInt(),
  patientNote: json['patientNote'] as String?,
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
  'quantity': instance.quantity,
  'patientNote': instance.patientNote,
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

EquivalentPharmacyResultDto _$EquivalentPharmacyResultDtoFromJson(
  Map<String, dynamic> json,
) => EquivalentPharmacyResultDto(
  equivalentTradeName: json['equivalentTradeName'] as String,
  manufacturer: json['manufacturer'] as String?,
  officialPriceEGP: (json['officialPriceEGP'] as num).toDouble(),
  priceSavingPercent: (json['priceSavingPercent'] as num).toDouble(),
  pharmacyId: json['pharmacyId'] as String,
  pharmacyName: json['pharmacyName'] as String,
  distanceKm: (json['distanceKm'] as num).toDouble(),
  inventoryItemId: json['inventoryItemId'] as String,
  priceAtPharmacy: (json['priceAtPharmacy'] as num).toDouble(),
);

Map<String, dynamic> _$EquivalentPharmacyResultDtoToJson(
  EquivalentPharmacyResultDto instance,
) => <String, dynamic>{
  'equivalentTradeName': instance.equivalentTradeName,
  'manufacturer': instance.manufacturer,
  'officialPriceEGP': instance.officialPriceEGP,
  'priceSavingPercent': instance.priceSavingPercent,
  'pharmacyId': instance.pharmacyId,
  'pharmacyName': instance.pharmacyName,
  'distanceKm': instance.distanceKm,
  'inventoryItemId': instance.inventoryItemId,
  'priceAtPharmacy': instance.priceAtPharmacy,
};

OriginalMedicationInfoDto _$OriginalMedicationInfoDtoFromJson(
  Map<String, dynamic> json,
) => OriginalMedicationInfoDto(
  tradeName: json['tradeName'] as String,
  activeIngredient: json['activeIngredient'] as String?,
  strength: json['strength'] as String?,
  dosageForm: json['dosageForm'] as String?,
  officialPriceEGP: (json['officialPriceEGP'] as num?)?.toDouble(),
  isAvailableNearby: json['isAvailableNearby'] as bool,
);

Map<String, dynamic> _$OriginalMedicationInfoDtoToJson(
  OriginalMedicationInfoDto instance,
) => <String, dynamic>{
  'tradeName': instance.tradeName,
  'activeIngredient': instance.activeIngredient,
  'strength': instance.strength,
  'dosageForm': instance.dosageForm,
  'officialPriceEGP': instance.officialPriceEGP,
  'isAvailableNearby': instance.isAvailableNearby,
};

MedicationEquivalentsResponse _$MedicationEquivalentsResponseFromJson(
  Map<String, dynamic> json,
) => MedicationEquivalentsResponse(
  original: json['original'] == null
      ? null
      : OriginalMedicationInfoDto.fromJson(
          json['original'] as Map<String, dynamic>,
        ),
  availableEquivalents: (json['availableEquivalents'] as List<dynamic>)
      .map(
        (e) => EquivalentPharmacyResultDto.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  legalDisclaimer: json['legalDisclaimer'] as String,
);

Map<String, dynamic> _$MedicationEquivalentsResponseToJson(
  MedicationEquivalentsResponse instance,
) => <String, dynamic>{
  'original': instance.original,
  'availableEquivalents': instance.availableEquivalents,
  'legalDisclaimer': instance.legalDisclaimer,
};
