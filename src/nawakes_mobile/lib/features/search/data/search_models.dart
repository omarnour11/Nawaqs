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
