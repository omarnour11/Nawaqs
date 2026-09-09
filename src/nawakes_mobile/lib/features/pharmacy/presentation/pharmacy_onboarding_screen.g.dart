// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pharmacy_onboarding_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(myPharmacy)
final myPharmacyProvider = MyPharmacyProvider._();

final class MyPharmacyProvider
    extends
        $FunctionalProvider<
          AsyncValue<MyPharmacyDto?>,
          MyPharmacyDto?,
          FutureOr<MyPharmacyDto?>
        >
    with $FutureModifier<MyPharmacyDto?>, $FutureProvider<MyPharmacyDto?> {
  MyPharmacyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myPharmacyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myPharmacyHash();

  @$internal
  @override
  $FutureProviderElement<MyPharmacyDto?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MyPharmacyDto?> create(Ref ref) {
    return myPharmacy(ref);
  }
}

String _$myPharmacyHash() => r'5d1bb955d220e1d034308e3d2dca39df01bbec2b';
