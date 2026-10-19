// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passes_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// التصاريح tab — list of reservations; opening one shows the full pass.
/// Falls back to cached passes when the network fails so the pickup code
/// stays reachable in basements with no reception.

@ProviderFor(PassesController)
final passesControllerProvider = PassesControllerProvider._();

/// التصاريح tab — list of reservations; opening one shows the full pass.
/// Falls back to cached passes when the network fails so the pickup code
/// stays reachable in basements with no reception.
final class PassesControllerProvider
    extends
        $AsyncNotifierProvider<PassesController, List<ReservationResponse>> {
  /// التصاريح tab — list of reservations; opening one shows the full pass.
  /// Falls back to cached passes when the network fails so the pickup code
  /// stays reachable in basements with no reception.
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

String _$passesControllerHash() => r'89ddd873e4474626a3aa0e130edf90ae8a5372ae';

/// التصاريح tab — list of reservations; opening one shows the full pass.
/// Falls back to cached passes when the network fails so the pickup code
/// stays reachable in basements with no reception.

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
