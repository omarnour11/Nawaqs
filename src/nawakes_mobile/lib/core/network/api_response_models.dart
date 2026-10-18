import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_response_models.g.dart';

@JsonSerializable()
class ToggleFavoriteResponse {
  final bool isFavorite;

  ToggleFavoriteResponse({required this.isFavorite});

  factory ToggleFavoriteResponse.fromJson(Map<String, dynamic> json) =>
      _$ToggleFavoriteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ToggleFavoriteResponseToJson(this);
}

@JsonSerializable()
class IdResponse {
  final String id;

  IdResponse({required this.id});

  factory IdResponse.fromJson(Map<String, dynamic> json) => _$IdResponseFromJson(json);
  Map<String, dynamic> toJson() => _$IdResponseToJson(this);
}

@JsonSerializable()
class UnreadCountResponse {
  final int count;

  UnreadCountResponse({required this.count});

  factory UnreadCountResponse.fromJson(Map<String, dynamic> json) =>
      _$UnreadCountResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UnreadCountResponseToJson(this);
}

@JsonSerializable()
class MarkReadResponse {
  final int updated;

  MarkReadResponse({required this.updated});

  factory MarkReadResponse.fromJson(Map<String, dynamic> json) =>
      _$MarkReadResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MarkReadResponseToJson(this);
}

@JsonSerializable()
class SetAvailabilityRequest {
  final int quantity;
  final double? price;
  final String? patientNote;

  SetAvailabilityRequest({required this.quantity, this.price, this.patientNote});

  factory SetAvailabilityRequest.fromJson(Map<String, dynamic> json) =>
      _$SetAvailabilityRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SetAvailabilityRequestToJson(this);
}

@JsonSerializable()
class ClaimShortageResponse {
  final String reservationId;

  ClaimShortageResponse({required this.reservationId});

  factory ClaimShortageResponse.fromJson(Map<String, dynamic> json) =>
      _$ClaimShortageResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ClaimShortageResponseToJson(this);
}

@JsonSerializable()
class ParseMultimodalBody {
  final String rawText;
  final String? inputType;

  ParseMultimodalBody({required this.rawText, this.inputType});

  factory ParseMultimodalBody.fromJson(Map<String, dynamic> json) =>
      _$ParseMultimodalBodyFromJson(json);
  Map<String, dynamic> toJson() => _$ParseMultimodalBodyToJson(this);
}

@JsonSerializable()
class ParsedMedicationResponse {
  final String resolvedName;
  final String? strength;
  final String? dosageForm;
  final double confidence;
  final bool requiresDisambiguation;
  final List<ParsedCandidate> candidates;

  ParsedMedicationResponse({
    required this.resolvedName,
    this.strength,
    this.dosageForm,
    required this.confidence,
    required this.requiresDisambiguation,
    required this.candidates,
  });

  factory ParsedMedicationResponse.fromJson(Map<String, dynamic> json) =>
      _$ParsedMedicationResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ParsedMedicationResponseToJson(this);
}

@JsonSerializable()
class ParsedCandidate {
  final String tradeName;
  final String? strength;
  final String? dosageForm;
  final double confidence;

  ParsedCandidate({
    required this.tradeName,
    this.strength,
    this.dosageForm,
    required this.confidence,
  });

  factory ParsedCandidate.fromJson(Map<String, dynamic> json) =>
      _$ParsedCandidateFromJson(json);
  Map<String, dynamic> toJson() => _$ParsedCandidateToJson(this);
}
