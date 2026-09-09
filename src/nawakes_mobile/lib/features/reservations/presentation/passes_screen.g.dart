// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passes_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// التصاريح tab — list of reservations; opening one shows the full pass.

@ProviderFor(PassesController)
final passesControllerProvider = PassesControllerProvider._();

/// التصاريح tab — list of reservations; opening one shows the full pass.
final class PassesControllerProvider
    extends
        $AsyncNotifierProvider<PassesController, List<ReservationResponse>> {
  /// التصاريح tab — list of reservations; opening one shows the full pass.
  PassesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'passesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$passesControllerHash();

  @$internal
  @override
  PassesController create() => PassesController();
}

String _$passesControllerHash() => r'c6b8d80dbc5df8a7f261a81920be1eb39849399e';

/// التصاريح tab — list of reservations; opening one shows the full pass.

abstract class _$PassesController
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
