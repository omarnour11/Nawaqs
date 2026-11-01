import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/active_orders_tab.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/inventory_tab.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/shortage_queue_tab.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/sales_ledger_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_profile_models.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_onboarding_screen.dart'
    show myPharmacyProvider;

/// Pharmacy Owner Portal: persistent bottom navigation bar matching the
/// patient experience, with live badges, verification banner, and full profile.
class PharmacyDashboardScreen extends HookConsumerWidget {
  const PharmacyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = useState(0);
    final ordersState = ref.watch(pharmacyReservationsControllerProvider);
    final profileState = ref.watch(myPharmacyProvider);

    final activeCount = ordersState.value
            ?.where((r) => r.status == 'Active' || r.status == 'Ready')
            .length ??
        0;

    final pharmacy = profileState.value;
    final verification = pharmacy?.verificationStatus ?? 'Pending';
    final rejectionReason = pharmacy?.rejectionReason;

    final tabTitles = [
      'الطلبات الجارية',
      'إدارة المخزون',
      'قائمة النواقص',
      'سجل المبيعات',
      'الملف الشخصي',
    ];

    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.local_pharmacy_rounded,
                  size: 19, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pharmacy?.name ?? 'لوحة الصيدلية',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    tabTitles[selectedIndex.value],
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          const NotificationBellButton(),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'مسح تصريح QR',
            onPressed: () => context.push('/pharmacy/scan'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('خروج'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Verification status banner ─────────────────────────────
          if (verification == 'Pending')
            _VerificationBanner(
              icon: Icons.hourglass_top_rounded,
              color: AppColors.warning,
              background: AppColors.warningSurface,
              title: 'طلب التوثيق قيد المراجعة',
              message:
                  'صيدليتك في انتظار مراجعة الإدارة. يمكنك ترتيب المخزون لحين استكمال التوثيق.',
              actionLabel: 'تعديل البيانات',
              onAction: () => context.push('/pharmacy/onboarding'),
            )
          else if (verification == 'Rejected')
            _VerificationBanner(
              icon: Icons.error_outline_rounded,
              color: AppColors.danger,
              background: AppColors.dangerSurface,
              title: 'تم رفض طلب التسجيل',
              message: rejectionReason ??
                  'يرجى مراجعة بيانات الرخصة والموقع وإعادة تقديم الطلب.',
              actionLabel: 'تعديل وإعادة إرسال',
              onAction: () => context.push('/pharmacy/onboarding'),
            ),

          Expanded(
            child: IndexedStack(
              index: selectedIndex.value,
              children: [
                const ActiveOrdersTab(),
                const InventoryTab(),
                const ShortageQueueTab(),
                const _EmbeddedLedgerTab(),
                _PharmacyProfileTab(pharmacy: pharmacy),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex.value,
        onDestinationSelected: (i) => selectedIndex.value = i,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.receipt_long_rounded),
            ),
            label: 'الطلبات',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'المخزون',
          ),
          const NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign_rounded),
            label: 'النواقص',
          ),
          const NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'المبيعات',
          ),
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'الملف',
          ),
        ],
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Embedded wrapper for the sales ledger inside the bottom navigation shell
class _EmbeddedLedgerTab extends StatelessWidget {
  const _EmbeddedLedgerTab();

  @override
  Widget build(BuildContext context) {
    return const SalesLedgerScreen();
  }
}

/// Pharmacy Profile tab inside the dashboard shell
class _PharmacyProfileTab extends HookConsumerWidget {
  final MyPharmacyDto? pharmacy;

  const _PharmacyProfileTab({required this.pharmacy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pharmacy;
    if (p == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('لم يتم تسجيل بيانات الصيدلية بعد',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.push('/pharmacy/onboarding'),
              child: const Text('تسجيل بيانات الصيدلية الآن'),
            ),
          ],
        ),
      );
    }

    final verification = p.verificationStatus;
    final (statusLabel, statusTone, statusIcon) = switch (verification) {
      'Approved' => ('موثقة ومعتمدة', ChipTone.success, Icons.verified_rounded),
      'Rejected' => ('تم رفض الطلب', ChipTone.danger, Icons.cancel_rounded),
      _ => ('قيد المراجعة', ChipTone.warning, Icons.hourglass_top_rounded),
    };

    return RefreshIndicator(
      color: AppColors.accentBlue,
      onRefresh: () async => ref.invalidate(myPharmacyProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header card with verification status ─────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primarySurface,
                      child: const Icon(Icons.local_pharmacy_rounded,
                          size: 32, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          StatusChip(
                            statusLabel,
                            tone: statusTone,
                            icon: statusIcon,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (p.rejectionReason != null &&
                    verification == 'Rejected') ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSurface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'سبب الرفض: ${p.rejectionReason}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                                height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Contact & Location Details ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('بيانات الاتصال والموقع'),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.location_on_outlined,
                  label: 'العنوان',
                  value: '${p.addressLine}، ${p.city}',
                ),
                const Divider(height: 20),
                _InfoTile(
                  icon: Icons.phone_outlined,
                  label: 'رقم الهاتف',
                  value: p.phone,
                ),
                const Divider(height: 20),
                _InfoTile(
                  icon: Icons.my_location_outlined,
                  label: 'الإحداثيات الجغرافية',
                  value:
                      '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Documents ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('المستندات الرسمية المرفقة'),
                const SizedBox(height: 12),
                _DocumentStatusTile(
                  title: 'رخصة مزاولة المهنة والمنشأة',
                  hasDoc: p.licenseDocUrl?.isNotEmpty == true,
                ),
                const Divider(height: 16),
                _DocumentStatusTile(
                  title: 'بطاقة الرقم القومي للصيدلي',
                  hasDoc: p.nationalIdDocUrl?.isNotEmpty == true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Edit Profile Button ────────────────────────────────────
          FilledButton.icon(
            onPressed: () => context.push('/pharmacy/onboarding'),
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: const Text('تعديل البيانات أو موقع الصيدلية على الخريطة'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _DocumentStatusTile extends StatelessWidget {
  final String title;
  final bool hasDoc;

  const _DocumentStatusTile({required this.title, required this.hasDoc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          hasDoc ? Icons.check_circle_outline_rounded : Icons.pending_outlined,
          size: 20,
          color: hasDoc ? AppColors.successIcon : AppColors.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 13)),
        ),
        Text(
          hasDoc ? 'مرفق' : 'غير مرفق',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: hasDoc ? AppColors.successText : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
