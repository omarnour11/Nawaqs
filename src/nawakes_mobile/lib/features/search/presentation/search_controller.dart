import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';

part 'search_controller.g.dart';

class LocationPermissionRequiredException implements Exception {
  final String message;
  const LocationPermissionRequiredException([
    this.message = 'يجب تفعيل خدمة الموقع (GPS) ومنح الصلاحية لعرض نتائج البحث',
  ]);

  @override
  String toString() => message;
}

@riverpod
class SearchController extends _$SearchController {
  @override
  FutureOr<SearchMedicationResponse?> build() {
    return null;
  }

  Future<void> search(
    String medication, {
    double radius = 10.0,
    String sortBy = "Distance",
    double? latitude,
    double? longitude,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      double? lat = latitude;
      double? lng = longitude;

      // ── 1. Resolve GPS location (Mandatory: NO silent fallback to Cairo) ──
      if (lat == null || lng == null) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw const LocationPermissionRequiredException(
            'خدمة الموقع (GPS) غير مفعلة على جهازك',
          );
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw const LocationPermissionRequiredException(
            'لم يتم منح صلاحية الموقع، لا يمكن إتمام البحث بدون GPS',
          );
        }

        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }

      // ── 2. Call API with real verified coordinates ───────────────────────
      final client = ref.read(apiClientProvider);
      return await client.searchMedications(medication, lat, lng, radius, sortBy);
    });
  }
}
