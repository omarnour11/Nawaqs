import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const _prefLabelKey = 'nawaqss_delivery_location_label';
  static const _prefLatKey = 'nawaqss_delivery_location_lat';
  static const _prefLngKey = 'nawaqss_delivery_location_lng';
  static const _prefGovKey = 'nawaqss_delivery_location_gov';

  @override
  DeliveryLocation build() {
    _loadSavedLocation();
    return const DeliveryLocation(
      label: 'الحي المتميز، 6 أكتوبر',
      latitude: 29.987,
      longitude: 30.942,
      governorate: 'الجيزة',
    );
  }

  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final label = prefs.getString(_prefLabelKey);
      final lat = prefs.getDouble(_prefLatKey);
      final lng = prefs.getDouble(_prefLngKey);
      final gov = prefs.getString(_prefGovKey);

      if (label != null && lat != null && lng != null) {
        state = DeliveryLocation(
          label: label,
          latitude: lat,
          longitude: lng,
          governorate: gov,
        );
      }
    } catch (_) {}
  }

  void setLocation(DeliveryLocation loc) {
    state = loc;
    _persistLocation(loc);
  }

  Future<void> _persistLocation(DeliveryLocation loc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLabelKey, loc.label);
      await prefs.setDouble(_prefLatKey, loc.latitude);
      await prefs.setDouble(_prefLngKey, loc.longitude);
      if (loc.governorate != null) {
        await prefs.setString(_prefGovKey, loc.governorate!);
      }
    } catch (_) {}
  }
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