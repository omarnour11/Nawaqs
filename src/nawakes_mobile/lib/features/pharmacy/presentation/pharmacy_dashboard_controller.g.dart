// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pharmacy_dashboard_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PharmacyReservationsController)
final pharmacyReservationsControllerProvider =
    PharmacyReservationsControllerProvider._();

final class PharmacyReservationsControllerProvider
    extends
        $AsyncNotifierProvider<
          PharmacyReservationsController,
          List<PharmacyReservationResponse>
        > {
  PharmacyReservationsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pharmacyReservationsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pharmacyReservationsControllerHash();

  @$internal
  @override
  PharmacyReservationsController create() => PharmacyReservationsController();
}

String _$pharmacyReservationsControllerHash() =>
    r'e5db8be28a40454d1ba3aa9e46ba0e40bca7a1d5';

abstract class _$PharmacyReservationsController
    extends $AsyncNotifier<List<PharmacyReservationResponse>> {
  FutureOr<List<PharmacyReservationResponse>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<PharmacyReservationResponse>>,
              List<PharmacyReservationResponse>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PharmacyReservationResponse>>,
                List<PharmacyReservationResponse>
              >,
              AsyncValue<List<PharmacyReservationResponse>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(PharmacyInventoryController)
final pharmacyInventoryControllerProvider =
    PharmacyInventoryControllerProvider._();

final class PharmacyInventoryControllerProvider
    extends
        $AsyncNotifierProvider<
          PharmacyInventoryController,
          List<PharmacyInventoryItemDto>
        > {
  PharmacyInventoryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pharmacyInventoryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pharmacyInventoryControllerHash();

  @$internal
  @override
  PharmacyInventoryController create() => PharmacyInventoryController();
}

String _$pharmacyInventoryControllerHash() =>
    r'e4c78d2527ab3d15cdedc14b599672e045f711de';

abstract class _$PharmacyInventoryController
    extends $AsyncNotifier<List<PharmacyInventoryItemDto>> {
  FutureOr<List<PharmacyInventoryItemDto>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<PharmacyInventoryItemDto>>,
              List<PharmacyInventoryItemDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PharmacyInventoryItemDto>>,
                List<PharmacyInventoryItemDto>
              >,
              AsyncValue<List<PharmacyInventoryItemDto>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
