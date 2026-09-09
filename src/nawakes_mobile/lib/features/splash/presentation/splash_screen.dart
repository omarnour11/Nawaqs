import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';

class SplashScreen extends HookConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      Future(() async {
        await Future.delayed(const Duration(milliseconds: 900));
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
      backgroundColor: AppColors.page,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.brand900,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.monitor_heart_outlined,
                  color: Colors.white, size: 34),
            ),
            const SizedBox(height: 18),
            const Text('نواقص',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('توفر الأدوية في صيدليات مصر',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 36),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
