import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/profile/data/profile_models.dart';
import 'package:nawakes_mobile/features/profile/presentation/profile_controller.dart';
import 'package:nawakes_mobile/features/profile/presentation/medications_section.dart';
import 'package:nawakes_mobile/features/favorites/data/favorite_models.dart';

/// الحساب — profile + medical record (chronic conditions, allergies, notes).
class ProfileScreen extends HookConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: profileState.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر تحميل الحساب',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(profileControllerProvider),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
          data: (profile) => RefreshIndicator(
            color: AppColors.accentBlue,
            onRefresh: () async => ref.invalidate(profileControllerProvider),
            child: _ProfileBody(profile: profile),
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends HookConsumerWidget {
  final ProfileResponse profile;
  const _ProfileBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editing = useState(false);
    final saving = useState(false);
    final nameCtrl = useTextEditingController(text: profile.fullName ?? '');
    final phoneCtrl = useTextEditingController(text: profile.phone ?? '');
    final notesCtrl =
        useTextEditingController(text: profile.medicalHistoryNotes ?? '');

    // Structured health lists (parsed from the encrypted questionnaire stored
    // at registration; profile notes act as the editable source).
    final conditions = useState<List<String>>(
        _parseList(profile.medicalHistoryNotes, 'أمراض:'));
    final allergies =
        useState<List<String>>(_parseList(profile.medicalHistoryNotes, 'حساسية:'));

    final newConditionCtrl = useTextEditingController();
    final newAllergyCtrl = useTextEditingController();

    Future<void> save() async {
      saving.value = true;
      try {
        // Compose notes = structured lists + free text
        final buf = StringBuffer();
        if (conditions.value.isNotEmpty) buf.writeln('أمراض: ${conditions.value.join('، ')}');
        if (allergies.value.isNotEmpty) buf.writeln('حساسية: ${allergies.value.join('، ')}');
        if (notesCtrl.text.trim().isNotEmpty) buf.write(notesCtrl.text.trim());

        await ref.read(profileControllerProvider.notifier).updateProfile(
              fullName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
              phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
              medicalHistoryNotes: buf.toString().trim(),
            );
        editing.value = false;
        // Re-parse from the saved notes so chips reflect exactly what's stored
        conditions.value = _parseList(profile.medicalHistoryNotes, 'أمراض:');
        allergies.value = _parseList(profile.medicalHistoryNotes, 'حساسية:');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('التغييرات اتحفظت.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      } finally {
        saving.value = false;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        NawaqsTopBar(
          eyebrow: 'نواقص / الحساب',
          title: 'الملف الطبي',
          showBell: true,
          onBell: () => context.push('/notifications'),
          extraActions: [
            TextButton(
              onPressed: () => editing.value = !editing.value,
              child: Text(editing.value ? 'إلغاء' : 'تعديل'),
            ),
          ],
        ),
        const ScreenSubtitle('حافظ على تحديثه عشان الصيدلي يقدر يخدمك بأمان'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Identity card ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.accentBlueBg,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (profile.fullName?.isNotEmpty == true)
                            ? profile.fullName!.trim().substring(0, 1)
                            : 'م',
                        style: const TextStyle(
                            color: AppColors.accentBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: editing.value
                          ? TextField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                hintText: 'الاسم بالكامل',
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(profile.fullName ?? 'مستخدم نواقص',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(profile.email,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Chronic conditions ──────────────────────────────────────
              _ChipsCard(
                sectionLabel: 'الأمراض المزمنة',
                chips: conditions.value
                    .map((c) => _removableChip(c, ChipTone.danger,
                        () => conditions.value = [...conditions.value]..remove(c),
                        enabled: editing.value))
                    .toList(),
                onAdd: editing.value
                    ? () => _addDialog(context, 'أمراض مزمنة', newConditionCtrl,
                        (v) => conditions.value = [...conditions.value, v])
                    : null,
                emptyText: 'مفيش أمراض مزمنة مسجلة',
              ),
              const SizedBox(height: 12),

              // ── Allergies ───────────────────────────────────────────────
              _ChipsCard(
                sectionLabel: 'الحساسية',
                chips: allergies.value
                    .map((a) => _removableChip(a, ChipTone.warning,
                        () => allergies.value = [...allergies.value]..remove(a),
                        enabled: editing.value))
                    .toList(),
                onAdd: editing.value
                    ? () => _addDialog(
                        context, 'حساسية', newAllergyCtrl,
                        (v) => allergies.value = [...allergies.value, v])
                    : null,
                emptyText: 'مفيش حساسية مسجلة',
              ),
              const SizedBox(height: 12),

              // ── Account details ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('بيانات التواصل'),
                    const SizedBox(height: 10),
                    if (editing.value) ...[
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(hintText: 'رقم الموبايل'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            hintText: 'ملاحظات طبية إضافية'),
                      ),
                    ] else ...[
                      InfoCell(label: 'الموبايل', value: profile.phone ?? '—'),
                      const SizedBox(height: 8),
                      InfoCell(label: 'ملاحظات طبية', value: profile.medicalHistoryNotes ?? '—'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Current medications (الأدوية الحالية) ───────────────────
              const MyMedicationsSection(),
              const SizedBox(height: 12),

              // ── Quick links ─────────────────────────────────────────────
              _LinkCard(
                icon: Icons.favorite_border_rounded,
                label: 'الصيدليات المفضلة',
                onTap: () => _showFavorites(context, ref),
              ),
              const SizedBox(height: 8),
              _LinkCard(
                icon: Icons.notifications_none_rounded,
                label: 'الإشعارات',
                onTap: () => context.push('/notifications'),
              ),
              const SizedBox(height: 8),
              _LinkCard(
                icon: Icons.notifications_active_outlined,
                label: 'تنبيهات التوفر',
                onTap: () => context.push('/alerts'),
              ),
              const SizedBox(height: 16),

              if (editing.value)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving.value ? null : save,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          AppColors.brand900, // dark teal "save changes" per mockup
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                    child: saving.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('حفظ التغييرات'),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('تسجيل الخروج'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerText,
                    side: const BorderSide(color: AppColors.dangerBg, width: 1.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static List<String> _parseList(String? notes, String key) {
    if (notes == null) return [];
    for (final line in notes.split('\n')) {
      if (line.trim().startsWith(key)) {
        return line
            .substring(key.length)
            .split('،')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  void _addDialog(BuildContext context, String title, TextEditingController ctrl,
      ValueChanged<String> onAdd) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text('إضافة $title')),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  onAdd(v.trim());
                  Navigator.pop(dialogContext);
                }
              },
              decoration: const InputDecoration(hintText: 'اكتب الاسم'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                ctrl.clear();
                Navigator.pop(dialogContext);
              },
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                onAdd(ctrl.text.trim());
                ctrl.clear();
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showFavorites(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => _FavoritesSheet(scrollController: controller),
      ),
    );
  }
}

Widget _removableChip(String label, ChipTone tone, VoidCallback onRemove,
    {required bool enabled}) {
  final (bg, fg) = switch (tone) {
    ChipTone.danger => (AppColors.dangerBg, AppColors.dangerText),
    ChipTone.warning => (AppColors.warningBg, AppColors.warningText),
    ChipTone.success => (AppColors.successBg, AppColors.successText),
    ChipTone.neutral => (AppColors.accentBlueBg, AppColors.accentBlue),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        if (enabled) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: fg),
          ),
        ],
      ],
    ),
  );
}

class _ChipsCard extends StatelessWidget {
  final String sectionLabel;
  final List<Widget> chips;
  final VoidCallback? onAdd;
  final String emptyText;

  const _ChipsCard({
    required this.sectionLabel,
    required this.chips,
    this.onAdd,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(sectionLabel),
          const SizedBox(height: 10),
          if (chips.isEmpty && onAdd == null)
            Text(emptyText,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...chips,
                if (onAdd != null)
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlueBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('+ إضافة',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentBlue)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;
  const _LinkCard({required this.label, required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.chevron_left_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesSheet extends HookConsumerWidget {
  final ScrollController scrollController;
  const _FavoritesSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesFuture =
        useMemoized(() => ref.read(apiClientProvider).getMyFavorites(), const []);
    final snapshot = useFuture(favoritesFuture);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text('الصيدليات المفضلة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        if (snapshot.connectionState == ConnectionState.waiting)
          const Expanded(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.accentBlue)))
        else if (snapshot.hasError || (snapshot.data ?? []).isEmpty)
          const Expanded(
            child: Center(
              child: Text('مفيش صيدليات مفضلة — دوس على القلب في تفاصيل الصيدلية.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, i) {
                final FavoritePharmacyDto f = snapshot.data![i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.fieldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    children: [
                      const IconTile(Icons.storefront_outlined,
                          bg: AppColors.accentBlueBg, color: AppColors.accentBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.name,
                                style: const TextStyle(
                                    fontSize: 13.5, fontWeight: FontWeight.w700)),
                            Text(f.city,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
