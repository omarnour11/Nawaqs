import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_models.g.dart';

@JsonSerializable()
class PharmacySearchResultDto {
  final String pharmacyId;
  final String pharmacyName;
  final String addressLine;
  final String phone;
  final double trustScore;
  final double distanceKm;
  final String inventoryItemId;
  final String medicationName;
  final double price;
  final String status;
  final int quantity;
  final String? patientNote;
  final DateTime lastUpdatedAt;
  final double latitude;
  final double longitude;

  PharmacySearchResultDto({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.addressLine,
    required this.phone,
    required this.trustScore,
    required this.distanceKm,
    required this.inventoryItemId,
    required this.medicationName,
    required this.price,
    required this.status,
    required this.quantity,
    this.patientNote,
    required this.lastUpdatedAt,
    required this.latitude,
    required this.longitude,
  });

  factory PharmacySearchResultDto.fromJson(Map<String, dynamic> json) => _$PharmacySearchResultDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PharmacySearchResultDtoToJson(this);
}

@JsonSerializable()
class SearchMedicationResponse {
  final List<PharmacySearchResultDto> results;
  final int totalCount;
  final bool cacheHit;
  final double radiusKm;

  SearchMedicationResponse({
    required this.results,
    required this.totalCount,
    required this.cacheHit,
    required this.radiusKm,
  });

  factory SearchMedicationResponse.fromJson(Map<String, dynamic> json) => _$SearchMedicationResponseFromJson(json);
  Map<String, dynamic> toJson() => _$SearchMedicationResponseToJson(this);
}

@JsonSerializable()
class EquivalentPharmacyResultDto {
  final String equivalentTradeName;
  final String? manufacturer;
  final double officialPriceEGP;
  final double priceSavingPercent;
  final String pharmacyId;
  final String pharmacyName;
  final double distanceKm;
  final String inventoryItemId;
  final double priceAtPharmacy;

  EquivalentPharmacyResultDto({
    required this.equivalentTradeName,
    this.manufacturer,
    required this.officialPriceEGP,
    required this.priceSavingPercent,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.distanceKm,
    required this.inventoryItemId,
    required this.priceAtPharmacy,
  });

  factory EquivalentPharmacyResultDto.fromJson(Map<String, dynamic> json) =>
      _$EquivalentPharmacyResultDtoFromJson(json);
  Map<String, dynamic> toJson() => _$EquivalentPharmacyResultDtoToJson(this);
}

@JsonSerializable()
class OriginalMedicationInfoDto {
  final String tradeName;
  final String? activeIngredient;
  final String? strength;
  final String? dosageForm;
  final double? officialPriceEGP;
  final bool isAvailableNearby;

  OriginalMedicationInfoDto({
    required this.tradeName,
    this.activeIngredient,
    this.strength,
    this.dosageForm,
    this.officialPriceEGP,
    required this.isAvailableNearby,
  });

  factory OriginalMedicationInfoDto.fromJson(Map<String, dynamic> json) =>
      _$OriginalMedicationInfoDtoFromJson(json);
  Map<String, dynamic> toJson() => _$OriginalMedicationInfoDtoToJson(this);
}

@JsonSerializable()
class MedicationEquivalentsResponse {
  final OriginalMedicationInfoDto? original;
  final List<EquivalentPharmacyResultDto> availableEquivalents;
  final String legalDisclaimer;

  MedicationEquivalentsResponse({
    this.original,
    required this.availableEquivalents,
    required this.legalDisclaimer,
  });

  factory MedicationEquivalentsResponse.fromJson(Map<String, dynamic> json) =>
      _$MedicationEquivalentsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationEquivalentsResponseToJson(this);
}
