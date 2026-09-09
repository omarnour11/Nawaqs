import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/active_orders_tab.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/inventory_tab.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/shortage_queue_tab.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_onboarding_screen.dart'
    show myPharmacyProvider;
import 'package:go_router/go_router.dart';

class PharmacyDashboardScreen extends HookConsumerWidget {
  const PharmacyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = useState(0);
    final ordersState = ref.watch(pharmacyReservationsControllerProvider);
    final profileState = ref.watch(myPharmacyProvider);

    // Backend reports 'Active' for live holds — the old code counted 'Pending'
    // so the badge never appeared.
    final activeCount = ordersState.value
            ?.where((r) => r.status == 'Active')
            .length ??
        0;

    final verification = profileState.value?.verificationStatus;
    final rejectionReason = profileState.value?.rejectionReason;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 20,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_pharmacy_rounded,
                    size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Text('Owner Dashboard'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.receipt_long_rounded),
              tooltip: 'سجل المبيعات',
              onPressed: () => context.push('/pharmacy/ledger'),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: 'تحقق من تصريح (مسح QR)',
              onPressed: () => context.push('/pharmacy/scan'),
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: 'Pharmacy profile',
              onPressed: () => context.push('/pharmacy/onboarding'),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Logout',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout')),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                }
              },
            ),
          ],
          bottom: TabBar(
            onTap: (i) => tabIndex.value = i,
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: AppColors.border,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 17),
                    const SizedBox(width: 6),
                    const Text('Active Orders'),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$activeCount',
                            style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 17),
                    SizedBox(width: 6),
                    Text('المخزون'),
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign_outlined, size: 17),
                    SizedBox(width: 6),
                    Text('النواقص'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // ── Verification status banner ────────────────────────────────
            if (verification == 'Pending')
              _VerificationBanner(
                icon: Icons.hourglass_top_rounded,
                color: AppColors.warning,
                background: AppColors.warningSurface,
                title: 'Pending admin review',
                message:
                    'Your pharmacy is awaiting verification. You can prepare your inventory meanwhile.',
                actionLabel: 'View profile',
                onAction: () => context.push('/pharmacy/onboarding'),
              )
            else if (verification == 'Rejected')
              _VerificationBanner(
                icon: Icons.error_outline_rounded,
                color: AppColors.danger,
                background: AppColors.dangerSurface,
                title: 'Registration rejected',
                message: rejectionReason ??
                    'Please review your details and resubmit for verification.',
                actionLabel: 'Fix & resubmit',
                onAction: () => context.push('/pharmacy/onboarding'),
              ),
            Expanded(
              child: TabBarView(
                children: const [
                  ActiveOrdersTab(),
                  InventoryTab(),
                  ShortageQueueTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _VerificationBanner({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: color)),
                const SizedBox(height: 2),
                Text(message,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
