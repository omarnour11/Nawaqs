import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/profile/data/medication_models.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailCtrl = useTextEditingController();
    final passwordCtrl = useTextEditingController();
    final obscure = useState(true);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen<AsyncValue<AuthState>>(authControllerProvider, (_, next) {
      if (!next.isLoading && next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeApiError(next.error!))),
        );
      }
    });

    Future<void> submit() async {
      final email = emailCtrl.text.trim();
      final password = passwordCtrl.text;
      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اكتب الإيميل وكلمة السر.')),
        );
        return;
      }
      await ref.read(authControllerProvider.notifier).login(email, password);
      if (!context.mounted) return;
      final err = ref.read(authControllerProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeApiError(err))),
        );
      }
    }

    return Scaffold(
      backgroundColor: context.pageColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand mark
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.borderColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: context.isDarkMode ? 0.25 : 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const NawaqssLogo(
                      size: 48,
                      showText: false,
                      variant: NawaqssLogoVariant.auto,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'نواقص',
                    style: AppTypography.mainHeader(
                      fontSize: 32,
                      color: context.textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'تتبع توفر الأدوية في صيدليات مصر',
                    style: AppTypography.body(
                      fontSize: 13.5,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: context.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: context.isDarkMode ? 0.2 : 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionLabel('تسجيل الدخول'),
                      const SizedBox(height: 14),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.mail_outline_rounded,
                              size: 19, color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: obscure.value,
                        onSubmitted: (_) => submit(),
                        decoration: InputDecoration(
                          hintText: 'كلمة السر',
                          prefixIcon: const Icon(Icons.lock_outline_rounded,
                              size: 19, color: AppColors.textMuted),
                          suffixIcon: IconButton(
                            icon: Icon(
                                obscure.value
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 19),
                            onPressed: () => obscure.value = !obscure.value,
                          ),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () => _showForgotPasswordSheet(context),
                          child: const Text('نسيت كلمة السر؟',
                              style: TextStyle(fontSize: 12.5)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: isLoading ? null : submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: NawaqsColors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2, color: Colors.white))
                              : const Text('دخول',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('معندكش حساب؟',
                        style: TextStyle(
                            color: context.textSecondaryColor, fontSize: 13.5)),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      style: TextButton.styleFrom(
                        foregroundColor: NawaqsColors.coral,
                      ),
                      child: const Text('اعمل حساب جديد',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
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

/// نسيت كلمة السر — two-step sheet: email → token (prefilled for dev) → new password.
Future<void> _showForgotPasswordSheet(BuildContext context) async {
  final emailCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  int step = 0; // 0 = email, 1 = reset
  String? error;
  bool busy = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Future<void> submit() async {
          setSheetState(() { busy = true; error = null; });
          try {
            final client =
                ProviderScope.containerOf(sheetContext).read(apiClientProvider);

            if (step == 0) {
              final res = await client
                  .forgotPassword(ForgotPasswordRequest(email: emailCtrl.text.trim()))
                  .timeout(const Duration(seconds: 15));
              final token = res.resetToken;
              if (token != null && token.toString().isNotEmpty) {
                codeCtrl.text = token.toString(); // dev flow: prefill token
              }
              step = 1;
            } else {
              await client.resetPassword(ResetPasswordRequest(
                email: emailCtrl.text.trim(),
                resetToken: codeCtrl.text.trim(),
                newPassword: passCtrl.text,
              )).timeout(const Duration(seconds: 15));
              if (sheetContext.mounted) Navigator.pop(sheetContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('كلمة السر اتغيرت. سجّل دخول بالجديدة.')),
                );
              }
            }
          } catch (e) {
            error = describeApiError(e);
          } finally {
            setSheetState(() { busy = false; });
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              left: 20, right: 20, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel('استعادة كلمة السر'),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                enabled: step == 0,
                decoration:
                    const InputDecoration(hintText: 'البريد الإلكتروني المسجل'),
              ),
              if (step == 1) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'كود الاستعادة',
                      helperText: 'اتملّا تلقائيًا في وضع التطوير'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'كلمة السر الجديدة',
                      helperText: '8 حروف مع رقم واحد على الأقل'),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style: const TextStyle(
                        color: AppColors.dangerText, fontSize: 12.5)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : submit,
                style: FilledButton.styleFrom(
                    backgroundColor: NawaqsColors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13))),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(step == 0 ? 'إرسال كود الاستعادة' : 'تغيير كلمة السر',
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    ),
  );
}
