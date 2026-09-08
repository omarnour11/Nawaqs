// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SearchController)
final searchControllerProvider = SearchControllerProvider._();

final class SearchControllerProvider
    extends
        $AsyncNotifierProvider<SearchController, SearchMedicationResponse?> {
  SearchControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchControllerHash();

  @$internal
  @override
  SearchController create() => SearchController();
}

String _$searchControllerHash() => r'992346e7c0099fa662628dc703fc400fe1f0a194';

abstract class _$SearchController
    extends $AsyncNotifier<SearchMedicationResponse?> {
  FutureOr<SearchMedicationResponse?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SearchMedicationResponse?>,
              SearchMedicationResponse?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SearchMedicationResponse?>,
                SearchMedicationResponse?
              >,
              AsyncValue<SearchMedicationResponse?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
