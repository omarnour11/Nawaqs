import 'dart:async';
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

  Future<void> markReady(String id) async {
    final client = ref.read(apiClientProvider);
    await client.markReservationReady(id);
    ref.invalidateSelf();
  }

  Future<void> cancelReservation(String id, String? reason) async {
    final client = ref.read(apiClientProvider);
    await client.cancelReservationByPharmacy(
        id, CancelByPharmacyRequest(reason: reason));
    ref.invalidateSelf();
    ref.invalidate(pharmacyInventoryControllerProvider);
  }
}

@riverpod
class PharmacyInventoryController extends _$PharmacyInventoryController {
  @override
  FutureOr<List<PharmacyInventoryItemDto>> build() async {
    final client = ref.read(apiClientProvider);
    final result = await client.getPharmacyInventory();
    return result.items;
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

  Future<void> addItem(String name, double price,
      {int? quantity, String? note, String? dosageForm, String? strength}) async {
    final client = ref.read(apiClientProvider);
    final qty = quantity ?? 10;
    await client.addInventoryItem(
      AddInventoryItemRequest(
        medicationName: name,
        price: price,
        status: qty == 0 ? 1 : 0, // 0=InStock, 1=OutOfStock
        quantity: qty,
        patientNote: note,
        dosageForm: dosageForm,
        strength: strength,
      ),
    );
    ref.invalidateSelf();
  }

  Future<void> deleteItem(String id) async {
    final client = ref.read(apiClientProvider);
    await client.deleteInventoryItem(id);
    ref.invalidateSelf();
  }

  Future<void> updateItem(String id, int quantity, double price) async {
    final client = ref.read(apiClientProvider);
    await client.setAvailability(
      id,
      SetAvailabilityRequest(quantity: quantity, price: price),
    );
    ref.invalidateSelf();
  }
}
