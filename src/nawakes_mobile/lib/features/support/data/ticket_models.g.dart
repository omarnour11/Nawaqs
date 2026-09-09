// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateTicketRequest _$CreateTicketRequestFromJson(Map<String, dynamic> json) =>
    CreateTicketRequest(
      subject: json['subject'] as String,
      description: json['description'] as String,
      category:
          $enumDecodeNullable(_$TicketCategoryEnumMap, json['category']) ??
          TicketCategory.other,
    );

Map<String, dynamic> _$CreateTicketRequestToJson(
  CreateTicketRequest instance,
) => <String, dynamic>{
  'subject': instance.subject,
  'description': instance.description,
  'category': _$TicketCategoryEnumMap[instance.category]!,
};

const _$TicketCategoryEnumMap = {
  TicketCategory.reservationIssue: 0,
  TicketCategory.inaccurateStock: 1,
  TicketCategory.pharmacyConduct: 2,
  TicketCategory.accountIssue: 3,
  TicketCategory.other: 4,
};

TicketDto _$TicketDtoFromJson(Map<String, dynamic> json) => TicketDto(
  id: json['id'] as String,
  subject: json['subject'] as String,
  description: json['description'] as String,
  category: json['category'] as String,
  status: json['status'] as String,
  resolution: json['resolution'] as String?,
  reservationId: json['reservationId'] as String?,
  pharmacyId: json['pharmacyId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$TicketDtoToJson(TicketDto instance) => <String, dynamic>{
  'id': instance.id,
  'subject': instance.subject,
  'description': instance.description,
  'category': instance.category,
  'status': instance.status,
  'resolution': instance.resolution,
  'reservationId': instance.reservationId,
  'pharmacyId': instance.pharmacyId,
  'createdAt': instance.createdAt.toIso8601String(),
};

ResolveTicketRequest _$ResolveTicketRequestFromJson(
  Map<String, dynamic> json,
) => ResolveTicketRequest(
  startProgress: json['startProgress'] as bool,
  resolution: json['resolution'] as String?,
);

Map<String, dynamic> _$ResolveTicketRequestToJson(
  ResolveTicketRequest instance,
) => <String, dynamic>{
  'startProgress': instance.startProgress,
  'resolution': instance.resolution,
};

AdminTicketDto _$AdminTicketDtoFromJson(Map<String, dynamic> json) =>
    AdminTicketDto(
      id: json['id'] as String,
      userId: json['userId'] as String,
      reporterEmail: json['reporterEmail'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      status: json['status'] as String,
      resolution: json['resolution'] as String?,
      reservationId: json['reservationId'] as String?,
      pharmacyId: json['pharmacyId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$AdminTicketDtoToJson(AdminTicketDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'reporterEmail': instance.reporterEmail,
      'subject': instance.subject,
      'description': instance.description,
      'category': instance.category,
      'status': instance.status,
      'resolution': instance.resolution,
      'reservationId': instance.reservationId,
      'pharmacyId': instance.pharmacyId,
      'createdAt': instance.createdAt.toIso8601String(),
    };
