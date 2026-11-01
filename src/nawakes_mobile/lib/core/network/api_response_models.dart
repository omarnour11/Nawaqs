import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_response_models.g.dart';

@JsonSerializable()
class UploadResultDto {
  final String url;

  UploadResultDto({required this.url});

  factory UploadResultDto.fromJson(Map<String, dynamic> json) => _$UploadResultDtoFromJson(json);
  Map<String, dynamic> toJson() => _$UploadResultDtoToJson(this);
}

@JsonSerializable()
class ToggleFavoriteResponse {
  final bool isFavorite;

  ToggleFavoriteResponse({required this.isFavorite});

  factory ToggleFavoriteResponse.fromJson(Map<String, dynamic> json) =>
      _$ToggleFavoriteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ToggleFavoriteResponseToJson(this);
}

class IdResponse {
  final String id;

  IdResponse({required this.id});

  factory IdResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['id'] ?? json['Id'];
    return IdResponse(id: raw?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {'id': id};
}

@JsonSerializable()
class UnreadCountResponse {
  final int count;

  UnreadCountResponse({required this.count});

  factory UnreadCountResponse.fromJson(Map<String, dynamic> json) =>
      _$UnreadCountResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UnreadCountResponseToJson(this);
}

@JsonSerializable()
class MarkReadResponse {
  final int updated;

  MarkReadResponse({required this.updated});

  factory MarkReadResponse.fromJson(Map<String, dynamic> json) =>
      _$MarkReadResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MarkReadResponseToJson(this);
}


@JsonSerializable()
class ClaimShortageResponse {
  final String reservationId;

  ClaimShortageResponse({required this.reservationId});

  factory ClaimShortageResponse.fromJson(Map<String, dynamic> json) =>
      _$ClaimShortageResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ClaimShortageResponseToJson(this);
}

class ParseMultimodalBody {
  final String rawText;
  final String? inputType;

  /// Cropped prescription JPEG (base64). Processed by Gemini Vision when enabled.
  final String? imageBase64;

  ParseMultimodalBody({
    required this.rawText,
    this.inputType,
    this.imageBase64,
  });

  factory ParseMultimodalBody.fromJson(Map<String, dynamic> json) =>
      ParseMultimodalBody(
        rawText: json['rawText'] as String? ?? '',
        inputType: json['inputType'] as String?,
        imageBase64: json['imageBase64'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'rawText': rawText,
        if (inputType != null) 'inputType': inputType,
        if (imageBase64 != null && imageBase64!.isNotEmpty)
          'imageBase64': imageBase64,
      };
}

class SafetyAlertResponse {
  final String id;
  final String severity; // critical, warning, nominal
  final String category;
  final String title;
  final String description;
  final List<String> involvedDrugs;

  const SafetyAlertResponse({
    String? id,
    required this.severity,
    this.category = '',
    String? title,
    String? description,
    List<String>? involvedDrugs,
    String? alertCode,
    String? message,
    String? recommendation,
    List<String>? interactingSubstances,
  })  : id = id ?? alertCode ?? '',
        title = title ?? message ?? '',
        description = description ?? recommendation ?? '',
        involvedDrugs = involvedDrugs ?? interactingSubstances ?? const [];

  String get alertCode => id;
  String get message => title.isNotEmpty ? title : description;
  String get recommendation => description;
  List<String> get interactingSubstances => involvedDrugs;

  factory SafetyAlertResponse.fromJson(Map<String, dynamic> json) {
    final rawSeverity = json['severity']?.toString() ?? 'nominal';
    final id = json['id'] as String? ?? json['alertCode'] as String? ?? '';
    final title = json['title'] as String? ?? json['message'] as String? ?? '';
    final description = json['description'] as String? ?? json['recommendation'] as String? ?? '';
    final rawDrugs = (json['involvedDrugs'] ?? json['interactingSubstances']) as List<dynamic>?;
    final involvedDrugs = rawDrugs?.map((e) => e.toString()).toList() ?? const [];

    return SafetyAlertResponse(
      id: id,
      severity: rawSeverity,
      category: json['category'] as String? ?? '',
      title: title,
      description: description,
      involvedDrugs: involvedDrugs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'severity': severity,
        'category': category,
        'title': title,
        'description': description,
        'involvedDrugs': involvedDrugs,
        'alertCode': alertCode,
        'message': message,
        'recommendation': recommendation,
        'interactingSubstances': interactingSubstances,
      };
}

@JsonSerializable()
class ParsedMedicationResponse {
  final String resolvedName;
  final String? strength;
  final String? dosageForm;
  final double confidence;
  final bool requiresDisambiguation;
  final List<ParsedCandidate> candidates;
  final String? activeIngredient;
  final bool isSuccess;
  final String? errorCode;
  final String? errorMessage;
  final String? rawSig;
  final String? arabicSig;
  final double? priceEgp;
  final List<SafetyAlertResponse>? safetyAlerts;

  ParsedMedicationResponse({
    required this.resolvedName,
    this.strength,
    this.dosageForm,
    required this.confidence,
    required this.requiresDisambiguation,
    required this.candidates,
    this.activeIngredient,
    this.isSuccess = true,
    this.errorCode,
    this.errorMessage,
    this.rawSig,
    this.arabicSig,
    this.priceEgp,
    this.safetyAlerts,
  });

  factory ParsedMedicationResponse.fromJson(Map<String, dynamic> json) =>
      _$ParsedMedicationResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ParsedMedicationResponseToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: false)
class ParsedCandidate {
  final String tradeName;
  final String? strength;
  final String? dosageForm;
  final double confidence;
  @JsonKey(defaultValue: 1)
  final int quantity;
  final String? activeIngredient;
  final bool requiresDisambiguation;
  final List<ParsedCandidate>? alternatives;
  final String? rawSig;
  final String? arabicSig;
  final double? priceEgp;

  ParsedCandidate({
    required this.tradeName,
    this.strength,
    this.dosageForm,
    required this.confidence,
    this.quantity = 1,
    this.activeIngredient,
    this.requiresDisambiguation = false,
    this.alternatives,
    this.rawSig,
    this.arabicSig,
    this.priceEgp,
  });

  factory ParsedCandidate.fromJson(Map<String, dynamic> json) =>
      ParsedCandidate(
        tradeName: json['tradeName'] as String? ?? '',
        strength: json['strength'] as String?,
        dosageForm: json['dosageForm'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        activeIngredient: json['activeIngredient'] as String?,
        requiresDisambiguation: json['requiresDisambiguation'] as bool? ?? false,
        alternatives: (json['alternatives'] as List<dynamic>?)
            ?.map((e) => ParsedCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
        rawSig: json['rawSig'] as String?,
        arabicSig: json['arabicSig'] as String?,
        priceEgp: (json['priceEgp'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'tradeName': tradeName,
        'strength': strength,
        'dosageForm': dosageForm,
        'confidence': confidence,
        'quantity': quantity,
        if (activeIngredient != null) 'activeIngredient': activeIngredient,
        'requiresDisambiguation': requiresDisambiguation,
        if (alternatives != null)
          'alternatives': alternatives!.map((e) => e.toJson()).toList(),
        if (rawSig != null) 'rawSig': rawSig,
        if (arabicSig != null) 'arabicSig': arabicSig,
        if (priceEgp != null) 'priceEgp': priceEgp,
      };
}

class BatchSearchItemDto {
  final String medication;
  final int quantity;

  BatchSearchItemDto({required this.medication, this.quantity = 1});

  Map<String, dynamic> toJson() => {
        'medication': medication,
        'quantity': quantity,
      };
}

class BatchSearchRequest {
  final List<BatchSearchItemDto> items;
  final double lat;
  final double lng;
  final double radiusKm;

  BatchSearchRequest({
    required this.items,
    required this.lat,
    required this.lng,
    this.radiusKm = 10.0,
  });

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'lat': lat,
        'lng': lng,
        'radiusKm': radiusKm,
      };
}

class BatchMedicationDetail {
  final String medication;
  final int requestedQuantity;
  final bool inStock;
  final double price;
  final int availableQuantity;
  final String? inventoryItemId;

  BatchMedicationDetail({
    required this.medication,
    required this.requestedQuantity,
    required this.inStock,
    required this.price,
    required this.availableQuantity,
    this.inventoryItemId,
  });

  factory BatchMedicationDetail.fromJson(Map<String, dynamic> json) =>
      BatchMedicationDetail(
        medication: json['medication'] as String? ?? '',
        requestedQuantity: (json['requestedQuantity'] as num?)?.toInt() ?? 1,
        inStock: json['inStock'] as bool? ?? false,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        availableQuantity: (json['availableQuantity'] as num?)?.toInt() ?? 0,
        inventoryItemId: json['inventoryItemId'] as String?,
      );
}

class BatchPharmacyResult {
  final String pharmacyId;
  final String pharmacyName;
  final String addressLine;
  final String phone;
  final double trustScore;
  final double distanceKm;
  final double latitude;
  final double longitude;
  final int matchedCount;
  final int totalRequested;
  final bool isCompleteMatch;
  final double totalEstimatedPrice;
  final List<BatchMedicationDetail> items;

  BatchPharmacyResult({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.addressLine,
    required this.phone,
    required this.trustScore,
    required this.distanceKm,
    required this.latitude,
    required this.longitude,
    required this.matchedCount,
    required this.totalRequested,
    required this.isCompleteMatch,
    required this.totalEstimatedPrice,
    required this.items,
  });

  factory BatchPharmacyResult.fromJson(Map<String, dynamic> json) =>
      BatchPharmacyResult(
        pharmacyId: json['pharmacyId'] as String? ?? '',
        pharmacyName: json['pharmacyName'] as String? ?? '',
        addressLine: json['addressLine'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        trustScore: (json['trustScore'] as num?)?.toDouble() ?? 0.0,
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        matchedCount: (json['matchedCount'] as num?)?.toInt() ?? 0,
        totalRequested: (json['totalRequested'] as num?)?.toInt() ?? 0,
        isCompleteMatch: json['isCompleteMatch'] as bool? ?? false,
        totalEstimatedPrice:
            (json['totalEstimatedPrice'] as num?)?.toDouble() ?? 0.0,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) =>
                    BatchMedicationDetail.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class BatchSearchResponse {
  final List<BatchPharmacyResult> completePharmacies;
  final List<BatchPharmacyResult> partialPharmacies;
  final int totalRequestedItems;
  final double radiusKm;

  BatchSearchResponse({
    required this.completePharmacies,
    required this.partialPharmacies,
    required this.totalRequestedItems,
    required this.radiusKm,
  });

  factory BatchSearchResponse.fromJson(Map<String, dynamic> json) =>
      BatchSearchResponse(
        completePharmacies: (json['completePharmacies'] as List<dynamic>?)
                ?.map((e) =>
                    BatchPharmacyResult.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        partialPharmacies: (json['partialPharmacies'] as List<dynamic>?)
                ?.map((e) =>
                    BatchPharmacyResult.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        totalRequestedItems:
            (json['totalRequestedItems'] as num?)?.toInt() ?? 0,
        radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 10.0,
      );
}

class NearbyPharmacyOption {
  final String pharmacyId;
  final String pharmacyName;
  final String? address;
  final double distanceKm;
  final double price;
  final int inStockQuantity;
  final String? phone;
  final bool supportsDelivery;
  final String inventoryItemId;

  NearbyPharmacyOption({
    required this.pharmacyId,
    required this.pharmacyName,
    this.address,
    required this.distanceKm,
    required this.price,
    required this.inStockQuantity,
    this.phone,
    this.supportsDelivery = true,
    this.inventoryItemId = '',
  });

  factory NearbyPharmacyOption.fromJson(Map<String, dynamic> json) =>
      NearbyPharmacyOption(
        pharmacyId: json['pharmacyId']?.toString() ?? '',
        pharmacyName: json['pharmacyName']?.toString() ?? '',
        address: json['address']?.toString(),
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        inStockQuantity: (json['inStockQuantity'] as num?)?.toInt() ?? 0,
        phone: json['phone']?.toString(),
        supportsDelivery: (json['supportsDelivery'] as bool?) ?? true,
        inventoryItemId: json['inventoryItemId']?.toString() ?? '',
      );
}

class NearbyProduct {
  final String id;
  final String tradeName;
  final String? commercialNameAr;
  final String? dosageForm;
  final String? strength;
  final double price;
  final int availablePharmaciesCount;
  final double minDistanceKm;
  final String? category;
  final String? imageUrl;
  final List<NearbyPharmacyOption> pharmacies;
  final String? description;

  NearbyProduct({
    required this.id,
    required this.tradeName,
    this.commercialNameAr,
    this.dosageForm,
    this.strength,
    required this.price,
    required this.availablePharmaciesCount,
    required this.minDistanceKm,
    this.category,
    this.imageUrl,
    required this.pharmacies,
    this.description,
  });

  factory NearbyProduct.fromJson(Map<String, dynamic> json) => NearbyProduct(
        id: json['id']?.toString() ?? '',
        tradeName: json['tradeName']?.toString() ?? '',
        commercialNameAr: json['commercialNameAr']?.toString(),
        dosageForm: json['dosageForm']?.toString(),
        strength: json['strength']?.toString(),
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        availablePharmaciesCount:
            (json['availablePharmaciesCount'] as num?)?.toInt() ?? 0,
        minDistanceKm: (json['minDistanceKm'] as num?)?.toDouble() ?? 0.0,
        category: json['category']?.toString(),
        imageUrl: json['imageUrl']?.toString(),
        description: json['description']?.toString(),
        pharmacies: (json['pharmacies'] as List<dynamic>?)
                ?.map((e) =>
                    NearbyPharmacyOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class NearbyProductsResponse {
  final List<NearbyProduct> products;
  final int totalCount;
  final double radiusKm;

  NearbyProductsResponse({
    required this.products,
    required this.totalCount,
    required this.radiusKm,
  });

  factory NearbyProductsResponse.fromJson(Map<String, dynamic> json) =>
      NearbyProductsResponse(
        products: (json['products'] as List<dynamic>?)
                ?.map((e) => NearbyProduct.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 15.0,
      );
}
