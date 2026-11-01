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

@JsonSerializable()
class NotifyPharmacyRequest {
  final String title;
  final String message;

  NotifyPharmacyRequest({required this.title, required this.message});

  factory NotifyPharmacyRequest.fromJson(Map<String, dynamic> json) =>
      _$NotifyPharmacyRequestFromJson(json);
  Map<String, dynamic> toJson() => _$NotifyPharmacyRequestToJson(this);
}

@JsonSerializable()
class UpdatePharmacyStatusRequest {
  final String status;
  final String? reason;

  UpdatePharmacyStatusRequest({required this.status, this.reason});

  factory UpdatePharmacyStatusRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdatePharmacyStatusRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdatePharmacyStatusRequestToJson(this);
}

@JsonSerializable()
class ReviewReportRequest {
  final bool confirm;

  ReviewReportRequest({required this.confirm});

  factory ReviewReportRequest.fromJson(Map<String, dynamic> json) =>
      _$ReviewReportRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ReviewReportRequestToJson(this);
}

// ─── Patient Management Models ────────────────────────────────────────────────

@JsonSerializable()
class PatientSummaryDto {
  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final DateTime registeredAt;
  final int reservationCount;
  final int complaintCount;

  PatientSummaryDto({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    required this.registeredAt,
    required this.reservationCount,
    required this.complaintCount,
  });

  factory PatientSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$PatientSummaryDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PatientSummaryDtoToJson(this);
}

@JsonSerializable()
class PagedPatientsResult {
  final List<PatientSummaryDto> items;
  final int totalCount;
  final int pageNumber;
  final int pageSize;
  final int totalPages;

  PagedPatientsResult({
    required this.items,
    required this.totalCount,
    required this.pageNumber,
    required this.pageSize,
    required this.totalPages,
  });

  factory PagedPatientsResult.fromJson(Map<String, dynamic> json) =>
      _$PagedPatientsResultFromJson(json);
  Map<String, dynamic> toJson() => _$PagedPatientsResultToJson(this);
}

// ─── Medicine Catalog Models ─────────────────────────────────────────────────

@JsonSerializable()
class MedicineCatalogItemDto {
  final String id;
  final String tradeName;
  final String? activeIngredient;
  final String? strength;
  final String? dosageForm;
  final double? officialPriceEGP;
  final String? manufacturer;
  final String? edaRegistrationNumber;
  final bool isChronic;

  MedicineCatalogItemDto({
    required this.id,
    required this.tradeName,
    this.activeIngredient,
    this.strength,
    this.dosageForm,
    this.officialPriceEGP,
    this.manufacturer,
    this.edaRegistrationNumber,
    this.isChronic = false,
  });

  factory MedicineCatalogItemDto.fromJson(Map<String, dynamic> json) =>
      _$MedicineCatalogItemDtoFromJson(json);
  Map<String, dynamic> toJson() => _$MedicineCatalogItemDtoToJson(this);
}

@JsonSerializable()
class PagedMedicineCatalogResult {
  final List<MedicineCatalogItemDto> items;
  final int totalCount;
  final int pageNumber;
  final int pageSize;
  final int totalPages;

  PagedMedicineCatalogResult({
    required this.items,
    required this.totalCount,
    required this.pageNumber,
    required this.pageSize,
    required this.totalPages,
  });

  factory PagedMedicineCatalogResult.fromJson(Map<String, dynamic> json) =>
      _$PagedMedicineCatalogResultFromJson(json);
  Map<String, dynamic> toJson() => _$PagedMedicineCatalogResultToJson(this);
}

class ShortageDemandResponse {
  final List<ShortageDemandRow> rows;
  final DateTime generatedAt;

  ShortageDemandResponse({required this.rows, required this.generatedAt});

  factory ShortageDemandResponse.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'] ?? json['Rows'];
    return ShortageDemandResponse(
      rows: (rawRows as List<dynamic>? ?? [])
          .map((e) => ShortageDemandRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      generatedAt: _parseDate(json['generatedAt'] ?? json['GeneratedAt']),
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value == null) return DateTime.now();
    return DateTime.parse(value.toString());
  }
}

class ShortageDemandRow {
  final String medicationName;
  final String city;
  final int waitingCount;
  final DateTime oldestWaitingSince;

  ShortageDemandRow({
    required this.medicationName,
    required this.city,
    required this.waitingCount,
    required this.oldestWaitingSince,
  });

  factory ShortageDemandRow.fromJson(Map<String, dynamic> json) =>
      ShortageDemandRow(
        medicationName: (json['medicationName'] ?? json['MedicationName'])
                ?.toString() ??
            '',
        city: (json['city'] ?? json['City'])?.toString() ?? '',
        waitingCount:
            ((json['waitingCount'] ?? json['WaitingCount']) as num?)?.toInt() ??
                0,
        oldestWaitingSince: ShortageDemandResponse._parseDate(
            json['oldestWaitingSince'] ?? json['OldestWaitingSince']),
      );
}
