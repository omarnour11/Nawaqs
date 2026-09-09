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
final adminPharmaciesProvider = AdminPharmaciesProvider._();

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
  AdminPharmaciesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminPharmaciesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminPharmaciesHash();

  @$internal
  @override
  $FutureProviderElement<List<AdminPharmacyDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AdminPharmacyDto>> create(Ref ref) {
    return adminPharmacies(ref);
  }
}

String _$adminPharmaciesHash() => r'0dd6f2cb992c8ed88a0ad2f84278754f65874361';

@ProviderFor(adminReports)
final adminReportsProvider = AdminReportsProvider._();

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
  AdminReportsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminReportsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminReportsHash();

  @$internal
  @override
  $FutureProviderElement<List<AdminReportDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AdminReportDto>> create(Ref ref) {
    return adminReports(ref);
  }
}

String _$adminReportsHash() => r'2dad01063f9c5e9aaf8e3c32b98769079096dfbf';

@ProviderFor(adminTickets)
final adminTicketsProvider = AdminTicketsProvider._();

final class AdminTicketsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AdminTicketDto>>,
          List<AdminTicketDto>,
          FutureOr<List<AdminTicketDto>>
        >
    with
        $FutureModifier<List<AdminTicketDto>>,
        $FutureProvider<List<AdminTicketDto>> {
  AdminTicketsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminTicketsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminTicketsHash();

  @$internal
  @override
  $FutureProviderElement<List<AdminTicketDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AdminTicketDto>> create(Ref ref) {
    return adminTickets(ref);
  }
}

String _$adminTicketsHash() => r'462abd7a33991770c1a192d4fae657c40466103e';
