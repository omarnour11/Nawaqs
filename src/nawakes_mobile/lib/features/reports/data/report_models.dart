import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_models.g.dart';

@JsonSerializable()
class CreateReportRequest {
  final int type; // 0 = Inaccurate, 1 = Found
  final String medicationName;
  final double? reportedPrice;
  final String? description;

  CreateReportRequest({
    required this.type,
    required this.medicationName,
    this.reportedPrice,
    this.description,
  });

  factory CreateReportRequest.fromJson(Map<String, dynamic> json) => _$CreateReportRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateReportRequestToJson(this);
}
