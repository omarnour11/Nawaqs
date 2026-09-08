// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReservationController)
final reservationControllerProvider = ReservationControllerProvider._();

final class ReservationControllerProvider
    extends $AsyncNotifierProvider<ReservationController, void> {
  ReservationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reservationControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reservationControllerHash();

  @$internal
  @override
  ReservationController create() => ReservationController();
}

String _$reservationControllerHash() =>
    r'd9f882c264e25faa234e6013e62bd814c243e727';

abstract class _$ReservationController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
