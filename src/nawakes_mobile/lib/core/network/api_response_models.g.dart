// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_response_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ToggleFavoriteResponse _$ToggleFavoriteResponseFromJson(
  Map<String, dynamic> json,
) => ToggleFavoriteResponse(isFavorite: json['isFavorite'] as bool);

Map<String, dynamic> _$ToggleFavoriteResponseToJson(
  ToggleFavoriteResponse instance,
) => <String, dynamic>{'isFavorite': instance.isFavorite};

IdResponse _$IdResponseFromJson(Map<String, dynamic> json) =>
    IdResponse(id: json['id'] as String);

Map<String, dynamic> _$IdResponseToJson(IdResponse instance) =>
    <String, dynamic>{'id': instance.id};

UnreadCountResponse _$UnreadCountResponseFromJson(Map<String, dynamic> json) =>
    UnreadCountResponse(count: (json['count'] as num).toInt());

Map<String, dynamic> _$UnreadCountResponseToJson(
  UnreadCountResponse instance,
) => <String, dynamic>{'count': instance.count};

MarkReadResponse _$MarkReadResponseFromJson(Map<String, dynamic> json) =>
    MarkReadResponse(updated: (json['updated'] as num).toInt());

Map<String, dynamic> _$MarkReadResponseToJson(MarkReadResponse instance) =>
    <String, dynamic>{'updated': instance.updated};

SetAvailabilityRequest _$SetAvailabilityRequestFromJson(
  Map<String, dynamic> json,
) => SetAvailabilityRequest(
  quantity: (json['quantity'] as num).toInt(),
  price: (json['price'] as num?)?.toDouble(),
  patientNote: json['patientNote'] as String?,
);

Map<String, dynamic> _$SetAvailabilityRequestToJson(
  SetAvailabilityRequest instance,
) => <String, dynamic>{
  'quantity': instance.quantity,
  'price': instance.price,
  'patientNote': instance.patientNote,
};

ClaimShortageResponse _$ClaimShortageResponseFromJson(
  Map<String, dynamic> json,
) => ClaimShortageResponse(reservationId: json['reservationId'] as String);

Map<String, dynamic> _$ClaimShortageResponseToJson(
  ClaimShortageResponse instance,
) => <String, dynamic>{'reservationId': instance.reservationId};

ParseMultimodalBody _$ParseMultimodalBodyFromJson(Map<String, dynamic> json) =>
    ParseMultimodalBody(
      rawText: json['rawText'] as String,
      inputType: json['inputType'] as String?,
    );

Map<String, dynamic> _$ParseMultimodalBodyToJson(
  ParseMultimodalBody instance,
) => <String, dynamic>{
  'rawText': instance.rawText,
  'inputType': instance.inputType,
};

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
};

ParsedCandidate _$ParsedCandidateFromJson(Map<String, dynamic> json) =>
    ParsedCandidate(
      tradeName: json['tradeName'] as String,
      strength: json['strength'] as String?,
      dosageForm: json['dosageForm'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
    );

Map<String, dynamic> _$ParsedCandidateToJson(ParsedCandidate instance) =>
    <String, dynamic>{
      'tradeName': instance.tradeName,
      'strength': instance.strength,
      'dosageForm': instance.dosageForm,
      'confidence': instance.confidence,
    };
