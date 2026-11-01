// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_dashboard_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(adminStats)
final adminStatsProvider = AdminStatsProvider._();

final class AdminStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<DashboardStatsDto>,
          DashboardStatsDto,
          FutureOr<DashboardStatsDto>
        >
    with
        $FutureModifier<DashboardStatsDto>,
        $FutureProvider<DashboardStatsDto> {
  AdminStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminStatsHash();

  @$internal
  @override
  $FutureProviderElement<DashboardStatsDto> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DashboardStatsDto> create(Ref ref) {
    return adminStats(ref);
  }
}

String _$adminStatsHash() => r'3a14704ae63fbe1c91524d6d665a56f39610d242';

@ProviderFor(adminPharmacies)
final adminPharmaciesProvider = AdminPharmaciesFamily._();

final class AdminPharmaciesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AdminPharmacyDto>>,
          List<AdminPharmacyDto>,
          FutureOr<List<AdminPharmacyDto>>
        >
    with
        $FutureModifier<List<AdminPharmacyDto>>,
        $FutureProvider<List<AdminPharmacyDto>> {
  AdminPharmaciesProvider._({
    required AdminPharmaciesFamily super.from,
    required bool super.argument,
  }) : super(
         retry: null,
         name: r'adminPharmaciesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$adminPharmaciesHash();

  @override
  String toString() {
    return r'adminPharmaciesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AdminPharmacyDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AdminPharmacyDto>> create(Ref ref) {
    final argument = this.argument as bool;
    return adminPharmacies(ref, all: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AdminPharmaciesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$adminPharmaciesHash() => r'46e0508848f30e54db5c8699e65090481abd4c62';

final class AdminPharmaciesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AdminPharmacyDto>>, bool> {
  AdminPharmaciesFamily._()
    : super(
        retry: null,
        name: r'adminPharmaciesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AdminPharmaciesProvider call({bool all = false}) =>
      AdminPharmaciesProvider._(argument: all, from: this);

  @override
  String toString() => r'adminPharmaciesProvider';
}

@ProviderFor(adminReports)
final adminReportsProvider = AdminReportsFamily._();

final class AdminReportsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AdminReportDto>>,
          List<AdminReportDto>,
          FutureOr<List<AdminReportDto>>
        >
    with
        $FutureModifier<List<AdminReportDto>>,
        $FutureProvider<List<AdminReportDto>> {
  AdminReportsProvider._({
    required AdminReportsFamily super.from,
    required bool super.argument,
  }) : super(
         retry: null,
         name: r'adminReportsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$adminReportsHash();

  @override
  String toString() {
    return r'adminReportsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AdminReportDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AdminReportDto>> create(Ref ref) {
    final argument = this.argument as bool;
    return adminReports(ref, pendingOnly: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AdminReportsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$adminReportsHash() => r'16c8b0ad5257e1b8544395e93dfed6b4dbada01a';

final class AdminReportsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AdminReportDto>>, bool> {
  AdminReportsFamily._()
    : super(
        retry: null,
        name: r'adminReportsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AdminReportsProvider call({bool pendingOnly = true}) =>
      AdminReportsProvider._(argument: pendingOnly, from: this);

  @override
  String toString() => r'adminReportsProvider';
}

@ProviderFor(adminPatients)
final adminPatientsProvider = AdminPatientsFamily._();

final class AdminPatientsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PagedPatientsResult>,
          PagedPatientsResult,
          FutureOr<PagedPatientsResult>
        >
    with
        $FutureModifier<PagedPatientsResult>,
        $FutureProvider<PagedPatientsResult> {
  AdminPatientsProvider._({
    required AdminPatientsFamily super.from,
    required ({String? search, int page}) super.argument,
  }) : super(
         retry: null,
         name: r'adminPatientsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$adminPatientsHash();

  @override
  String toString() {
    return r'adminPatientsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<PagedPatientsResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PagedPatientsResult> create(Ref ref) {
    final argument = this.argument as ({String? search, int page});
    return adminPatients(ref, search: argument.search, page: argument.page);
  }

  @override
  bool operator ==(Object other) {
    return other is AdminPatientsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$adminPatientsHash() => r'04fb2eea1c00d9e03a9397d6cc9441c82cd2c47b';

final class AdminPatientsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<PagedPatientsResult>,
          ({String? search, int page})
        > {
  AdminPatientsFamily._()
    : super(
        retry: null,
        name: r'adminPatientsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AdminPatientsProvider call({String? search, int page = 1}) =>
      AdminPatientsProvider._(
        argument: (search: search, page: page),
        from: this,
      );

  @override
  String toString() => r'adminPatientsProvider';
}

@ProviderFor(adminMedicineCatalog)
final adminMedicineCatalogProvider = AdminMedicineCatalogFamily._();

final class AdminMedicineCatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<PagedMedicineCatalogResult>,
          PagedMedicineCatalogResult,
          FutureOr<PagedMedicineCatalogResult>
        >
    with
        $FutureModifier<PagedMedicineCatalogResult>,
        $FutureProvider<PagedMedicineCatalogResult> {
  AdminMedicineCatalogProvider._({
    required AdminMedicineCatalogFamily super.from,
    required ({String? search, int page, bool? chronicOnly}) super.argument,
  }) : super(
         retry: null,
         name: r'adminMedicineCatalogProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$adminMedicineCatalogHash();

  @override
  String toString() {
    return r'adminMedicineCatalogProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<PagedMedicineCatalogResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PagedMedicineCatalogResult> create(Ref ref) {
    final argument =
        this.argument as ({String? search, int page, bool? chronicOnly});
    return adminMedicineCatalog(
      ref,
      search: argument.search,
      page: argument.page,
      chronicOnly: argument.chronicOnly,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AdminMedicineCatalogProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$adminMedicineCatalogHash() =>
    r'eb119645e80238aba58327a1de3b2d3b1c725f26';

final class AdminMedicineCatalogFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<PagedMedicineCatalogResult>,
          ({String? search, int page, bool? chronicOnly})
        > {
  AdminMedicineCatalogFamily._()
    : super(
        retry: null,
        name: r'adminMedicineCatalogProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AdminMedicineCatalogProvider call({
    String? search,
    int page = 1,
    bool? chronicOnly,
  }) => AdminMedicineCatalogProvider._(
    argument: (search: search, page: page, chronicOnly: chronicOnly),
    from: this,
  );

  @override
  String toString() => r'adminMedicineCatalogProvider';
}
