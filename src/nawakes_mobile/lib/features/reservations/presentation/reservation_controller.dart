import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/search/data/active_prescription_provider.dart';

part 'reservation_controller.g.dart';

@riverpod
class ReservationController extends _$ReservationController {
  @override
  FutureOr<void> build() {}

  Future<void> reserveItem(String inventoryItemId) async {
    state = const AsyncValue.loading();
    
    state = await AsyncValue.guard(() async {
      final client = ref.read(apiClientProvider);
      try {
        final crop = ref.read(activePrescriptionCropBase64Provider);
        await client.createReservation(CreateReservationRequest(inventoryItemId: inventoryItemId, prescriptionCropBase64: crop));
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          throw Exception('Item is already reserved or out of stock.');
        } else if (e.response?.statusCode == 404) {
          throw Exception('Item not found.');
        } else {
          throw Exception('Failed to reserve item: ${e.message}');
        }
      } catch (e) {
        throw Exception('An unexpected error occurred.');
      }
    });
  }
}
