import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';

part 'search_controller.g.dart';

@riverpod
class SearchController extends _$SearchController {
  @override
  FutureOr<SearchMedicationResponse?> build() {
    return null;
  }

  Future<void> search(
    String medication, {
    double radius = 100.0,
    String sortBy = "Distance",
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // ── 1. Resolve GPS location ──────────────────────────────────────────
      double lat = 30.0444; // Cairo fallback
      double lng = 31.2357;

      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 8),
              ),
            );
            lat = pos.latitude;
            lng = pos.longitude;
          }
        }
      } catch (_) {
        // Silently fall through to the Cairo coordinates fallback
      }

      // ── 2. Call API ──────────────────────────────────────────────────────
      final client = ref.read(apiClientProvider);
      return await client.searchMedications(medication, lat, lng, radius, sortBy);
    });
  }
}
