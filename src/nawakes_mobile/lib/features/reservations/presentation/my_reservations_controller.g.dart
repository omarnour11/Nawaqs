// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_reservations_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MyReservationsController)
final myReservationsControllerProvider = MyReservationsControllerProvider._();

final class MyReservationsControllerProvider
    extends
        $AsyncNotifierProvider<
          MyReservationsController,
          List<ReservationResponse>
        > {
  MyReservationsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myReservationsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myReservationsControllerHash();

  @$internal
  @override
  MyReservationsController create() => MyReservationsController();
}

String _$myReservationsControllerHash() =>
    r'e70eb7c221a8fa56a5056ead5823f7313dcbbd07';

abstract class _$MyReservationsController
    extends $AsyncNotifier<List<ReservationResponse>> {
  FutureOr<List<ReservationResponse>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<ReservationResponse>>,
              List<ReservationResponse>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ReservationResponse>>,
                List<ReservationResponse>
              >,
              AsyncValue<List<ReservationResponse>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
