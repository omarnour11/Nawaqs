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
import 'package:nawakes_mobile/features/profile/presentation/payment_methods_screen.dart';
import 'package:nawakes_mobile/core/theme/theme_mode_provider.dart';


const List<String> _standardAllergies = [
  'حساسية الصدر والربو الشعبي',
  'حساسية البنسلين ومشتقاته',
  'حساسية الأسبرين ومسكنات NSAIDs',
  'حساسية السلفا (السلفوناميدات)',
  'حساسية اللاكتوز (سكر الحليب)',
  'حساسية الجلوتين (القمح)',
  'حساسية المكسرات والفول السوداني',
  'حساسية البيض',
  'حساسية السمك والمأكولات البحرية',
  'حساسية الفراولة والموز',
  'حساسية الصبغات الوريدية واليود',
  'حساسية اللاتكس (المطاط)',
  'أكزيما وحساسية جلدية',
  'حساسية الجيوب الأنفية وحبوب اللقاح',
];

const List<String> _standardConditions = [
  'داء السكري النوع الأول',
  'داء السكري النوع الثاني',
  'ارتفاع ضغط الدم الشرياني',
  'قصور الشرايين التاجية والقلب',
  'ضعف وقصور عضلة القلب',
  'الربو الشعبي المزمن وحساسية الصدر',
  'السدة الرئوية المزمنة (COPD)',
  'الفشل الكلوي المزمن وقصور الكلى',
  'خمول وقصور الغدة الدرقية',
  'فرط نشاط الغدة الدرقية',
  'الروماتويد والتهاب المفاصل المزمن',
  'الصرع واضطراب الشحنات الكهربائية',
  'مرض كرون والتهاب الأمعاء',
  'التهاب القولون التقرحي',
  'متلازمة القولون العصبي المزمن',
  'النقرس وارتفاع حمض اليوريك',
  'ارتفاع دهون الدم والكوليسترول',
  'تليف والتهاب الكبد المزمن',
  'هشاشة العظام المزمنة',
  'التصلب المتعدد (MS)',
  'مرض باركنسون (الشلل الرعاش)',
  'الذئبة الحمراء الجهازية (SLE)',
  'ارتجاع المريء وقرحة المعدة المزمنة',
  'المياه الزرقاء بالعين (الجلوكوما)',
];

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
    final initialFreeNotes = useMemoized(
      () => _parseMedicalNotes(profile.medicalHistoryNotes).join('\n'),
      [profile.medicalHistoryNotes],
    );
    final notesCtrl = useTextEditingController(text: initialFreeNotes);

    // Structured health lists (parsed from medical history notes or fallback
    // to profile's explicit chronicConditions and knownAllergies).
    final initialConditions = useMemoized(() {
      final fromNotes = _parseConditions(profile.medicalHistoryNotes);
      if (fromNotes.isNotEmpty) return fromNotes;
      if (profile.chronicConditions != null && profile.chronicConditions!.trim().isNotEmpty) {
        return profile.chronicConditions!
            .split(RegExp(r'[,،\n]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
      }
      return <String>[];
    }, [profile.medicalHistoryNotes, profile.chronicConditions]);

    final initialAllergies = useMemoized(() {
      final fromNotes = _parseAllergies(profile.medicalHistoryNotes);
      if (fromNotes.isNotEmpty) return fromNotes;
      if (profile.knownAllergies != null && profile.knownAllergies!.trim().isNotEmpty) {
        return profile.knownAllergies!
            .split(RegExp(r'[,،\n]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
      }
      return <String>[];
    }, [profile.medicalHistoryNotes, profile.knownAllergies]);

    final conditions = useState<List<String>>(initialConditions);
    final allergies = useState<List<String>>(initialAllergies);

    final newConditionCtrl = useTextEditingController();
    final newAllergyCtrl = useTextEditingController();
    final gender = useState<String>(profile.gender ?? 'ذكر');
    final ageCtrl = useTextEditingController(text: profile.age != null ? profile.age.toString() : '');

    Future<void> save() async {
      saving.value = true;
      try {
        // Compose notes = structured lists + free text (distinct and deduplicated)
        final distinctConditions = conditions.value
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        final distinctAllergies = allergies.value
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        final distinctFreeNotes = _parseMedicalNotes(notesCtrl.text);

        final buf = StringBuffer();
        if (distinctConditions.isNotEmpty) {
          buf.writeln('أمراض: ${distinctConditions.join('، ')}');
        }
        if (distinctAllergies.isNotEmpty) {
          buf.writeln('حساسية: ${distinctAllergies.join('، ')}');
        }
        if (distinctFreeNotes.isNotEmpty) {
          buf.write(distinctFreeNotes.join('\n'));
        }

        final savedNotes = buf.toString().trim();
        await ref.read(apiClientProvider).updateProfile(UpdateProfileRequest(
              fullName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
              phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
              medicalHistoryNotes: savedNotes,
              gender: gender.value,
              age: int.tryParse(ageCtrl.text.trim()),
              chronicConditions: distinctConditions.join('، '),
              knownAllergies: distinctAllergies.join('، '),
            ));
        ref.invalidate(profileControllerProvider);
        editing.value = false;
        // Re-parse from the saved notes so chips reflect exactly what's stored
        conditions.value = _parseConditions(savedNotes);
        allergies.value = _parseAllergies(savedNotes);
        notesCtrl.text = _parseMedicalNotes(savedNotes).join('\n');
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: EdgeInsets.only(bottom: editing.value ? 100 : 24),
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
                      decoration: BoxDecoration(
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
                                Text(
                                    (profile.fullName != null &&
                                            profile.fullName!.trim().isNotEmpty)
                                        ? profile.fullName!
                                        : 'مستخدم نواقص',
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

              // ── Demographics card (Gender & Age) ────────────────────────
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
                    const SectionLabel('البيانات الحيوية (للأمان والجرعات)'),
                    const SizedBox(height: 10),
                    if (editing.value) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('النوع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => gender.value = 'ذكر',
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: gender.value == 'ذكر' ? AppColors.brand900 : const Color(0xFFF1F3F5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text('ذكر 👨',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: gender.value == 'ذكر' ? Colors.white : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => gender.value = 'أنثى',
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: gender.value == 'أنثى' ? AppColors.brand900 : const Color(0xFFF1F3F5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text('أنثى 👩',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: gender.value == 'أنثى' ? Colors.white : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('العمر بالسنين', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: ageCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'مثال: 32',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Icon(gender.value == 'أنثى' ? Icons.female_rounded : Icons.male_rounded,
                              color: AppColors.accentBlue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${gender.value}${ageCtrl.text.isNotEmpty ? " · ${ageCtrl.text} سنة" : ""}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
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
                        (v) {
                          final trimmed = v.trim();
                          if (trimmed.isNotEmpty && !conditions.value.contains(trimmed)) {
                            conditions.value = [...conditions.value, trimmed];
                          }
                        })
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
                        (v) {
                          final trimmed = v.trim();
                          if (trimmed.isNotEmpty && !allergies.value.contains(trimmed)) {
                            allergies.value = [...allergies.value, trimmed];
                          }
                        })
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
                      InfoCell(
                        label: 'ملاحظات طبية',
                        value: _parseMedicalNotes(profile.medicalHistoryNotes).isNotEmpty
                            ? _parseMedicalNotes(profile.medicalHistoryNotes).join('\n')
                            : '—',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Current medications (الأدوية الحالية) ───────────────────
                            // ── Pharmacist Privacy Sharing Toggle ──────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.privacy_tip_outlined,
                        size: 22, color: AppColors.accentBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'هل تسمح للصيدلي برؤية أدويتك الحالية؟',
                            style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'لتمكين الصيدلي من فحص التداخلات والجرعات عند تنفيذ الحجز بأمان.',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: profile.allowPharmacistViewActiveMedications,
                      activeTrackColor: AppColors.brand900,
                      onChanged: (val) async {
                        try {
                          await ref
                              .read(profileControllerProvider.notifier)
                              .updateProfile(
                                allowPharmacistViewActiveMedications: val,
                              );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(describeApiError(e))),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const MyMedicationsSection(),
              const SizedBox(height: 12),

              // ── Quick links ─────────────────────────────────────────────
              _LinkCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'طرق الدفع ومحفظة الحساب (إنستاباي، فودافون كاش، الفيزا)',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              _LinkCard(
                icon: Icons.medication_liquid_outlined,
                label: 'دولاب دوا العيلة',
                onTap: () => context.push('/family-cabinet'),
              ),
              const SizedBox(height: 8),

              // ── Dark Mode Toggle (شكل هلال 🌙) ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: NawaqsColors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.nightlight_round,
                        color: NawaqsColors.teal,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'الوضع الليلي (Dark Mode)',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'مظهر مريح للعين وألوان داكنة راقية',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: ref.watch(themeModeProvider) == ThemeMode.dark,
                      activeTrackColor: NawaqsColors.teal,
                      onChanged: (_) => ref.read(themeModeProvider.notifier).toggleTheme(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (!editing.value)
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('تسجيل الخروج'),
                        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('إلغاء'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.dangerText,
                            ),
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: const Text('تسجيل الخروج'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    }
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
              const SizedBox(height: 16),

              // ── Delete Account ("حذف حسابي نهائياً") ──
              if (!editing.value)
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showDeleteAccountDialog(context, ref),
                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                    label: const Text(
                      'حذف حسابي نهائياً',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      ),
      bottomNavigationBar: editing.value
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: const Border(top: BorderSide(color: AppColors.hairline)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: saving.value ? null : save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: saving.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'حفظ التغييرات',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  static List<String> _parseSections(String? notes, String prefix) {
    if (notes == null) return [];
    final result = <String>{};
    for (final line in notes.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith(prefix)) {
        final items = trimmed
            .substring(prefix.length)
            .split(RegExp(r'[،,]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        result.addAll(items);
      }
    }
    return result.toList();
  }

  static List<String> _parseConditions(String? notes) => _parseSections(notes, 'أمراض:');
  static List<String> _parseAllergies(String? notes) => _parseSections(notes, 'حساسية:');

  static List<String> _parseMedicalNotes(String? notes) {
    if (notes == null) return [];
    final result = <String>{};
    for (final rawLine in notes.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('أمراض:') || trimmed.startsWith('حساسية:')) continue;
      result.add(trimmed);
    }
    return result.toList();
  }

  String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .trim()
        .toLowerCase();
  }

  void _addDialog(BuildContext context, String title, TextEditingController ctrl,
      ValueChanged<String> onAdd) {
    final isAllergy = title.contains('حساسية');
    final standards = isAllergy ? _standardAllergies : _standardConditions;
    final queryNotifier = ValueNotifier<String>('');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'إضافة $title',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onChanged: (val) => queryNotifier.value = val,
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        onAdd(v.trim());
                        ctrl.clear();
                        Navigator.pop(dialogContext);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: isAllergy
                          ? 'اكتب الحساسية (مثلاً: بنسلين، صدر...)'
                          : 'اكتب المرض (مثلاً: ضغط، سكر...)',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: queryNotifier,
                    builder: (context, rawQuery, _) {
                      final normQuery = _normalizeArabic(rawQuery);
                      if (normQuery.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'ابدأ بكتابة اسم المرض للبحث في قائمة الأمراض المعيارية…',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textHint),
                          ),
                        );
                      }

                      final matches = standards
                          .where((s) => _normalizeArabic(s).contains(normQuery))
                          .take(6)
                          .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            matches.isNotEmpty
                                ? 'المصطلح الطبي المعياري المقترح (اضغط للاختيار):'
                                : 'لا يوجد اقتراح معياري مطابق — يمكنك الإضافة بالضغط على الزر أدناه.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: matches.isNotEmpty ? FontWeight.w700 : FontWeight.normal,
                              color: matches.isNotEmpty ? AppColors.textSecondary : AppColors.textHint,
                            ),
                          ),
                          if (matches.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: matches.map((match) {
                                return ActionChip(
                                  avatar: const Icon(Icons.medical_services_outlined,
                                      size: 14, color: AppColors.brand700),
                                  label: Text(
                                    match,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.brand900,
                                    ),
                                  ),
                                  backgroundColor: AppColors.brand700.withValues(alpha: 0.08),
                                  side: BorderSide(
                                    color: AppColors.brand700.withValues(alpha: 0.25),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onPressed: () {
                                    ctrl.text = match;
                                    onAdd(match);
                                    ctrl.clear();
                                    Navigator.pop(dialogContext);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ctrl.clear();
                Navigator.pop(dialogContext);
              },
              child: const Text('إلغاء'),
            ),
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
        );
      },
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


void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalCtx) {
      return HookConsumer(
        builder: (ctx, ref, _) {
          final textCtrl = useTextEditingController();
          final isMatched = useState(false);
          final isDeleting = useState(false);

          String norm(String s) => s
              .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
              .replaceAll(RegExp(r'[أإآا]'), 'ا')
              .replaceAll(RegExp(r'[يى]'), 'ي')
              .replaceAll(RegExp(r'[ةه]'), 'ه')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim()
              .toLowerCase();

          void checkText(String val) {
            isMatched.value = norm(val) == norm('لو احتجت نواقص تاني هجيلكم');
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'حذف الحساب نهائياً',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'يؤسفنا فراقك جداً! عند حذف الحساب، سيتم مسح بياناتك الشخصية وتاريخ الروشتات وسجل الطلبات نهائياً وفقاً لقانون حماية البيانات.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'لتأكيد الحذف النهائي، اكتب العبارة التالية بدقة:',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC62828),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'لو احتجت نواقص تاني هجيلكم',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFB71C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: textCtrl,
                    onChanged: checkText,
                    decoration: InputDecoration(
                      hintText: 'اكتب العبارة هنا لتأكيد الحذف...',
                      prefixIcon: Icon(
                        isMatched.value ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                        color: isMatched.value ? Colors.green : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: (isMatched.value && !isDeleting.value)
                        ? () async {
                            isDeleting.value = true;
                            try {
                              await ref.read(authControllerProvider.notifier).logout();
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم حذف الحساب بنجاح. نتمنى لك دوام الصحة والعافية!'),
                                    backgroundColor: NawaqsColors.tealDark,
                                  ),
                                );
                                context.go('/login');
                              }
                            } catch (_) {
                              isDeleting.value = false;
                            }
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      disabledBackgroundColor: Colors.grey.shade200,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isDeleting.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'تأكيد حذف الحساب نهائياً',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}