import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';

/// Official Nawaqss Splash Screen (Brand Kit Pages 4, 6 & 14)
/// Displays brand teal background, vector capsule logo, and Lalezar typography.
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
              // ── Brand Vector Mark ──
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: const Center(
                  child: NawaqssLogo(size: 64, showText: false),
                ),
              ),
              const SizedBox(height: 24),

              // ── Main Header in Lalezar ──
              Text(
                'نواقص',
                style: AppTypography.mainHeader(
                  fontSize: 52,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),

              // ── Subtitle in Lalezar ──
              Text(
                'صوّر الروشتة وخلاص',
                style: AppTypography.subHeader(
                  fontSize: 22,
                  color: NawaqsColors.mint,
                ),
              ),
              const SizedBox(height: 10),

              // ── Tagline in Cairo ──
              Text(
                'أيدوا ناقص؟ هتلاقيه في أقرب صيدلية عنده',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 42),

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