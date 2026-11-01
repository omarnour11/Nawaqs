// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_response_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadResultDto _$UploadResultDtoFromJson(Map<String, dynamic> json) =>
    UploadResultDto(url: json['url'] as String);

Map<String, dynamic> _$UploadResultDtoToJson(UploadResultDto instance) =>
    <String, dynamic>{'url': instance.url};

ToggleFavoriteResponse _$ToggleFavoriteResponseFromJson(
  Map<String, dynamic> json,
) => ToggleFavoriteResponse(isFavorite: json['isFavorite'] as bool);

Map<String, dynamic> _$ToggleFavoriteResponseToJson(
  ToggleFavoriteResponse instance,
) => <String, dynamic>{'isFavorite': instance.isFavorite};

UnreadCountResponse _$UnreadCountResponseFromJson(Map<String, dynamic> json) =>
    UnreadCountResponse(count: (json['count'] as num).toInt());

Map<String, dynamic> _$UnreadCountResponseToJson(
  UnreadCountResponse instance,
) => <String, dynamic>{'count': instance.count};

MarkReadResponse _$MarkReadResponseFromJson(Map<String, dynamic> json) =>
    MarkReadResponse(updated: (json['updated'] as num).toInt());

Map<String, dynamic> _$MarkReadResponseToJson(MarkReadResponse instance) =>
    <String, dynamic>{'updated': instance.updated};

ClaimShortageResponse _$ClaimShortageResponseFromJson(
  Map<String, dynamic> json,
) => ClaimShortageResponse(reservationId: json['reservationId'] as String);

Map<String, dynamic> _$ClaimShortageResponseToJson(
  ClaimShortageResponse instance,
) => <String, dynamic>{'reservationId': instance.reservationId};

ParsedMedicationResponse _$ParsedMedicationResponseFromJson(
  Map<String, dynamic> json,
) => ParsedMedicationResponse(
  resolvedName: json['resolvedName'] as String,
  strength: json['strength'] as String?,
  dosageForm: json['dosageForm'] as String?,
  confidence: (json['confidence'] as num).toDouble(),
  requiresDisambiguation: json['requiresDisambiguation'] as bool,
  candidates: (json['candidates'] as List<dynamic>)
      .map((e) => ParsedCandidate.fromJson(e as Map<String, dynamic>))
      .toList(),
  activeIngredient: json['activeIngredient'] as String?,
  isSuccess: json['isSuccess'] as bool? ?? true,
  errorCode: json['errorCode'] as String?,
  errorMessage: json['errorMessage'] as String?,
);

Map<String, dynamic> _$ParsedMedicationResponseToJson(
  ParsedMedicationResponse instance,
) => <String, dynamic>{
  'resolvedName': instance.resolvedName,
  'strength': instance.strength,
  'dosageForm': instance.dosageForm,
  'confidence': instance.confidence,
  'requiresDisambiguation': instance.requiresDisambiguation,
  'candidates': instance.candidates,
  'activeIngredient': instance.activeIngredient,
  'isSuccess': instance.isSuccess,
  'errorCode': instance.errorCode,
  'errorMessage': instance.errorMessage,
};
