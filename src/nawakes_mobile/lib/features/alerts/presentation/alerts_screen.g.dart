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

/// The patient's active regimen, for the "من أدويتي" quick-pick chips.

@ProviderFor(myRegimenMeds)
final myRegimenMedsProvider = MyRegimenMedsProvider._();

/// The patient's active regimen, for the "من أدويتي" quick-pick chips.

final class MyRegimenMedsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PatientMedicationDto>>,
          List<PatientMedicationDto>,
          FutureOr<List<PatientMedicationDto>>
        >
    with
        $FutureModifier<List<PatientMedicationDto>>,
        $FutureProvider<List<PatientMedicationDto>> {
  /// The patient's active regimen, for the "من أدويتي" quick-pick chips.
  MyRegimenMedsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myRegimenMedsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myRegimenMedsHash();

  @$internal
  @override
  $FutureProviderElement<List<PatientMedicationDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PatientMedicationDto>> create(Ref ref) {
    return myRegimenMeds(ref);
  }
}

String _$myRegimenMedsHash() => r'a40b81a36677a829c2b6a50ff848708377bfa7c1';

/// Availability state for one alert: how many nearby pharmacies stock it.

@ProviderFor(alertAvailability)
final alertAvailabilityProvider = AlertAvailabilityFamily._();

/// Availability state for one alert: how many nearby pharmacies stock it.

final class AlertAvailabilityProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Availability state for one alert: how many nearby pharmacies stock it.
  AlertAvailabilityProvider._({
    required AlertAvailabilityFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'alertAvailabilityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$alertAvailabilityHash();

  @override
  String toString() {
    return r'alertAvailabilityProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return alertAvailability(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AlertAvailabilityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$alertAvailabilityHash() => r'c81cb58a8ad7bfcbfe3849dbd9ea77d01d81bbdf';

/// Availability state for one alert: how many nearby pharmacies stock it.

final class AlertAvailabilityFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  AlertAvailabilityFamily._()
    : super(
        retry: null,
        name: r'alertAvailabilityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Availability state for one alert: how many nearby pharmacies stock it.

  AlertAvailabilityProvider call(String medicationName) =>
      AlertAvailabilityProvider._(argument: medicationName, from: this);

  @override
  String toString() => r'alertAvailabilityProvider';
}
