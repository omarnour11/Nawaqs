// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches and caches the current user's profile.
/// Invalidated after a successful update so the UI re-fetches fresh data.

@ProviderFor(ProfileController)
final profileControllerProvider = ProfileControllerProvider._();

/// Fetches and caches the current user's profile.
/// Invalidated after a successful update so the UI re-fetches fresh data.
final class ProfileControllerProvider
    extends $AsyncNotifierProvider<ProfileController, ProfileResponse> {
  /// Fetches and caches the current user's profile.
  /// Invalidated after a successful update so the UI re-fetches fresh data.
  ProfileControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileControllerHash();

  @$internal
  @override
  ProfileController create() => ProfileController();
}

String _$profileControllerHash() => r'8da2f7d422fb156913cd4e6bc1142b1f16c5ce65';

/// Fetches and caches the current user's profile.
/// Invalidated after a successful update so the UI re-fetches fresh data.

abstract class _$ProfileController extends $AsyncNotifier<ProfileResponse> {
  FutureOr<ProfileResponse> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ProfileResponse>, ProfileResponse>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProfileResponse>, ProfileResponse>,
              AsyncValue<ProfileResponse>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
