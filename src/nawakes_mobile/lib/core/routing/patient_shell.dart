import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

/// Patient bottom nav per the design spec: 4 items, icon above 11px label,
/// active item in accent blue. Find / Passes / Account / Support.
class PatientShell extends StatelessWidget {
  final Widget child;

  const PatientShell({super.key, required this.child});

  static const _locations = ['/home', '/passes', '/profile', '/support'];

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final selectedIndex =
        _locations.indexWhere((l) => loc.startsWith(l)).clamp(0, 3);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'notifications_fab',
        onPressed: () => context.push('/notifications'),
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        elevation: 2,
        child: const Icon(Icons.notifications_none_rounded, size: 22),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => switch (i) {
          0 => context.go('/home'),
          1 => context.go('/passes'),
          2 => context.go('/profile'),
          _ => context.go('/support'),
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'البحث',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined),
            selectedIcon: Icon(Icons.qr_code_2_rounded),
            label: 'التصاريح',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_2_outlined),
            selectedIcon: Icon(Icons.person_2_rounded),
            label: 'الحساب',
          ),
          NavigationDestination(
            icon: Icon(Icons.help_outline_rounded),
            selectedIcon: Icon(Icons.help_rounded),
            label: 'الدعم',
          ),
        ].map((d) => d).toList(),
      ),
    );
  }
}
