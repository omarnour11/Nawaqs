import 'package:freezed_annotation/freezed_annotation.dart';

part 'favorite_models.g.dart';

@JsonSerializable()
class FavoritePharmacyDto {
  final String pharmacyId;
  final String name;
  final String addressLine;
  final String city;
  final String phone;
  final double latitude;
  final double longitude;
  final double trustScore;
  final double averageRating;
  final int ratingCount;

  FavoritePharmacyDto({
    required this.pharmacyId,
    required this.name,
    required this.addressLine,
    required this.city,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.trustScore,
    required this.averageRating,
    required this.ratingCount,
  });

  factory FavoritePharmacyDto.fromJson(Map<String, dynamic> json) =>
      _$FavoritePharmacyDtoFromJson(json);
  Map<String, dynamic> toJson() => _$FavoritePharmacyDtoToJson(this);
}
