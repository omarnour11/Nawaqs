import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/pharmacy/data/top_rated_pharmacy_model.dart';
import 'package:nawakes_mobile/features/search/presentation/nearby_products_provider.dart';

/// Fetches the top-rated approved partner pharmacies near the patient's current delivery location.
final topRatedPharmaciesProvider = FutureProvider.autoDispose<List<TopRatedPharmacyDto>>((ref) async {
  final loc = ref.watch(deliveryLocationProvider);
  final client = ref.read(apiClientProvider);

  try {
    return await client.getTopRatedPharmacies(
      latitude: loc.latitude,
      longitude: loc.longitude,
      limit: 2,
    );
  } catch (_) {
    try {
      return await client.getTopRatedPharmacies(limit: 2);
    } catch (_) {
      return const [];
    }
  }
});
