import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart' show apiClientProvider;
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart' show describeApiError;
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';

/// Bottom sheet to create a tracked family member (cabinet) and optionally
/// invite a caregiver by phone. Returns true when a cabinet was created.
Future<bool> showAddFamilyMemberSheet(BuildContext context, {String? initialNickname}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddFamilyMemberSheet(initialNickname: initialNickname),
  );
  return result ?? false;
}

class _AddFamilyMemberSheet extends HookConsumerWidget {
  final String? initialNickname;
  const _AddFamilyMemberSheet({this.initialNickname});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = useTextEditingController(text: initialNickname ?? '');
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

        final invitePhone = phone.text.trim();
        if (invitePhone.isNotEmpty) {
          await ref.read(apiClientProvider).inviteCaregiver(
                profileId,
                InviteCaregiverRequest(invitedPhoneNumber: invitePhone),
              );
        }

        if (context.mounted) Navigator.of(context).pop(true);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(e))));
        }
      } finally {
        submitting.value = false;
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'إضافة فرد لمتابعة الأدوية',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'مثل: والدي، والدتي، طفلي، نفسي — لمتابعة تواريخ نفاذ الأدوية بانتظام.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nickname,
            autofocus: (initialNickname == null || initialNickname!.isEmpty),
            decoration: const InputDecoration(
              labelText: 'الاسم أو صلة القرابة *',
              hintText: 'مثال: والدي، والدتي، طفلي',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'مشاركة المتابعة مع مرافق (اختياري)',
              hintText: 'رقم هاتف المرافق في نواقص',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: submitting.value ? null : submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: submitting.value
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('حفظ وبدء المتابعة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
