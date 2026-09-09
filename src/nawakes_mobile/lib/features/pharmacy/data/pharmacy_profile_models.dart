import 'package:freezed_annotation/freezed_annotation.dart';

part 'pharmacy_profile_models.g.dart';

@JsonSerializable()
class MyPharmacyDto {
  final String id;
  final String name;
  final String addressLine;
  final String city;
  final String phone;
  final double latitude;
  final double longitude;
  final String verificationStatus;
  final String? rejectionReason;
  final String? licenseDocUrl;
  final String? nationalIdDocUrl;
  final double trustScore;
  final double averageRating;
  final int ratingCount;
  final DateTime createdAt;

  MyPharmacyDto({
    required this.id,
    required this.name,
    required this.addressLine,
    required this.city,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.verificationStatus,
    this.rejectionReason,
    this.licenseDocUrl,
    this.nationalIdDocUrl,
    required this.trustScore,
    required this.averageRating,
    required this.ratingCount,
    required this.createdAt,
  });

  factory MyPharmacyDto.fromJson(Map<String, dynamic> json) => _$MyPharmacyDtoFromJson(json);
  Map<String, dynamic> toJson() => _$MyPharmacyDtoToJson(this);
}

@JsonSerializable()
class RegisterPharmacyRequest {
  final String name;
  final String addressLine;
  final String city;
  final String phone;
  final double latitude;
  final double longitude;
  final String? licenseDocUrl;
  final String? nationalIdDocUrl;

  RegisterPharmacyRequest({
    required this.name,
    required this.addressLine,
    required this.city,
    required this.phone,
    required this.latitude,
    required this.longitude,
    this.licenseDocUrl,
    this.nationalIdDocUrl,
  });

  factory RegisterPharmacyRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterPharmacyRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterPharmacyRequestToJson(this);
}
