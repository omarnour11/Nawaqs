// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_reports_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pendingReports)
final pendingReportsProvider = PendingReportsProvider._();

final class PendingReportsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AdminReportDto>>,
          List<AdminReportDto>,
          FutureOr<List<AdminReportDto>>
        >
    with
        $FutureModifier<List<AdminReportDto>>,
        $FutureProvider<List<AdminReportDto>> {
  PendingReportsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingReportsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingReportsHash();

  @$internal
  @override
  $FutureProviderElement<List<AdminReportDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AdminReportDto>> create(Ref ref) {
    return pendingReports(ref);
  }
}

String _$pendingReportsHash() => r'07b92a6e64cab64c2f3142a653d9f12e868c7198';
