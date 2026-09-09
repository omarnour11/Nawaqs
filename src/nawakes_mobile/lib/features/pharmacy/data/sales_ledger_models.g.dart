// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_ledger_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SalesLedgerEntryDto _$SalesLedgerEntryDtoFromJson(Map<String, dynamic> json) =>
    SalesLedgerEntryDto(
      reservationId: json['reservationId'] as String,
      shortageRequestId: json['shortageRequestId'] as String?,
      medicationName: json['medicationName'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      patientContact: json['patientContact'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      reservationCode: json['reservationCode'] as String,
    );

Map<String, dynamic> _$SalesLedgerEntryDtoToJson(
  SalesLedgerEntryDto instance,
) => <String, dynamic>{
  'reservationId': instance.reservationId,
  'shortageRequestId': instance.shortageRequestId,
  'medicationName': instance.medicationName,
  'price': instance.price,
  'quantity': instance.quantity,
  'patientContact': instance.patientContact,
  'completedAt': instance.completedAt.toIso8601String(),
  'reservationCode': instance.reservationCode,
};

SalesLedgerDto _$SalesLedgerDtoFromJson(Map<String, dynamic> json) =>
    SalesLedgerDto(
      totalCompleted: (json['totalCompleted'] as num).toInt(),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      todayCount: (json['todayCount'] as num).toInt(),
      entries: (json['entries'] as List<dynamic>)
          .map((e) => SalesLedgerEntryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SalesLedgerDtoToJson(SalesLedgerDto instance) =>
    <String, dynamic>{
      'totalCompleted': instance.totalCompleted,
      'totalRevenue': instance.totalRevenue,
      'todayCount': instance.todayCount,
      'entries': instance.entries,
    };

TicketMessageDto _$TicketMessageDtoFromJson(Map<String, dynamic> json) =>
    TicketMessageDto(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderRole: json['senderRole'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$TicketMessageDtoToJson(TicketMessageDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'senderId': instance.senderId,
      'senderRole': instance.senderRole,
      'body': instance.body,
      'createdAt': instance.createdAt.toIso8601String(),
    };

PostMessageRequest _$PostMessageRequestFromJson(Map<String, dynamic> json) =>
    PostMessageRequest(body: json['body'] as String);

Map<String, dynamic> _$PostMessageRequestToJson(PostMessageRequest instance) =>
    <String, dynamic>{'body': instance.body};
