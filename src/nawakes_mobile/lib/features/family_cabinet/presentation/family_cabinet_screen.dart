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

    Future<void> addMemberWithPreset(String presetName) async {
      final created = await showAddFamilyMemberSheet(context, initialNickname: presetName);
      if (created == true) load();
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    final profiles = cabinet.value?.profiles ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('صيدلية البيت الذكية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('متابعة أدوية العائلة ومواعيد نفاذها', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showAddFamilyMemberSheet(context);
          if (created == true) load();
        },
        backgroundColor: AppColors.brand900,
        foregroundColor: Colors.white,
        label: const Text('إضافة شخص للعائلة', style: TextStyle(fontWeight: FontWeight.w700)),
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
                      // ── Value & Guide Banner ──────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1D4ED8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'إزاي صيدلية البيت بتفيدك؟',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E40AF)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'أضف أدوية والدك أو والدتك أو أطفالك اليومية، والنظام هيحسبلك تلقائياً فاضل كام يوم والدوا يخلص، وهينبهك قبل النفاذ بـ 5 أيام عشان تلحق تحجزه بضغطة واحدة من أقرب صيدلية بدون ما ينقطع العلاج.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.45),
                            ),
                          ],
                        ),
                      ),

                      // ── Quick Presets Rack ─────────────────────────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إضافة سريعة لشخص في العائلة:',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _PresetButton(label: 'والدي 🧓', onTap: () => addMemberWithPreset('والدي')),
                              const SizedBox(width: 8),
                              _PresetButton(label: 'والدتي 👵', onTap: () => addMemberWithPreset('والدتي')),
                              const SizedBox(width: 8),
                              _PresetButton(label: 'طفلي 👶', onTap: () => addMemberWithPreset('طفلي')),
                              const SizedBox(width: 8),
                              _PresetButton(label: 'نفسي 👤', onTap: () => addMemberWithPreset('نفسي')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Pending Invites ───────────────────────────────────────
                      if (pendingInvites.value.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'دعوات بانتظار موافقتك',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
                        const SizedBox(height: 12),
                      ],

                      // ── Profiles & Medicines ──────────────────────────────────
                      if (profiles.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.hairline.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.medication_outlined, size: 32, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'صيدلية بيتك فارغة حالياً',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'اضغط على أحد الأزرار السريعة بالأعلى (والدي، والدتي، طفلي، نفسي) لبدء تتبع الأدوية وحمايتهم من انقطاع الجرعات.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                              ),
                            ],
                          ),
                        )
                      else
                        ...profiles.expand(
                          (profile) => [
                            Padding(
                              padding: const EdgeInsets.only(top: 14, bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_rounded, size: 20, color: AppColors.brand900),
                                  const SizedBox(width: 6),
                                  Text(
                                    profile.nickname,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${profile.medications.length} أدوية',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            if (profile.medications.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.hairline),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                                    SizedBox(width: 8),
                                    Text('مفيش أدوية متتبعة لسه لهذا الشخص',
                                        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                                  ],
                                ),
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

class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.hairline),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
