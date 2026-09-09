// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medications_section.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(myMedications)
final myMedicationsProvider = MyMedicationsProvider._();

final class MyMedicationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PatientMedicationDto>>,
          List<PatientMedicationDto>,
          FutureOr<List<PatientMedicationDto>>
        >
    with
        $FutureModifier<List<PatientMedicationDto>>,
        $FutureProvider<List<PatientMedicationDto>> {
  MyMedicationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myMedicationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myMedicationsHash();

  @$internal
  @override
  $FutureProviderElement<List<PatientMedicationDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PatientMedicationDto>> create(Ref ref) {
    return myMedications(ref);
  }
}

String _$myMedicationsHash() => r'b82669c1d8dd645f44b93b6af961f2573b64427a';
