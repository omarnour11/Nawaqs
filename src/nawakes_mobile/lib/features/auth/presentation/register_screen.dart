import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final step = useState(0); // 0 = account, 1 = health profile
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    final nameCtrl = useTextEditingController();
    final emailCtrl = useTextEditingController();
    final passwordCtrl = useTextEditingController();
    final confirmCtrl = useTextEditingController();
    final allergiesCtrl = useTextEditingController();
    final conditionsCtrl = useTextEditingController();
    final obscure = useState(true);

    ref.listen<AsyncValue<AuthState>>(authControllerProvider, (_, next) {
      if (!next.isLoading && next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeApiError(next.error!))),
        );
      }
    });

    List<String> splitList(String raw) => raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    Future<void> submit() async {
      if (!formKey.currentState!.validate()) return;
      await ref.read(authControllerProvider.notifier).register(
            email: emailCtrl.text.trim(),
            password: passwordCtrl.text,
            fullName: nameCtrl.text.trim(),
            knownAllergies: splitList(allergiesCtrl.text),
            chronicIllnesses: splitList(conditionsCtrl.text),
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
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text('حساب جديد',
                      style: TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    step.value == 0
                        ? 'الخطوة 1 من 2 · بيانات الحساب'
                        : 'الخطوة 2 من 3 · ملفك الطبي (اختياري)',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: step.value == 0 ? 0.33 : 0.66,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE9EAED),
                    color: AppColors.brand700,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Form(
                    key: formKey,
                    child: step.value == 0
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: nameCtrl,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                    labelText: 'الاسم بالكامل'),
                                validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'مطلوب' : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                    labelText: 'البريد الإلكتروني'),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'مطلوب';
                                  }
                                  if (!v.contains('@')) return 'إيميل غير صحيح';
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
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        obscure.value
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 19),
                                    onPressed: () =>
                                        obscure.value = !obscure.value,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.length < 8) {
                                    return '8 حروف على الأقل';
                                  }
                                  if (!v.contains(RegExp(r'\d'))) {
                                    return 'ضيف رقم واحد';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: confirmCtrl,
                                obscureText: obscure.value,
                                onFieldSubmitted: (_) {
                                  if (formKey.currentState!.validate()) {
                                    step.value = 1;
                                  }
                                },
                                decoration: const InputDecoration(
                                    labelText: 'تأكيد كلمة السر'),
                                validator: (v) =>
                                    v != passwordCtrl.text ? 'مش متطابقة' : null,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () {
                                  if (formKey.currentState!.validate()) {
                                    step.value = 1;
                                  }
                                },
                                style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(13))),
                                child: const Text('التالي'),
                              ),
                            ],
                          )
                        : Column(
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
                                        'البيانات دي متشفرة وبتساعد الصيدلي يخدمك بأمان.',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.accentBlue,
                                            height: 1.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: conditionsCtrl,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'الأمراض المزمنة',
                                  hintText: 'سكري، ضغط، فصل بينهم بفاصلة',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: allergiesCtrl,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'الحساسية',
                                  hintText: 'البنسلين، فاصلة بينهم',
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: isLoading ? null : submit,
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.brand900,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(13))),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white))
                                    : const Text('إنشاء الحساب'),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: isLoading ? null : submit,
                                child: const Text('تخطي الخطوة'),
                              ),
                            ],
                          ),
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
                    const Text('عندك حساب؟',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('دخول'),
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
