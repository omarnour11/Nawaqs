import 'package:json_annotation/json_annotation.dart';

part 'family_cabinet_models.g.dart';

@JsonSerializable()
class FamilyCabinetResponseModel {
  FamilyCabinetResponseModel({required this.profiles});

  factory FamilyCabinetResponseModel.fromJson(Map<String, dynamic> json) =>
      _$FamilyCabinetResponseModelFromJson(json);

  final List<FamilyCabinetProfileModel> profiles;
}

@JsonSerializable()
class FamilyCabinetProfileModel {
  FamilyCabinetProfileModel({
    required this.id,
    required this.nickname,
    required this.homeLatitude,
    required this.homeLongitude,
    required this.medications,
  });

  factory FamilyCabinetProfileModel.fromJson(Map<String, dynamic> json) =>
      _$FamilyCabinetProfileModelFromJson(json);

  final String id;
  final String nickname;
  final double homeLatitude;
  final double homeLongitude;
  final List<FamilyMedicationModel> medications;
}

@JsonSerializable()
class FamilyMedicationModel {
  FamilyMedicationModel({
    required this.id,
    required this.medicationName,
    this.strength,
    required this.stripsCount,
    required this.unitsPerStrip,
    required this.dailyDoseUnits,
    required this.daysRemaining,
    required this.alertThresholdDays,
    this.lastRefillDate,
  });

  factory FamilyMedicationModel.fromJson(Map<String, dynamic> json) =>
      _$FamilyMedicationModelFromJson(json);

  final String id;
  final String medicationName;
  final String? strength;
  final int stripsCount;
  final int unitsPerStrip;
  final num dailyDoseUnits;
  final int daysRemaining;
  final int alertThresholdDays;
  final DateTime? lastRefillDate;
}

@JsonSerializable()
class CreateFamilyProfileRequest {
  CreateFamilyProfileRequest({
    required this.nickname,
    required this.homeLatitude,
    required this.homeLongitude,
  });

  factory CreateFamilyProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateFamilyProfileRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateFamilyProfileRequestToJson(this);

  final String nickname;
  final double homeLatitude;
  final double homeLongitude;
}

@JsonSerializable()
class FamilyMedicationRequest {
  FamilyMedicationRequest({
    required this.medicationName,
    this.strength,
    required this.stripsCount,
    required this.unitsPerStrip,
    required this.dailyDoseUnits,
    required this.alertThresholdDays,
  });

  factory FamilyMedicationRequest.fromJson(Map<String, dynamic> json) =>
      _$FamilyMedicationRequestFromJson(json);
  Map<String, dynamic> toJson() => _$FamilyMedicationRequestToJson(this);

  final String medicationName;
  final String? strength;
  final int stripsCount;
  final int unitsPerStrip;
  final num dailyDoseUnits;
  final int alertThresholdDays;
}

@JsonSerializable()
class RefillFamilyMedicationRequest {
  RefillFamilyMedicationRequest({required this.stripsAdded});

  factory RefillFamilyMedicationRequest.fromJson(Map<String, dynamic> json) =>
      _$RefillFamilyMedicationRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RefillFamilyMedicationRequestToJson(this);

  final int stripsAdded;
}

@JsonSerializable()
class InviteCaregiverRequest {
  InviteCaregiverRequest({this.invitedPhoneNumber});

  factory InviteCaregiverRequest.fromJson(Map<String, dynamic> json) =>
      _$InviteCaregiverRequestFromJson(json);
  Map<String, dynamic> toJson() => _$InviteCaregiverRequestToJson(this);

  final String? invitedPhoneNumber;
}
