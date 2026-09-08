import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';

part 'my_reservations_controller.g.dart';

@riverpod
class MyReservationsController extends _$MyReservationsController {
  @override
  FutureOr<List<ReservationResponse>> build() async {
    final client = ref.read(apiClientProvider);
    return await client.getMyReservations();
  }

  Future<void> cancel(String id) async {
    final client = ref.read(apiClientProvider);
    await client.cancelReservation(id);
    ref.invalidateSelf();
  }
}
