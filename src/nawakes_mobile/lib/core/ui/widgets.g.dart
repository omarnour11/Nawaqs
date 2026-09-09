// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widgets.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live unread-notifications count for the bell badge; 0 on failure.

@ProviderFor(UnreadNotificationsCount)
final unreadNotificationsCountProvider = UnreadNotificationsCountProvider._();

/// Live unread-notifications count for the bell badge; 0 on failure.
final class UnreadNotificationsCountProvider
    extends $AsyncNotifierProvider<UnreadNotificationsCount, int> {
  /// Live unread-notifications count for the bell badge; 0 on failure.
  UnreadNotificationsCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadNotificationsCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadNotificationsCountHash();

  @$internal
  @override
  UnreadNotificationsCount create() => UnreadNotificationsCount();
}

String _$unreadNotificationsCountHash() =>
    r'8d3c53de9f050cc5e5dbe6e0ab23b1abf483e9ca';

/// Live unread-notifications count for the bell badge; 0 on failure.

abstract class _$UnreadNotificationsCount extends $AsyncNotifier<int> {
  FutureOr<int> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
