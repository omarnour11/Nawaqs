import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_models.g.dart';

@JsonSerializable()
class NotificationDto {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? relatedEntityId;
  final bool isRead;
  final DateTime createdAt;

  NotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.relatedEntityId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) => _$NotificationDtoFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationDtoToJson(this);
}
