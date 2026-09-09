// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shortage_queue_tab.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(openShortageRequests)
final openShortageRequestsProvider = OpenShortageRequestsProvider._();

final class OpenShortageRequestsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ShortageRequestDto>>,
          List<ShortageRequestDto>,
          FutureOr<List<ShortageRequestDto>>
        >
    with
        $FutureModifier<List<ShortageRequestDto>>,
        $FutureProvider<List<ShortageRequestDto>> {
  OpenShortageRequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openShortageRequestsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openShortageRequestsHash();

  @$internal
  @override
  $FutureProviderElement<List<ShortageRequestDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ShortageRequestDto>> create(Ref ref) {
    return openShortageRequests(ref);
  }
}

String _$openShortageRequestsHash() =>
    r'5b3714500f927d09167e2ee074d633026a4dbd7d';
