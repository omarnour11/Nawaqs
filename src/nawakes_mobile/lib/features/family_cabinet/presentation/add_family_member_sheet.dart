import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart' show apiClientProvider;
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart' show describeApiError;
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';

/// Bottom sheet to create a tracked family member (cabinet) and optionally
/// invite a caregiver by phone. Returns true when a cabinet was created.
Future<bool> showAddFamilyMemberSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddFamilyMemberSheet(),
  );
  return result ?? false;
}

class _AddFamilyMemberSheet extends HookConsumerWidget {
  const _AddFamilyMemberSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = useTextEditingController();
    final phone = useTextEditingController();
    final submitting = useState(false);
    // Created once per sheet: if the invite below fails (e.g. the phone number
    // has no account), retrying must reuse this profile instead of adding a
    // duplicate cabinet entry.
    final createdProfileId = useState<String?>(null);

    Future<void> submit() async {
      if (submitting.value || nickname.text.trim().isEmpty) return;
      submitting.value = true;
      try {
        // Cairo-area default home coordinates; the user's last known location
        // refines this when location permission is granted.
        var profileId = createdProfileId.value;
        if (profileId == null) {
          final created = await ref.read(apiClientProvider).createFamilyProfile(
                CreateFamilyProfileRequest(
                  nickname: nickname.text.trim(),
                  homeLatitude: 30.0444,
                  homeLongitude: 31.2357,
                ),
              );
          profileId = created.id;
          createdProfileId.value = profileId;
        }
        if (phone.text.trim().isNotEmpty) {
          await ref.read(apiClientProvider).inviteCaregiver(
                profileId,
                InviteCaregiverRequest(invitedPhoneNumber: phone.text.trim()),
              );
        }
        if (context.mounted) Navigator.of(context).pop(true);
      } catch (e) {
        submitting.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(e))));
        }
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('إضافة شخص للعيلة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            controller: nickname,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'الاسم (مثال: والدي)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'رقم موبايل مقدم الرعاية (اختياري)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: submitting.value ? null : submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accentBlue),
              child: submitting.value
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ'),
            ),
          ),
        ],
      ),
    );
  }
}
