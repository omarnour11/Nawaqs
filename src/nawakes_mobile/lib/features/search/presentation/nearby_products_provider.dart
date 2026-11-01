import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';

class NearbyProductsCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setCategory(String? cat) => state = cat;
}

final nearbyProductsCategoryProvider =
    NotifierProvider<NearbyProductsCategoryNotifier, String?>(
        NearbyProductsCategoryNotifier.new);

class DeliveryLocation {
  final String label;
  final double latitude;
  final double longitude;
  final String? governorate;

  const DeliveryLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.governorate,
  });
}

class DeliveryLocationNotifier extends Notifier<DeliveryLocation> {
  @override
  DeliveryLocation build() => const DeliveryLocation(
        label: 'الحي المتميز، 6 أكتوبر',
        latitude: 29.987,
        longitude: 30.942,
        governorate: 'الجيزة',
      );

  void setLocation(DeliveryLocation loc) => state = loc;
}

final deliveryLocationProvider =
    NotifierProvider<DeliveryLocationNotifier, DeliveryLocation>(
        DeliveryLocationNotifier.new);

final nearbyProductsProvider =
    FutureProvider.autoDispose<List<NearbyProduct>>((ref) async {
  final category = ref.watch(nearbyProductsCategoryProvider);
  final deliveryLoc = ref.watch(deliveryLocationProvider);
  final apiClient = ref.read(apiClientProvider);

  try {
    final resp = await apiClient.getNearbyProducts(
      lat: deliveryLoc.latitude,
      lng: deliveryLoc.longitude,
      radius: 15.0,
      category: category,
      limit: 30,
    );
    return resp.products;
  } catch (e) {
    return [];
  }
});
