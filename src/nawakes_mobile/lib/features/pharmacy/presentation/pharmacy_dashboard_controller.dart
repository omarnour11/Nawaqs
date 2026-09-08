import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_dashboard_models.dart';

part 'pharmacy_dashboard_controller.g.dart';

@riverpod
class PharmacyReservationsController extends _$PharmacyReservationsController {
  @override
  FutureOr<List<PharmacyReservationResponse>> build() async {
    final client = ref.read(apiClientProvider);
    return await client.getPharmacyReservations();
  }

  Future<void> completeReservation(String id) async {
    final client = ref.read(apiClientProvider);
    await client.completePharmacyReservation(id);
    ref.invalidateSelf();
    // Also invalidate inventory since complete changes status to OutOfStock
    ref.invalidate(pharmacyInventoryControllerProvider);
  }
}

@riverpod
class PharmacyInventoryController extends _$PharmacyInventoryController {
  @override
  FutureOr<List<PharmacyInventoryItemDto>> build() async {
    final client = ref.read(apiClientProvider);
    return await client.getPharmacyInventory();
  }

  Future<void> toggleStatus(String id, String currentStatus) async {
    final client = ref.read(apiClientProvider);
    final newStatus = currentStatus == 'InStock'
        ? 1
        : 0; // 0=InStock, 1=OutOfStock
    await client.toggleInventoryStatus(
      id,
      ToggleStatusRequest(status: newStatus),
    );
    ref.invalidateSelf();
  }

  Future<void> addItem(String name, double price) async {
    final client = ref.read(apiClientProvider);
    await client.addInventoryItem(
      AddInventoryItemRequest(
        medicationName: name,
        price: price,
        status: 0, // InStock by default
      ),
    );
    ref.invalidateSelf();
  }
}
