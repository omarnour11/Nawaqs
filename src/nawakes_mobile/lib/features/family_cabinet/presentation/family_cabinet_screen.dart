import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart' show apiClientProvider;
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart' show describeApiError;
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';

import 'medication_depletion_card.dart';
import 'add_family_member_sheet.dart';
import 'add_family_medication_sheet.dart';

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
      if (created == true) {
        await load();
        if (context.mounted && cabinet.value?.profiles.isNotEmpty == true) {
          final p = cabinet.value!.profiles.firstWhere(
            (e) => e.nickname == presetName,
            orElse: () => cabinet.value!.profiles.last,
          );
          final added = await showAddFamilyMedicationSheet(
            context,
            profileId: p.id,
            profileNickname: p.nickname,
          );
          if (added == true) load();
        }
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    final profiles = cabinet.value?.profiles ?? [];

    return Scaffold(
      backgroundColor: NawaqsColors.cream,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'صيدلية البيت الذكية',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: NawaqsColors.tealDark,
              ),
            ),
            Text(
              'متابعة أدوية العائلة ومواعيد نفاذها',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        backgroundColor: NawaqsColors.cream,
        foregroundColor: NawaqsColors.tealDark,
        elevation: 0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showAddFamilyMemberSheet(context);
          if (created == true) load();
        },
        backgroundColor: NawaqsColors.tealDark,
        foregroundColor: Colors.white,
        elevation: 3,
        label: const Text('إضافة شخص للعائلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
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
                          color: NawaqsColors.mint,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: NawaqsColors.mintDeep),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const NuqousMascot.searching(height: 58),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'إزاي صيدلية البيت بتفيدك؟',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: NawaqsColors.tealDark,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'أضف أدوية والدك أو والدتك أو أطفالك اليومية، والنظام هيحسبلك تلقائياً فاضل كام يوم والدوا يخلص، وهينبهك قبل النفاذ بـ 5 أيام عشان تلحق تحجزه بضغطة واحدة من أقرب صيدلية بدون ما ينقطع العلاج.',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: NawaqsColors.tealDark,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
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
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: NawaqsColors.tealDark,
                            ),
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
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const NuqousMascot.welcome(height: 104),
                              const SizedBox(height: 12),
                              const NawaqssSingleMedSticker(
                                label: 'دوا واحد بس لكل العائلة 🏠',
                                fontSize: 12,
                                enableTilt: true,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'صيدلية بيتك فارغة حالياً',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: NawaqsColors.tealDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'اضغط على أحد الأزرار السريعة بالأعلى (والدي، والدتي، طفلي، نفسي) لبدء تتبع الأدوية وحمايتهم من انقطاع الجرعات.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...profiles.expand(
                          (profile) => [
                            Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_rounded, size: 20, color: NawaqsColors.tealDark),
                                  const SizedBox(width: 6),
                                  Text(
                                    profile.nickname,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: NawaqsColors.tealDark,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${profile.medications.length} أدوية)',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final added = await showAddFamilyMedicationSheet(
                                        context,
                                        profileId: profile.id,
                                        profileNickname: profile.nickname,
                                      );
                                      if (added == true) load();
                                    },
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                                    label: const Text(
                                      'إضافة دواء',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: NawaqsColors.tealDark,
                                      backgroundColor: NawaqsColors.mint,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (profile.medications.isEmpty)
                              InkWell(
                                onTap: () async {
                                  final added = await showAddFamilyMedicationSheet(
                                    context,
                                    profileId: profile.id,
                                    profileNickname: profile.nickname,
                                  );
                                  if (added == true) load();
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: NawaqsColors.mintDeep),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.add_circle_rounded, size: 22, color: NawaqsColors.teal),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'مفيش أدوية متتبعة لسه لهذا الشخص · اضغط هنا لإضافة أول دواء 💊',
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: NawaqsColors.tealDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NawaqsColors.mintDeep),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: NawaqsColors.tealDark,
            ),
          ),
        ),
      ),
    );
  }
}
