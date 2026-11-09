import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';

/// Official Nawaqss Splash Screen (Brand Kit Pages 1, 3, 4 & 14)
/// Displays brand teal background, pure vector capsule logo on teal, and Lalezar typography.
class SplashScreen extends HookConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      Future(() async {
        await Future.delayed(const Duration(milliseconds: 1200));
        if (context.mounted) {
          final status =
              ref.read(authControllerProvider).value?.status ?? AuthStatus.unknown;
          try {
            switch (status) {
              case AuthStatus.pharmacyOwner:
                context.go('/pharmacy');
              case AuthStatus.admin:
                context.go('/admin');
              case AuthStatus.patient:
                context.go('/home');
              default:
                context.go('/login');
            }
          } catch (_) {}
        }
      });
      return null;
    }, const []);

    return Scaffold(
      backgroundColor: NawaqsColors.teal,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Official Brand Vector Mark on Teal (Page 1, 4 & 14) ──
              const NawaqssLogo(
                size: 88,
                showText: false,
                onDark: true,
              ),
              const SizedBox(height: 22),

              // ── Main Header in Lalezar (Page 6 & 14) ──
              Text(
                'نواقص',
                style: AppTypography.mainHeader(
                  fontSize: 54,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),

              // ── English Wordmark Subtitle (Page 3) ──
              const Text(
                'Nawaqss',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: NawaqsColors.mint,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 16),

              // ── Subtitle in Lalezar ──
              Text(
                'صوّر الروشتة وخلاص',
                style: AppTypography.subHeader(
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              // ── Tagline in Cairo ──
              Text(
                'أيدوا ناقص؟ هتلاقيه في أقرب صيدلية عنده',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  fontSize: 14,
                  color: NawaqsColors.mint.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 38),

              // ── Loading indicator in Mint ──
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  valueColor: AlwaysStoppedAnimation<Color>(NawaqsColors.mint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
