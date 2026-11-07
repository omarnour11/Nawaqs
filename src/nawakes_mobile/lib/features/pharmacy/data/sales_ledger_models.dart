import 'package:freezed_annotation/freezed_annotation.dart';

part 'sales_ledger_models.g.dart';

@JsonSerializable()
class SalesLedgerEntryDto {
  final String reservationId;
  final String? shortageRequestId;
  final String medicationName;
  final double price;
  final int quantity;
  final String patientContact;
  final dynamic completedAt;
  final String reservationCode;

  const SalesLedgerEntryDto({
    required this.reservationId,
    this.shortageRequestId,
    required this.medicationName,
    required this.price,
    required this.quantity,
    required this.patientContact,
    required this.completedAt,
    required this.reservationCode,
  });

  DateTime get completedAtDateTime => completedAt is DateTime
      ? completedAt as DateTime
      : (DateTime.tryParse(completedAt?.toString() ?? '') ?? DateTime.now());

  factory SalesLedgerEntryDto.fromJson(Map<String, dynamic> json) =>
      _$SalesLedgerEntryDtoFromJson(json);

  Map<String, dynamic> toJson() {
    try {
      return _$SalesLedgerEntryDtoToJson(this);
    } catch (_) {
      return {
        'reservationId': reservationId,
        'shortageRequestId': shortageRequestId,
        'medicationName': medicationName,
        'price': price,
        'quantity': quantity,
        'patientContact': patientContact,
        'completedAt': completedAtDateTime.toIso8601String(),
        'reservationCode': reservationCode,
      };
    }
  }
}

@JsonSerializable()
class SalesLedgerDto {
  final int totalCompleted;
  final double totalRevenue;
  final int todayCount;
  final List<SalesLedgerEntryDto> entries;

  const SalesLedgerDto({
    required this.totalCompleted,
    required this.totalRevenue,
    required this.todayCount,
    required this.entries,
  });

  factory SalesLedgerDto.fromJson(Map<String, dynamic> json) =>
      _$SalesLedgerDtoFromJson(json);
  Map<String, dynamic> toJson() => _$SalesLedgerDtoToJson(this);
}

@JsonSerializable()
class TicketMessageDto {
  final String id;
  final String senderId;
  final String senderRole;
  final String body;
  final DateTime createdAt;

  TicketMessageDto({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  factory TicketMessageDto.fromJson(Map<String, dynamic> json) =>
      _$TicketMessageDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TicketMessageDtoToJson(this);
}

@JsonSerializable()
class PostMessageRequest {
  final String body;

  PostMessageRequest({required this.body});

  factory PostMessageRequest.fromJson(Map<String, dynamic> json) =>
      _$PostMessageRequestFromJson(json);
  Map<String, dynamic> toJson() => _$PostMessageRequestToJson(this);
}
