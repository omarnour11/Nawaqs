// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardStatsDto _$DashboardStatsDtoFromJson(Map<String, dynamic> json) =>
    DashboardStatsDto(
      totalPatients: (json['totalPatients'] as num).toInt(),
      totalPharmacies: (json['totalPharmacies'] as num).toInt(),
      pendingApprovals: (json['pendingApprovals'] as num).toInt(),
      approvedPharmacies: (json['approvedPharmacies'] as num).toInt(),
      rejectedPharmacies: (json['rejectedPharmacies'] as num).toInt(),
      totalInventoryItems: (json['totalInventoryItems'] as num).toInt(),
      inStockItems: (json['inStockItems'] as num).toInt(),
      outOfStockItems: (json['outOfStockItems'] as num).toInt(),
      activeReservations: (json['activeReservations'] as num).toInt(),
      completedReservations: (json['completedReservations'] as num).toInt(),
      pendingReports: (json['pendingReports'] as num).toInt(),
      totalPatientsSubscriptions: (json['totalPatientsSubscriptions'] as num)
          .toInt(),
      averageTrustScore: (json['averageTrustScore'] as num).toDouble(),
    );

Map<String, dynamic> _$DashboardStatsDtoToJson(DashboardStatsDto instance) =>
    <String, dynamic>{
      'totalPatients': instance.totalPatients,
      'totalPharmacies': instance.totalPharmacies,
      'pendingApprovals': instance.pendingApprovals,
      'approvedPharmacies': instance.approvedPharmacies,
      'rejectedPharmacies': instance.rejectedPharmacies,
      'totalInventoryItems': instance.totalInventoryItems,
      'inStockItems': instance.inStockItems,
      'outOfStockItems': instance.outOfStockItems,
      'activeReservations': instance.activeReservations,
      'completedReservations': instance.completedReservations,
      'pendingReports': instance.pendingReports,
      'totalPatientsSubscriptions': instance.totalPatientsSubscriptions,
      'averageTrustScore': instance.averageTrustScore,
    };

AdminPharmacyDto _$AdminPharmacyDtoFromJson(Map<String, dynamic> json) =>
    AdminPharmacyDto(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      ownerEmail: json['ownerEmail'] as String,
      name: json['name'] as String,
      addressLine: json['addressLine'] as String,
      city: json['city'] as String,
      phone: json['phone'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      verificationStatus: json['verificationStatus'] as String,
      rejectionReason: json['rejectionReason'] as String?,
      licenseDocUrl: json['licenseDocUrl'] as String?,
      nationalIdDocUrl: json['nationalIdDocUrl'] as String?,
      trustScore: (json['trustScore'] as num).toDouble(),
      inventoryCount: (json['inventoryCount'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$AdminPharmacyDtoToJson(AdminPharmacyDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ownerId': instance.ownerId,
      'ownerEmail': instance.ownerEmail,
      'name': instance.name,
      'addressLine': instance.addressLine,
      'city': instance.city,
      'phone': instance.phone,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'verificationStatus': instance.verificationStatus,
      'rejectionReason': instance.rejectionReason,
      'licenseDocUrl': instance.licenseDocUrl,
      'nationalIdDocUrl': instance.nationalIdDocUrl,
      'trustScore': instance.trustScore,
      'inventoryCount': instance.inventoryCount,
      'createdAt': instance.createdAt.toIso8601String(),
    };

AdminReportDto _$AdminReportDtoFromJson(Map<String, dynamic> json) =>
    AdminReportDto(
      id: json['id'] as String,
      pharmacyId: json['pharmacyId'] as String,
      pharmacyName: json['pharmacyName'] as String,
      reporterEmail: json['reporterEmail'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      description: json['description'] as String?,
      medicationName: json['medicationName'] as String?,
      reportedPrice: (json['reportedPrice'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'] as String),
    );

Map<String, dynamic> _$AdminReportDtoToJson(AdminReportDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'pharmacyId': instance.pharmacyId,
      'pharmacyName': instance.pharmacyName,
      'reporterEmail': instance.reporterEmail,
      'type': instance.type,
      'status': instance.status,
      'description': instance.description,
      'medicationName': instance.medicationName,
      'reportedPrice': instance.reportedPrice,
      'createdAt': instance.createdAt.toIso8601String(),
      'reviewedAt': instance.reviewedAt?.toIso8601String(),
    };

ReviewPharmacyRequest _$ReviewPharmacyRequestFromJson(
  Map<String, dynamic> json,
) => ReviewPharmacyRequest(
  approve: json['approve'] as bool,
  rejectionReason: json['rejectionReason'] as String?,
);

Map<String, dynamic> _$ReviewPharmacyRequestToJson(
  ReviewPharmacyRequest instance,
) => <String, dynamic>{
  'approve': instance.approve,
  'rejectionReason': instance.rejectionReason,
};

ReviewReportRequest _$ReviewReportRequestFromJson(Map<String, dynamic> json) =>
    ReviewReportRequest(confirm: json['confirm'] as bool);

Map<String, dynamic> _$ReviewReportRequestToJson(
  ReviewReportRequest instance,
) => <String, dynamic>{'confirm': instance.confirm};
