import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/auth/data/auth_models.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';

const List<String> _patientCommonConditions = [
  'ضغط الدم',
  'السكري',
  'حساسية الصدر',
  'الربو',
  'أمراض القلب',
  'قصور الكلى',
];

const List<String> _patientCommonAllergies = [
  'بنسلين',
  'سلفا',
  'أسبرين',
  'مسكنات NSAIDs',
  'حساسية الصدر',
  'أكزيما',
];

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final pharmacyFormKey = useMemoized(GlobalKey<FormState>.new);
    final isPharmacy = useState(false); // false = Patient, true = PharmacyOwner
    final step = useState(0); // 0 = account info, 1 = details (health or pharmacy)
    final authState = ref.watch(authControllerProvider);

    // Account controllers
    final nameCtrl = useTextEditingController();
    final emailCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();
    final passwordCtrl = useTextEditingController();
    final confirmCtrl = useTextEditingController();
    final obscure = useState(true);

    // Patient demographics & clinical attributes
    final selectedGender = useState('ذكر');
    final ageCtrl = useTextEditingController();
    final selectedAllergies = useState<Set<String>>({});
    final selectedConditions = useState<Set<String>>({});
    final isSubmittingPatient = useState(false);

    // Patient health controllers
    final allergiesCtrl = useTextEditingController();
    final conditionsCtrl = useTextEditingController();

    final isLoading = authState.isLoading || isSubmittingPatient.value;

    // Pharmacy controllers
    final pharmacyNameCtrl = useTextEditingController();
    final cityCtrl = useTextEditingController();
    final addressCtrl = useTextEditingController();
    final licenseCtrl = useTextEditingController();
    final pharmacyLocation = useState<Position?>(null);
    final isLocatingPharmacy = useState(false);

    Future<void> fetchPharmacyLocation({bool showFeedback = false}) async {
      isLocatingPharmacy.value = true;
      try {
        if (!await Geolocator.isLocationServiceEnabled()) {
          if (showFeedback && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('يرجى تفعيل خدمة الموقع (GPS) في الهاتف')),
            );
          }
          return;
        }
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.deniedForever) {
          if (showFeedback && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('إذن الموقع مرفوض في إعدادات الهاتف')),
            );
          }
          return;
        }
        if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null && pharmacyLocation.value == null) {
            pharmacyLocation.value = last;
          }
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
          );
          pharmacyLocation.value = pos;
          if (showFeedback && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تحديد موقع الصيدلية بنجاح')),
            );
          }
        }
      } catch (_) {
      } finally {
        isLocatingPharmacy.value = false;
      }
    }

    // Auto-fetch location when switching to pharmacy registration
    useEffect(() {
      if (isPharmacy.value && pharmacyLocation.value == null) {
        fetchPharmacyLocation();
      }
      return null;
    }, [isPharmacy.value]);

    ref.listen<AsyncValue<AuthState>>(authControllerProvider, (_, next) {
      if (!next.isLoading && next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeApiError(next.error!))),
        );
      }
    });

    void toggleCondition(String cond) {
      final updated = Set<String>.from(selectedConditions.value);
      if (updated.contains(cond)) {
        updated.remove(cond);
      } else {
        updated.add(cond);
      }
      selectedConditions.value = updated;
    }

    void toggleAllergy(String allergy) {
      final updated = Set<String>.from(selectedAllergies.value);
      if (updated.contains(allergy)) {
        updated.remove(allergy);
      } else {
        updated.add(allergy);
      }
      selectedAllergies.value = updated;
    }

    List<String> combineItems(Set<String> selectedChips, String raw) {
      final items = <String>{...selectedChips};
      if (raw.trim().isNotEmpty) {
        items.addAll(
          raw
              .split(RegExp(r'[,،\n]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      }
      return items.toList();
    }

    Future<void> submitPatient({bool skipHealth = false}) async {
      if (formKey.currentState != null && !formKey.currentState!.validate()) return;
      if (nameCtrl.text.trim().isEmpty ||
          emailCtrl.text.trim().isEmpty ||
          passwordCtrl.text.isEmpty) {
        return;
      }
      isSubmittingPatient.value = true;
      try {
        final conditionsList = skipHealth
            ? <String>[]
            : combineItems(selectedConditions.value, conditionsCtrl.text);
        final allergiesList = skipHealth
            ? <String>[]
            : combineItems(selectedAllergies.value, allergiesCtrl.text);

        final req = RegisterRequest(
          email: emailCtrl.text.trim(),
          password: passwordCtrl.text,
          fullName: nameCtrl.text.trim(),
          role: 'Patient',
          gender: selectedGender.value,
          age: int.tryParse(ageCtrl.text.trim()),
          chronicConditions:
              conditionsList.isNotEmpty ? conditionsList.join('، ') : null,
          knownAllergies:
              allergiesList.isNotEmpty ? allergiesList : null,
          chronicIllnesses:
              conditionsList.isNotEmpty ? conditionsList : null,
        );

        await ref.read(apiClientProvider).register(req);
        await ref.read(authControllerProvider.notifier).login(
              emailCtrl.text.trim(),
              passwordCtrl.text,
            );
        if (!context.mounted) return;
        final err = ref.read(authControllerProvider).error;
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(err))),
          );
        }
      } catch (err) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeApiError(err))),
        );
      } finally {
        isSubmittingPatient.value = false;
      }
    }

    Future<void> submitPharmacy() async {
      if (!pharmacyFormKey.currentState!.validate()) return;
      await ref.read(authControllerProvider.notifier).register(
            email: emailCtrl.text.trim(),
            password: passwordCtrl.text,
            fullName: nameCtrl.text.trim(),
            role: 'PharmacyOwner',
            pharmacy: PharmacyRegistrationDto(
              name: pharmacyNameCtrl.text.trim(),
              addressLine: addressCtrl.text.trim(),
              city: cityCtrl.text.trim(),
              phone: phoneCtrl.text.trim(),
              latitude: pharmacyLocation.value?.latitude,
              longitude: pharmacyLocation.value?.longitude,
              licenseDocUrl: licenseCtrl.text.trim().isEmpty
                  ? null
                  : licenseCtrl.text.trim(),
            ),
          );
      if (!context.mounted) return;
      final err = ref.read(authControllerProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeApiError(err))),
        );
      }
    }

    return Scaffold(

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text('حساب جديد',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 12),

                // Account type switch (Patient vs Pharmacy)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (isPharmacy.value) {
                              isPharmacy.value = false;
                              step.value = 0;
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: !isPharmacy.value
                                  ? AppColors.brand900
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !isPharmacy.value
                                  ? [
                                      BoxShadow(
                                        color: AppColors.brand900
                                            .withValues(alpha: 0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 17,
                                  color: !isPharmacy.value
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'حساب مريض',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: !isPharmacy.value
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (!isPharmacy.value) {
                              isPharmacy.value = true;
                              step.value = 0;
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: isPharmacy.value
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isPharmacy.value
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_pharmacy_rounded,
                                  size: 17,
                                  color: isPharmacy.value
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'حساب صيدلية',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isPharmacy.value
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Step title & progress
                Center(
                  child: Text(
                    isPharmacy.value
                        ? (step.value == 0
                            ? 'الخطوة 1 من 2 · بيانات الصيدلي والحساب'
                            : 'الخطوة 2 من 2 · بيانات الصيدلية والترخيص')
                        : (step.value == 0
                            ? 'الخطوة 1 من 2 · بيانات الحساب'
                            : 'الخطوة 2 من 2 · البيانات الشخصية والملف الطبي (اختياري)'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),

                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: step.value == 0 ? 0.5 : 1.0,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE9EAED),
                    color: isPharmacy.value
                        ? AppColors.primary
                        : AppColors.brand700,
                  ),
                ),
                const SizedBox(height: 18),

                // Main Form Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: isPharmacy.value
                      ? _PharmacyRegistrationForm(
                          formKey: formKey,
                          detailsFormKey: pharmacyFormKey,
                          step: step.value,
                          isLoading: isLoading,
                          nameCtrl: nameCtrl,
                          emailCtrl: emailCtrl,
                          phoneCtrl: phoneCtrl,
                          passwordCtrl: passwordCtrl,
                          confirmCtrl: confirmCtrl,
                          pharmacyNameCtrl: pharmacyNameCtrl,
                          cityCtrl: cityCtrl,
                          addressCtrl: addressCtrl,
                          licenseCtrl: licenseCtrl,
                          pharmacyLocation: pharmacyLocation.value,
                          isLocatingPharmacy: isLocatingPharmacy.value,
                          onLocate: () => fetchPharmacyLocation(showFeedback: true),
                          obscure: obscure,
                          onNext: () {
                            if (formKey.currentState!.validate()) {
                              step.value = 1;
                            }
                          },
                          onSubmit: submitPharmacy,
                        )
                      : _PatientRegistrationForm(
                          formKey: formKey,
                          step: step.value,
                          isLoading: isLoading,
                          nameCtrl: nameCtrl,
                          emailCtrl: emailCtrl,
                          passwordCtrl: passwordCtrl,
                          confirmCtrl: confirmCtrl,
                          gender: selectedGender.value,
                          onGenderChanged: (val) => selectedGender.value = val,
                          ageCtrl: ageCtrl,
                          selectedConditions: selectedConditions.value,
                          onToggleCondition: toggleCondition,
                          conditionsCtrl: conditionsCtrl,
                          selectedAllergies: selectedAllergies.value,
                          onToggleAllergy: toggleAllergy,
                          allergiesCtrl: allergiesCtrl,
                          obscure: obscure,
                          onNext: () {
                            if (formKey.currentState!.validate()) {
                              step.value = 1;
                            }
                          },
                          onSubmit: () => submitPatient(skipHealth: false),
                          onSkip: () => submitPatient(skipHealth: true),
                        ),
                ),

                const SizedBox(height: 12),
                if (step.value == 1)
                  TextButton(
                    onPressed: () => step.value = 0,
                    child: const Text('→ رجوع لبيانات الحساب'),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('عندك حساب بالفعل؟',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('تسجيل الدخول'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Patient Registration Form ───────────────────────────────────────────────
class _PatientRegistrationForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final int step;
  final bool isLoading;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final String gender;
  final ValueChanged<String> onGenderChanged;
  final TextEditingController ageCtrl;
  final Set<String> selectedConditions;
  final ValueChanged<String> onToggleCondition;
  final TextEditingController conditionsCtrl;
  final Set<String> selectedAllergies;
  final ValueChanged<String> onToggleAllergy;
  final TextEditingController allergiesCtrl;
  final ValueNotifier<bool> obscure;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;

  const _PatientRegistrationForm({
    required this.formKey,
    required this.step,
    required this.isLoading,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.gender,
    required this.onGenderChanged,
    required this.ageCtrl,
    required this.selectedConditions,
    required this.onToggleCondition,
    required this.conditionsCtrl,
    required this.selectedAllergies,
    required this.onToggleAllergy,
    required this.allergiesCtrl,
    required this.obscure,
    required this.onNext,
    required this.onSubmit,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    if (step == 0) {
      return Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('register_name_field'),
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'الاسم بالكامل'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('register_email_field'),
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'البريد الإلكتروني'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'البريد مطلوب';
                if (!v.contains('@')) return 'بريد إلكتروني غير صحيح';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('register_password_field'),
              controller: passwordCtrl,
              obscureText: obscure.value,
              decoration: InputDecoration(
                labelText: 'كلمة السر',
                helperText: '8 حروف مع رقم واحد على الأقل',
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure.value
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                  ),
                  onPressed: () => obscure.value = !obscure.value,
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 8) return '8 حروف على الأقل';
                if (!v.contains(RegExp(r'\d'))) return 'أضف رقمًا واحدًا على الأقل';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('register_confirm_password_field'),
              controller: confirmCtrl,
              obscureText: obscure.value,
              onFieldSubmitted: (_) => onNext(),
              decoration: const InputDecoration(labelText: 'تأكيد كلمة السر'),
              validator: (v) =>
                  v != passwordCtrl.text ? 'كلمة السر غير متطابقة' : null,
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('register_next_button'),
              onPressed: onNext,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text('التالي'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.infoSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined,
                  color: AppColors.accentBlue, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'البيانات دي مشفرة وبتساعد الصيدلي يخدمك بأمان وتجنب التداخلات الدوائية والتوصيات المناسبة.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.accentBlue,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Demographics Card (Gender & Age)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'البيانات الحيوية (للأمان والجرعات والتوصيات)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'النوع',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                key: const Key('gender_male_chip'),
                                onTap: () => onGenderChanged('ذكر'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: gender == 'ذكر'
                                        ? AppColors.brand900
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: gender == 'ذكر'
                                          ? AppColors.brand900
                                          : AppColors.hairline,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'ذكر 👨',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: gender == 'ذكر'
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: InkWell(
                                key: const Key('gender_female_chip'),
                                onTap: () => onGenderChanged('أنثى'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: gender == 'أنثى'
                                        ? AppColors.brand900
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: gender == 'أنثى'
                                          ? AppColors.brand900
                                          : AppColors.hairline,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'أنثى 👩',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: gender == 'أنثى'
                                          ? Colors.white
                                          : AppColors.textPrimary,
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
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'العمر بالسنين',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('register_age_field'),
                          controller: ageCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'مثال: 30',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Chronic conditions
        const Text(
          'الأمراض المزمنة (اختياري)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'اضغط لاختيار الأمراض الشائعة أو اكتب في الحقل أدناه:',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _patientCommonConditions.map((cond) {
            final isSelected = selectedConditions.contains(cond);
            return FilterChip(
              key: Key('condition_chip_$cond'),
              label: Text(cond),
              selected: isSelected,
              onSelected: (_) => onToggleCondition(cond),
              selectedColor: AppColors.brand700.withValues(alpha: 0.15),
              checkmarkColor: AppColors.brand700,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.brand700 : AppColors.textPrimary,
              ),
              backgroundColor: const Color(0xFFF1F3F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.brand700 : AppColors.hairline,
                ),
              ),
              showCheckmark: true,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('register_conditions_field'),
          controller: conditionsCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'أمراض مزمنة أخرى',
            hintText: 'سكري، ضغط الدم (فصل بفاصلة)',
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),

        // Allergies
        const Text(
          'الحساسية الدوائية (اختياري)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'اضغط لاختيار مسببات الحساسية الشائعة أو اكتب مسببات إضافية:',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _patientCommonAllergies.map((allergy) {
            final isSelected = selectedAllergies.contains(allergy);
            return FilterChip(
              key: Key('allergy_chip_$allergy'),
              label: Text(allergy),
              selected: isSelected,
              onSelected: (_) => onToggleAllergy(allergy),
              selectedColor: AppColors.warningBg,
              checkmarkColor: AppColors.warningText,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.warningText : AppColors.textPrimary,
              ),
              backgroundColor: const Color(0xFFF1F3F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.warningIcon : AppColors.hairline,
                ),
              ),
              showCheckmark: true,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('register_allergies_field'),
          controller: allergiesCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'حساسية دوائية أخرى',
            hintText: 'بنسلين، سلفا (فصل بفاصلة)',
            isDense: true,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('submit_patient_button'),
          onPressed: isLoading ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Text('إنشاء الحساب'),
        ),
        const SizedBox(height: 6),
        TextButton(
          key: const Key('skip_patient_step_button'),
          onPressed: isLoading ? null : onSkip,
          child: const Text('تخطي هذه الخطوة'),
        ),
      ],
    );
  }
}

// ── Pharmacy Registration Form ──────────────────────────────────────────────
class _PharmacyRegistrationForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final GlobalKey<FormState> detailsFormKey;
  final int step;
  final bool isLoading;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final TextEditingController pharmacyNameCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController licenseCtrl;
  final Position? pharmacyLocation;
  final bool isLocatingPharmacy;
  final VoidCallback onLocate;
  final ValueNotifier<bool> obscure;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  const _PharmacyRegistrationForm({
    required this.formKey,
    required this.detailsFormKey,
    required this.step,
    required this.isLoading,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.pharmacyNameCtrl,
    required this.cityCtrl,
    required this.addressCtrl,
    required this.licenseCtrl,
    required this.pharmacyLocation,
    required this.isLocatingPharmacy,
    required this.onLocate,
    required this.obscure,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (step == 0) {
      return Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'اسم الصيدلي / مدير الصيدلية',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'اسم المسؤول مطلوب' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني للعمل',
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'البريد مطلوب';
                if (!v.contains('@')) return 'بريد إلكتروني غير صحيح';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم هاتف الصيدلية للتواصل',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
                hintText: '01XXXXXXXXX',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'رقم الهاتف مطلوب';
                if (v.trim().length < 8) return 'رقم هاتف غير صحيح';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscure.value,
              decoration: InputDecoration(
                labelText: 'كلمة السر',
                helperText: '8 حروف مع رقم واحد على الأقل',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure.value
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                  ),
                  onPressed: () => obscure.value = !obscure.value,
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 8) return '8 حروف على الأقل';
                if (!v.contains(RegExp(r'\d'))) return 'أضف رقمًا واحدًا على الأقل';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: confirmCtrl,
              obscureText: obscure.value,
              onFieldSubmitted: (_) => onNext(),
              decoration: const InputDecoration(
                labelText: 'تأكيد كلمة السر',
                prefixIcon: Icon(Icons.lock_reset_rounded, size: 20),
              ),
              validator: (v) =>
                  v != passwordCtrl.text ? 'كلمة السر غير متطابقة' : null,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text('متابعة بيانات الصيدلية'),
            ),
          ],
        ),
      );
    }

    return Form(
      key: detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Information banner regarding pending approval
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hourglass_top_rounded,
                    color: AppColors.warning, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب التوثيق قيد المراجعة',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warning,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'بعد إتمام التسجيل، يتم فحص بيانات الصيدلية والترخيص من قبل إدارة المنصة لاعتماد الحساب رسميًا.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: pharmacyNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'اسم الصيدلية الرسمي',
              prefixIcon: Icon(Icons.storefront_outlined, size: 20),
              hintText: 'مثال: صيدلية الشفاء',
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'اسم الصيدلية مطلوب' : null,
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: cityCtrl,
            decoration: const InputDecoration(
              labelText: 'المحافظة / المدينة',
              prefixIcon: Icon(Icons.location_city_outlined, size: 20),
              hintText: 'مثال: القاهرة، الجيزة، الإسكندرية',
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'المدينة مطلوبة' : null,
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: addressCtrl,
            decoration: const InputDecoration(
              labelText: 'عنوان الصيدلية بالتفصيل',
              prefixIcon: Icon(Icons.place_outlined, size: 20),
              hintText: 'الشارع، رقم المبنى، أقرب علامة مميزة',
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null,
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: licenseCtrl,
            decoration: const InputDecoration(
              labelText: 'رقم ترخيص مزاولة المهنة / السجل التجاري (اختياري)',
              prefixIcon: Icon(Icons.badge_outlined, size: 20),
              hintText: 'مثال: LIC-102948',
            ),
          ),
          const SizedBox(height: 12),

          // Location badge/button
          if (isLocatingPharmacy)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'جاري التقاط موقع الصيدلية الجغرافي من الـ GPS...',
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else if (pharmacyLocation != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.successIcon.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded, size: 16, color: AppColors.successIcon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم تحديد موقع الصيدلية (${pharmacyLocation!.latitude.toStringAsFixed(4)}, ${pharmacyLocation!.longitude.toStringAsFixed(4)})',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.successText, fontWeight: FontWeight.w700),
                    ),
                  ),
                  InkWell(
                    onTap: onLocate,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'تحديث',
                        style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: onLocate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_searching_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'اضغط هنا لتحديد موقع الصيدلية من موقعك الحالي (GPS)',
                        style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: isLoading ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 19),
                      SizedBox(width: 8),
                      Text('إرسال طلب تسجيل الصيدلية',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
