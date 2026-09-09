// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatientMedicationDto _$PatientMedicationDtoFromJson(
  Map<String, dynamic> json,
) => PatientMedicationDto(
  id: json['id'] as String,
  medicationName: json['medicationName'] as String,
  strength: json['strength'] as String?,
  form: json['form'] as String?,
  doseSchedule: json['doseSchedule'] as String?,
  unitsPerDay: (json['unitsPerDay'] as num?)?.toDouble(),
  isActive: json['isActive'] as bool,
  notes: json['notes'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$PatientMedicationDtoToJson(
  PatientMedicationDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'medicationName': instance.medicationName,
  'strength': instance.strength,
  'form': instance.form,
  'doseSchedule': instance.doseSchedule,
  'unitsPerDay': instance.unitsPerDay,
  'isActive': instance.isActive,
  'notes': instance.notes,
  'createdAt': instance.createdAt.toIso8601String(),
};

MedicationRequest _$MedicationRequestFromJson(Map<String, dynamic> json) =>
    MedicationRequest(
      medicationName: json['medicationName'] as String,
      strength: json['strength'] as String?,
      form: json['form'] as String?,
      doseSchedule: json['doseSchedule'] as String?,
      unitsPerDay: (json['unitsPerDay'] as num?)?.toDouble(),
      isActive: json['isActive'] as bool? ?? true,
      notes: json['notes'] as String?,
      id: json['id'] as String?,
    );

Map<String, dynamic> _$MedicationRequestToJson(MedicationRequest instance) =>
    <String, dynamic>{
      'medicationName': instance.medicationName,
      'strength': instance.strength,
      'form': instance.form,
      'doseSchedule': instance.doseSchedule,
      'unitsPerDay': instance.unitsPerDay,
      'isActive': instance.isActive,
      'notes': instance.notes,
      'id': instance.id,
    };

CreateShortageRequest _$CreateShortageRequestFromJson(
  Map<String, dynamic> json,
) => CreateShortageRequest(
  medicationName: json['medicationName'] as String,
  strength: json['strength'] as String?,
  quantityNeeded: (json['quantityNeeded'] as num?)?.toInt() ?? 1,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$CreateShortageRequestToJson(
  CreateShortageRequest instance,
) => <String, dynamic>{
  'medicationName': instance.medicationName,
  'strength': instance.strength,
  'quantityNeeded': instance.quantityNeeded,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'notes': instance.notes,
};

ShortageRequestDto _$ShortageRequestDtoFromJson(Map<String, dynamic> json) =>
    ShortageRequestDto(
      id: json['id'] as String,
      medicationName: json['medicationName'] as String,
      strength: json['strength'] as String?,
      quantityNeeded: (json['quantityNeeded'] as num).toInt(),
      notes: json['notes'] as String?,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$ShortageRequestDtoToJson(ShortageRequestDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'medicationName': instance.medicationName,
      'strength': instance.strength,
      'quantityNeeded': instance.quantityNeeded,
      'notes': instance.notes,
      'distanceKm': instance.distanceKm,
      'createdAt': instance.createdAt.toIso8601String(),
      'expiresAt': instance.expiresAt.toIso8601String(),
    };

ForgotPasswordRequest _$ForgotPasswordRequestFromJson(
  Map<String, dynamic> json,
) => ForgotPasswordRequest(email: json['email'] as String);

Map<String, dynamic> _$ForgotPasswordRequestToJson(
  ForgotPasswordRequest instance,
) => <String, dynamic>{'email': instance.email};

ResetPasswordRequest _$ResetPasswordRequestFromJson(
  Map<String, dynamic> json,
) => ResetPasswordRequest(
  email: json['email'] as String,
  resetToken: json['resetToken'] as String,
  newPassword: json['newPassword'] as String,
);

Map<String, dynamic> _$ResetPasswordRequestToJson(
  ResetPasswordRequest instance,
) => <String, dynamic>{
  'email': instance.email,
  'resetToken': instance.resetToken,
  'newPassword': instance.newPassword,
};

ForgotPasswordResponse _$ForgotPasswordResponseFromJson(
  Map<String, dynamic> json,
) => ForgotPasswordResponse(
  sent: json['sent'] as bool,
  resetToken: json['resetToken'] as String?,
);

Map<String, dynamic> _$ForgotPasswordResponseToJson(
  ForgotPasswordResponse instance,
) => <String, dynamic>{
  'sent': instance.sent,
  'resetToken': instance.resetToken,
};
