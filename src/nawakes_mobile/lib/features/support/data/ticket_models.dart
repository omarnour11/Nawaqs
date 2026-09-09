import 'package:freezed_annotation/freezed_annotation.dart';

part 'ticket_models.g.dart';

enum TicketCategory {
  @JsonValue(0)
  reservationIssue,
  @JsonValue(1)
  inaccurateStock,
  @JsonValue(2)
  pharmacyConduct,
  @JsonValue(3)
  accountIssue,
  @JsonValue(4)
  other,
}

@JsonSerializable()
class CreateTicketRequest {
  final String subject;
  final String description;
  final TicketCategory category;

  CreateTicketRequest({
    required this.subject,
    required this.description,
    this.category = TicketCategory.other,
  });

  factory CreateTicketRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateTicketRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateTicketRequestToJson(this);
}

@JsonSerializable()
class TicketDto {
  final String id;
  final String subject;
  final String description;
  final String category;
  final String status;
  final String? resolution;
  final String? reservationId;
  final String? pharmacyId;
  final DateTime createdAt;

  TicketDto({
    required this.id,
    required this.subject,
    required this.description,
    required this.category,
    required this.status,
    this.resolution,
    this.reservationId,
    this.pharmacyId,
    required this.createdAt,
  });

  factory TicketDto.fromJson(Map<String, dynamic> json) => _$TicketDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TicketDtoToJson(this);
}

@JsonSerializable()
class ResolveTicketRequest {
  final bool startProgress;
  final String? resolution;

  ResolveTicketRequest({required this.startProgress, this.resolution});

  factory ResolveTicketRequest.fromJson(Map<String, dynamic> json) =>
      _$ResolveTicketRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ResolveTicketRequestToJson(this);
}

@JsonSerializable()
class AdminTicketDto {
  final String id;
  final String userId;
  final String reporterEmail;
  final String subject;
  final String description;
  final String category;
  final String status;
  final String? resolution;
  final String? reservationId;
  final String? pharmacyId;
  final DateTime createdAt;

  AdminTicketDto({
    required this.id,
    required this.userId,
    required this.reporterEmail,
    required this.subject,
    required this.description,
    required this.category,
    required this.status,
    this.resolution,
    this.reservationId,
    this.pharmacyId,
    required this.createdAt,
  });

  factory AdminTicketDto.fromJson(Map<String, dynamic> json) =>
      _$AdminTicketDtoFromJson(json);
  Map<String, dynamic> toJson() => _$AdminTicketDtoToJson(this);
}
