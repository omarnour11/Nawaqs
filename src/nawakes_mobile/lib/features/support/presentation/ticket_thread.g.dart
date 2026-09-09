// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_thread.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ticketMessages)
final ticketMessagesProvider = TicketMessagesFamily._();

final class TicketMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TicketMessageDto>>,
          List<TicketMessageDto>,
          FutureOr<List<TicketMessageDto>>
        >
    with
        $FutureModifier<List<TicketMessageDto>>,
        $FutureProvider<List<TicketMessageDto>> {
  TicketMessagesProvider._({
    required TicketMessagesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ticketMessagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ticketMessagesHash();

  @override
  String toString() {
    return r'ticketMessagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TicketMessageDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TicketMessageDto>> create(Ref ref) {
    final argument = this.argument as String;
    return ticketMessages(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TicketMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ticketMessagesHash() => r'2ae15f69ee3a96d9a9ff3de345b7c834a9b13582';

final class TicketMessagesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TicketMessageDto>>, String> {
  TicketMessagesFamily._()
    : super(
        retry: null,
        name: r'ticketMessagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TicketMessagesProvider call(String ticketId) =>
      TicketMessagesProvider._(argument: ticketId, from: this);

  @override
  String toString() => r'ticketMessagesProvider';
}
