import 'package:freezed_annotation/freezed_annotation.dart';

part 'medication_models.g.dart';

@JsonSerializable()
class PatientMedicationDto {
  final String id;
  final String medicationName;
  final String? strength;
  final String? form;
  final String? doseSchedule;
  final double? unitsPerDay;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;

  PatientMedicationDto({
    required this.id,
    required this.medicationName,
    this.strength,
    this.form,
    this.doseSchedule,
    this.unitsPerDay,
    required this.isActive,
    this.notes,
    required this.createdAt,
  });

  factory PatientMedicationDto.fromJson(Map<String, dynamic> json) =>
      _$PatientMedicationDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PatientMedicationDtoToJson(this);
}

@JsonSerializable()
class MedicationRequest {
  final String medicationName;
  final String? strength;
  final String? form;
  final String? doseSchedule;
  final double? unitsPerDay;
  final bool isActive;
  final String? notes;
  final String? id;

  MedicationRequest({
    required this.medicationName,
    this.strength,
    this.form,
    this.doseSchedule,
    this.unitsPerDay,
    this.isActive = true,
    this.notes,
    this.id,
  });

  factory MedicationRequest.fromJson(Map<String, dynamic> json) =>
      _$MedicationRequestFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationRequestToJson(this);
}

@JsonSerializable()
class CreateShortageRequest {
  final String medicationName;
  final String? strength;
  final int quantityNeeded;
  final double latitude;
  final double longitude;
  final String? notes;

  CreateShortageRequest({
    required this.medicationName,
    this.strength,
    this.quantityNeeded = 1,
    required this.latitude,
    required this.longitude,
    this.notes,
  });

  factory CreateShortageRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateShortageRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateShortageRequestToJson(this);
}

@JsonSerializable()
class ShortageRequestDto {
  final String id;
  final String medicationName;
  final String? strength;
  final int quantityNeeded;
  final String? notes;
  final double distanceKm;
  final DateTime createdAt;
  final DateTime expiresAt;

  ShortageRequestDto({
    required this.id,
    required this.medicationName,
    this.strength,
    required this.quantityNeeded,
    this.notes,
    required this.distanceKm,
    required this.createdAt,
    required this.expiresAt,
  });

  factory ShortageRequestDto.fromJson(Map<String, dynamic> json) =>
      _$ShortageRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ShortageRequestDtoToJson(this);
}

@JsonSerializable()
class ForgotPasswordRequest {
  final String email;

  ForgotPasswordRequest({required this.email});

  factory ForgotPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ForgotPasswordRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ForgotPasswordRequestToJson(this);
}

@JsonSerializable()
class ResetPasswordRequest {
  final String email;
  final String resetToken;
  final String newPassword;

  ResetPasswordRequest({
    required this.email,
    required this.resetToken,
    required this.newPassword,
  });

  factory ResetPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ResetPasswordRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ResetPasswordRequestToJson(this);
}

@JsonSerializable()
class ForgotPasswordResponse {
  final bool sent;
  final String? resetToken;

  ForgotPasswordResponse({required this.sent, this.resetToken});

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) =>
      _$ForgotPasswordResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ForgotPasswordResponseToJson(this);
}
