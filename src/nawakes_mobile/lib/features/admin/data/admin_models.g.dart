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

NotifyPharmacyRequest _$NotifyPharmacyRequestFromJson(
  Map<String, dynamic> json,
) => NotifyPharmacyRequest(
  title: json['title'] as String,
  message: json['message'] as String,
);

Map<String, dynamic> _$NotifyPharmacyRequestToJson(
  NotifyPharmacyRequest instance,
) => <String, dynamic>{'title': instance.title, 'message': instance.message};

UpdatePharmacyStatusRequest _$UpdatePharmacyStatusRequestFromJson(
  Map<String, dynamic> json,
) => UpdatePharmacyStatusRequest(
  status: json['status'] as String,
  reason: json['reason'] as String?,
);

Map<String, dynamic> _$UpdatePharmacyStatusRequestToJson(
  UpdatePharmacyStatusRequest instance,
) => <String, dynamic>{'status': instance.status, 'reason': instance.reason};

ReviewReportRequest _$ReviewReportRequestFromJson(Map<String, dynamic> json) =>
    ReviewReportRequest(confirm: json['confirm'] as bool);

Map<String, dynamic> _$ReviewReportRequestToJson(
  ReviewReportRequest instance,
) => <String, dynamic>{'confirm': instance.confirm};

PatientSummaryDto _$PatientSummaryDtoFromJson(Map<String, dynamic> json) =>
    PatientSummaryDto(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String?,
      phone: json['phone'] as String?,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      reservationCount: (json['reservationCount'] as num).toInt(),
      complaintCount: (json['complaintCount'] as num).toInt(),
    );

Map<String, dynamic> _$PatientSummaryDtoToJson(PatientSummaryDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'fullName': instance.fullName,
      'phone': instance.phone,
      'registeredAt': instance.registeredAt.toIso8601String(),
      'reservationCount': instance.reservationCount,
      'complaintCount': instance.complaintCount,
    };

PagedPatientsResult _$PagedPatientsResultFromJson(Map<String, dynamic> json) =>
    PagedPatientsResult(
      items: (json['items'] as List<dynamic>)
          .map((e) => PatientSummaryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['totalCount'] as num).toInt(),
      pageNumber: (json['pageNumber'] as num).toInt(),
      pageSize: (json['pageSize'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
    );

Map<String, dynamic> _$PagedPatientsResultToJson(
  PagedPatientsResult instance,
) => <String, dynamic>{
  'items': instance.items,
  'totalCount': instance.totalCount,
  'pageNumber': instance.pageNumber,
  'pageSize': instance.pageSize,
  'totalPages': instance.totalPages,
};

MedicineCatalogItemDto _$MedicineCatalogItemDtoFromJson(
  Map<String, dynamic> json,
) => MedicineCatalogItemDto(
  id: json['id'] as String,
  tradeName: json['tradeName'] as String,
  activeIngredient: json['activeIngredient'] as String?,
  strength: json['strength'] as String?,
  dosageForm: json['dosageForm'] as String?,
  officialPriceEGP: (json['officialPriceEGP'] as num?)?.toDouble(),
  manufacturer: json['manufacturer'] as String?,
  edaRegistrationNumber: json['edaRegistrationNumber'] as String?,
  isChronic: json['isChronic'] as bool? ?? false,
);

Map<String, dynamic> _$MedicineCatalogItemDtoToJson(
  MedicineCatalogItemDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'tradeName': instance.tradeName,
  'activeIngredient': instance.activeIngredient,
  'strength': instance.strength,
  'dosageForm': instance.dosageForm,
  'officialPriceEGP': instance.officialPriceEGP,
  'manufacturer': instance.manufacturer,
  'edaRegistrationNumber': instance.edaRegistrationNumber,
  'isChronic': instance.isChronic,
};

PagedMedicineCatalogResult _$PagedMedicineCatalogResultFromJson(
  Map<String, dynamic> json,
) => PagedMedicineCatalogResult(
  items: (json['items'] as List<dynamic>)
      .map((e) => MedicineCatalogItemDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalCount: (json['totalCount'] as num).toInt(),
  pageNumber: (json['pageNumber'] as num).toInt(),
  pageSize: (json['pageSize'] as num).toInt(),
  totalPages: (json['totalPages'] as num).toInt(),
);

Map<String, dynamic> _$PagedMedicineCatalogResultToJson(
  PagedMedicineCatalogResult instance,
) => <String, dynamic>{
  'items': instance.items,
  'totalCount': instance.totalCount,
  'pageNumber': instance.pageNumber,
  'pageSize': instance.pageSize,
  'totalPages': instance.totalPages,
};
