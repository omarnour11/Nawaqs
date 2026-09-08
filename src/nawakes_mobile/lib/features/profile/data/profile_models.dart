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

  ProfileResponse({
    required this.userId,
    required this.email,
    this.fullName,
    this.phone,
    this.medicalHistoryNotes,
    required this.createdAt,
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

  UpdateProfileRequest({this.fullName, this.phone, this.medicalHistoryNotes});

  factory UpdateProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateProfileRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateProfileRequestToJson(this);
}
