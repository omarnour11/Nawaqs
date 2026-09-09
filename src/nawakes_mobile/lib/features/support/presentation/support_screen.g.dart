// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(myTickets)
final myTicketsProvider = MyTicketsProvider._();

final class MyTicketsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TicketDto>>,
          List<TicketDto>,
          FutureOr<List<TicketDto>>
        >
    with $FutureModifier<List<TicketDto>>, $FutureProvider<List<TicketDto>> {
  MyTicketsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myTicketsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myTicketsHash();

  @$internal
  @override
  $FutureProviderElement<List<TicketDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TicketDto>> create(Ref ref) {
    return myTickets(ref);
  }
}

String _$myTicketsHash() => r'8ebce2901f10044dc9acca41323f96dcc2c797c9';
