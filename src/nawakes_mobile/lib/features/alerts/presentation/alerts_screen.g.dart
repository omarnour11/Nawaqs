// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alerts_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(myAlerts)
final myAlertsProvider = MyAlertsProvider._();

final class MyAlertsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AlertDto>>,
          List<AlertDto>,
          FutureOr<List<AlertDto>>
        >
    with $FutureModifier<List<AlertDto>>, $FutureProvider<List<AlertDto>> {
  MyAlertsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myAlertsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myAlertsHash();

  @$internal
  @override
  $FutureProviderElement<List<AlertDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AlertDto>> create(Ref ref) {
    return myAlerts(ref);
  }
}

String _$myAlertsHash() => r'b48136e730316c62482eacb151fd799dd388d0a3';
