class TopRatedPharmacyDto {
  final String id;
  final String name;
  final String addressLine;
  final String city;
  final String phone;
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final double trustScore;
  final double averageRating;
  final int ratingCount;
  final bool offersDelivery;
  final double? deliveryFee;

  TopRatedPharmacyDto({
    required this.id,
    required this.name,
    required this.addressLine,
    required this.city,
    required this.phone,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
    required this.trustScore,
    required this.averageRating,
    required this.ratingCount,
    this.offersDelivery = true,
    this.deliveryFee,
  });

  factory TopRatedPharmacyDto.fromJson(Map<String, dynamic> json) => TopRatedPharmacyDto(
        id: json['id'] as String? ?? json['pharmacyId'] as String? ?? '',
        name: json['name'] as String? ?? json['pharmacyName'] as String? ?? '',
        addressLine: json['addressLine'] as String? ?? '',
        city: json['city'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        trustScore: (json['trustScore'] as num?)?.toDouble() ?? 100.0,
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 4.9,
        ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
        offersDelivery: json['offersDelivery'] as bool? ?? true,
        deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'addressLine': addressLine,
        'city': city,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
        'distanceKm': distanceKm,
        'trustScore': trustScore,
        'averageRating': averageRating,
        'ratingCount': ratingCount,
        'offersDelivery': offersDelivery,
        'deliveryFee': deliveryFee,
      };
}
