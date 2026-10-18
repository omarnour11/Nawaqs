import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart' show apiClientProvider;
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart' show describeApiError;
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';

import 'medication_depletion_card.dart';
import 'add_family_member_sheet.dart';

class FamilyCabinetScreen extends HookConsumerWidget {
  const FamilyCabinetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cabinet = useState<FamilyCabinetResponseModel?>(null);
    final loading = useState(true);
    final error = useState<String?>(null);
    final pendingInvites = useState<List<PendingCaregiverInviteModel>>(const []);

    Future<void> load() async {
      loading.value = true;
      error.value = null;
      try {
        final api = ref.read(apiClientProvider);
        final res = await api.getFamilyCabinet();
        cabinet.value = res;
        // Pending invites are part of the same screen: a caregiver needs to be
        // able to accept without hunting through notifications.
        pendingInvites.value = await api.getPendingCaregiverInvites();
      } catch (e) {
        error.value = describeApiError(e);
      } finally {
        loading.value = false;
      }
    }

    Future<void> acceptInvite(PendingCaregiverInviteModel invite) async {
      try {
        await ref.read(apiClientProvider).acceptCaregiverInvite(invite.linkId);
        await load();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('دولاب دوا العيلة'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showAddFamilyMemberSheet(context);
          if (created == true) load();
        },
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
        label: const Text('إضافة شخص'),
        icon: const Icon(Icons.person_add_alt_1),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: loading.value
            ? const Center(child: CircularProgressIndicator())
            : error.value != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(child: Text(error.value!, textAlign: TextAlign.center)),
                      const SizedBox(height: 12),
                      Center(
                        child: OutlinedButton(onPressed: load, child: const Text('إعادة المحاولة')),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      if (pendingInvites.value.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'دعوات بانتظار موافقتك',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                        ...pendingInvites.value.map(
                          (invite) => Card(
                            color: AppColors.card,
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.hairline),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_add_alt_1),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'دعوة لمتابعة ${invite.familyProfileNickname}',
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () => acceptInvite(invite),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.accentBlue),
                                    child: const Text('قبول'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (cabinet.value == null || cabinet.value!.profiles.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 100),
                          child: Center(
                            child: Text('مفيش حد متتبع لسه',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        )
                      else
                        ...cabinet.value!.profiles.expand(
                          (profile) => [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                profile.nickname,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (profile.medications.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text('مفيش أدوية متتبعة',
                                    style: TextStyle(color: AppColors.textSecondary)),
                              )
                            else
                              ...profile.medications.map(
                                (m) => MedicationDepletionCard(
                                  medication: m,
                                  onChanged: load,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
      ),
    );
  }
}
