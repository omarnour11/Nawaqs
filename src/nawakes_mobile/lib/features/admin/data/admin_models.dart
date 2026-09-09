import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_models.g.dart';

@JsonSerializable()
class DashboardStatsDto {
  final int totalPatients;
  final int totalPharmacies;
  final int pendingApprovals;
  final int approvedPharmacies;
  final int rejectedPharmacies;
  final int totalInventoryItems;
  final int inStockItems;
  final int outOfStockItems;
  final int activeReservations;
  final int completedReservations;
  final int pendingReports;
  final int totalPatientsSubscriptions;
  final double averageTrustScore;

  DashboardStatsDto({
    required this.totalPatients,
    required this.totalPharmacies,
    required this.pendingApprovals,
    required this.approvedPharmacies,
    required this.rejectedPharmacies,
    required this.totalInventoryItems,
    required this.inStockItems,
    required this.outOfStockItems,
    required this.activeReservations,
    required this.completedReservations,
    required this.pendingReports,
    required this.totalPatientsSubscriptions,
    required this.averageTrustScore,
  });

  factory DashboardStatsDto.fromJson(Map<String, dynamic> json) =>
      _$DashboardStatsDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DashboardStatsDtoToJson(this);
}

@JsonSerializable()
class AdminPharmacyDto {
  final String id;
  final String ownerId;
  final String ownerEmail;
  final String name;
  final String addressLine;
  final String city;
  final String phone;
  final double latitude;
  final double longitude;
  final String verificationStatus;
  final String? rejectionReason;
  final String? licenseDocUrl;
  final String? nationalIdDocUrl;
  final double trustScore;
  final int inventoryCount;
  final DateTime createdAt;

  AdminPharmacyDto({
    required this.id,
    required this.ownerId,
    required this.ownerEmail,
    required this.name,
    required this.addressLine,
    required this.city,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.verificationStatus,
    this.rejectionReason,
    this.licenseDocUrl,
    this.nationalIdDocUrl,
    required this.trustScore,
    required this.inventoryCount,
    required this.createdAt,
  });

  factory AdminPharmacyDto.fromJson(Map<String, dynamic> json) =>
      _$AdminPharmacyDtoFromJson(json);
  Map<String, dynamic> toJson() => _$AdminPharmacyDtoToJson(this);
}

@JsonSerializable()
class AdminReportDto {
  final String id;
  final String pharmacyId;
  final String pharmacyName;
  final String reporterEmail;
  final String type;
  final String status;
  final String? description;
  final String? medicationName;
  final double? reportedPrice;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  AdminReportDto({
    required this.id,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.reporterEmail,
    required this.type,
    required this.status,
    this.description,
    this.medicationName,
    this.reportedPrice,
    required this.createdAt,
    this.reviewedAt,
  });

  factory AdminReportDto.fromJson(Map<String, dynamic> json) =>
      _$AdminReportDtoFromJson(json);
  Map<String, dynamic> toJson() => _$AdminReportDtoToJson(this);
}

@JsonSerializable()
class ReviewPharmacyRequest {
  final bool approve;
  final String? rejectionReason;

  ReviewPharmacyRequest({required this.approve, this.rejectionReason});

  factory ReviewPharmacyRequest.fromJson(Map<String, dynamic> json) =>
      _$ReviewPharmacyRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ReviewPharmacyRequestToJson(this);
}

@JsonSerializable()
class ReviewReportRequest {
  final bool confirm;

  ReviewReportRequest({required this.confirm});

  factory ReviewReportRequest.fromJson(Map<String, dynamic> json) =>
      _$ReviewReportRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ReviewReportRequestToJson(this);
}
