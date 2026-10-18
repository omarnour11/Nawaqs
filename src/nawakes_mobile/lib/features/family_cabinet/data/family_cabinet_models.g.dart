// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_cabinet_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FamilyCabinetResponseModel _$FamilyCabinetResponseModelFromJson(
  Map<String, dynamic> json,
) => FamilyCabinetResponseModel(
  profiles: (json['profiles'] as List<dynamic>)
      .map((e) => FamilyCabinetProfileModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

FamilyCabinetProfileModel _$FamilyCabinetProfileModelFromJson(
  Map<String, dynamic> json,
) => FamilyCabinetProfileModel(
  id: json['id'] as String,
  nickname: json['nickname'] as String,
  homeLatitude: (json['homeLatitude'] as num).toDouble(),
  homeLongitude: (json['homeLongitude'] as num).toDouble(),
  medications: (json['medications'] as List<dynamic>)
      .map((e) => FamilyMedicationModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

FamilyMedicationModel _$FamilyMedicationModelFromJson(
  Map<String, dynamic> json,
) => FamilyMedicationModel(
  id: json['id'] as String,
  medicationName: json['medicationName'] as String,
  strength: json['strength'] as String?,
  stripsCount: (json['stripsCount'] as num).toInt(),
  unitsPerStrip: (json['unitsPerStrip'] as num).toInt(),
  dailyDoseUnits: json['dailyDoseUnits'] as num,
  daysRemaining: (json['daysRemaining'] as num).toInt(),
  alertThresholdDays: (json['alertThresholdDays'] as num).toInt(),
  lastRefillDate: json['lastRefillDate'] == null
      ? null
      : DateTime.parse(json['lastRefillDate'] as String),
);

CreateFamilyProfileRequest _$CreateFamilyProfileRequestFromJson(
  Map<String, dynamic> json,
) => CreateFamilyProfileRequest(
  nickname: json['nickname'] as String,
  homeLatitude: (json['homeLatitude'] as num).toDouble(),
  homeLongitude: (json['homeLongitude'] as num).toDouble(),
);

Map<String, dynamic> _$CreateFamilyProfileRequestToJson(
  CreateFamilyProfileRequest instance,
) => <String, dynamic>{
  'nickname': instance.nickname,
  'homeLatitude': instance.homeLatitude,
  'homeLongitude': instance.homeLongitude,
};

FamilyMedicationRequest _$FamilyMedicationRequestFromJson(
  Map<String, dynamic> json,
) => FamilyMedicationRequest(
  medicationName: json['medicationName'] as String,
  strength: json['strength'] as String?,
  stripsCount: (json['stripsCount'] as num).toInt(),
  unitsPerStrip: (json['unitsPerStrip'] as num).toInt(),
  dailyDoseUnits: json['dailyDoseUnits'] as num,
  alertThresholdDays: (json['alertThresholdDays'] as num).toInt(),
);

Map<String, dynamic> _$FamilyMedicationRequestToJson(
  FamilyMedicationRequest instance,
) => <String, dynamic>{
  'medicationName': instance.medicationName,
  'strength': instance.strength,
  'stripsCount': instance.stripsCount,
  'unitsPerStrip': instance.unitsPerStrip,
  'dailyDoseUnits': instance.dailyDoseUnits,
  'alertThresholdDays': instance.alertThresholdDays,
};

RefillFamilyMedicationRequest _$RefillFamilyMedicationRequestFromJson(
  Map<String, dynamic> json,
) => RefillFamilyMedicationRequest(
  stripsAdded: (json['stripsAdded'] as num).toInt(),
);

Map<String, dynamic> _$RefillFamilyMedicationRequestToJson(
  RefillFamilyMedicationRequest instance,
) => <String, dynamic>{'stripsAdded': instance.stripsAdded};

InviteCaregiverRequest _$InviteCaregiverRequestFromJson(
  Map<String, dynamic> json,
) => InviteCaregiverRequest(
  invitedPhoneNumber: json['invitedPhoneNumber'] as String?,
);

Map<String, dynamic> _$InviteCaregiverRequestToJson(
  InviteCaregiverRequest instance,
) => <String, dynamic>{'invitedPhoneNumber': instance.invitedPhoneNumber};

PendingCaregiverInviteModel _$PendingCaregiverInviteModelFromJson(
  Map<String, dynamic> json,
) => PendingCaregiverInviteModel(
  linkId: json['linkId'] as String,
  familyProfileId: json['familyProfileId'] as String,
  familyProfileNickname: json['familyProfileNickname'] as String,
  invitedAt: DateTime.parse(json['invitedAt'] as String),
);

AcceptCaregiverInviteResponse _$AcceptCaregiverInviteResponseFromJson(
  Map<String, dynamic> json,
) => AcceptCaregiverInviteResponse(
  familyProfileId: json['familyProfileId'] as String,
);
