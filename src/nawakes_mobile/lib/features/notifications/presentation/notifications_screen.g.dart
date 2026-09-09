// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(myNotifications)
final myNotificationsProvider = MyNotificationsProvider._();

final class MyNotificationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<NotificationDto>>,
          List<NotificationDto>,
          FutureOr<List<NotificationDto>>
        >
    with
        $FutureModifier<List<NotificationDto>>,
        $FutureProvider<List<NotificationDto>> {
  MyNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myNotificationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myNotificationsHash();

  @$internal
  @override
  $FutureProviderElement<List<NotificationDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<NotificationDto>> create(Ref ref) {
    return myNotifications(ref);
  }
}

String _$myNotificationsHash() => r'8f825265107465892d18a20f580d452ff8aa480f';
