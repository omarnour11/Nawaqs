// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_ledger_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(salesLedger)
final salesLedgerProvider = SalesLedgerProvider._();

final class SalesLedgerProvider
    extends
        $FunctionalProvider<
          AsyncValue<SalesLedgerDto>,
          SalesLedgerDto,
          FutureOr<SalesLedgerDto>
        >
    with $FutureModifier<SalesLedgerDto>, $FutureProvider<SalesLedgerDto> {
  SalesLedgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'salesLedgerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$salesLedgerHash();

  @$internal
  @override
  $FutureProviderElement<SalesLedgerDto> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SalesLedgerDto> create(Ref ref) {
    return salesLedger(ref);
  }
}

String _$salesLedgerHash() => r'7441480401e80810bfaafafaf32ea1e1b774d1ac';
