import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_models.g.dart';

@JsonSerializable()
class ProfileResponse {
  final String userId;
  final String email;
  final String? fullName;
  final String? phone;
  final String? medicalHistoryNotes;
  final DateTime createdAt;
  final bool allowPharmacistViewActiveMedications;
  final String? gender;
  final int? age;
  final String? chronicConditions;
  final String? knownAllergies;

  ProfileResponse({
    required this.userId,
    required this.email,
    this.fullName,
    this.phone,
    this.medicalHistoryNotes,
    required this.createdAt,
    this.allowPharmacistViewActiveMedications = true,
    this.gender,
    this.age,
    this.chronicConditions,
    this.knownAllergies,
  });

  factory ProfileResponse.fromJson(Map<String, dynamic> json) =>
      _$ProfileResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileResponseToJson(this);
}

@JsonSerializable()
class UpdateProfileRequest {
  final String? fullName;
  final String? phone;
  final String? medicalHistoryNotes;
  final bool? allowPharmacistViewActiveMedications;
  final String? gender;
  final int? age;
  final String? chronicConditions;
  final String? knownAllergies;

  UpdateProfileRequest({
    this.fullName,
    this.phone,
    this.medicalHistoryNotes,
    this.allowPharmacistViewActiveMedications,
    this.gender,
    this.age,
    this.chronicConditions,
    this.knownAllergies,
  });

  factory UpdateProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateProfileRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateProfileRequestToJson(this);
}
