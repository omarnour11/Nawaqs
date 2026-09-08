import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/profile/data/profile_models.dart';

part 'profile_controller.g.dart';

/// Fetches and caches the current user's profile.
/// Invalidated after a successful update so the UI re-fetches fresh data.
@riverpod
class ProfileController extends _$ProfileController {
  @override
  FutureOr<ProfileResponse> build() async {
    final client = ref.read(apiClientProvider);
    return client.getProfile();
  }

  /// Sends a PATCH with only the non-null fields provided.
  /// [fullName], [phone], [medicalHistoryNotes] — pass null to skip a field.
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? medicalHistoryNotes,
  }) async {
    final client = ref.read(apiClientProvider);
    await client.updateProfile(UpdateProfileRequest(
      fullName: fullName,
      phone: phone,
      medicalHistoryNotes: medicalHistoryNotes,
    ));
    // Re-fetch so the screen shows the freshly saved data
    ref.invalidateSelf();
    await future; // wait for the new fetch to complete before returning
  }
}
