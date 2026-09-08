// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateReportRequest _$CreateReportRequestFromJson(Map<String, dynamic> json) =>
    CreateReportRequest(
      type: (json['type'] as num).toInt(),
      medicationName: json['medicationName'] as String,
      reportedPrice: (json['reportedPrice'] as num?)?.toDouble(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$CreateReportRequestToJson(
  CreateReportRequest instance,
) => <String, dynamic>{
  'type': instance.type,
  'medicationName': instance.medicationName,
  'reportedPrice': instance.reportedPrice,
  'description': instance.description,
};
