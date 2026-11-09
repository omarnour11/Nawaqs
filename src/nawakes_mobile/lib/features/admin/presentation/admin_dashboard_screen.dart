import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/utils/arabic_digits.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/admin/data/admin_models.dart';
import 'package:nawakes_mobile/features/support/data/ticket_models.dart';

part 'admin_dashboard_screen.g.dart';

@riverpod
Future<DashboardStatsDto> adminStats(Ref ref) async {
  return ref.read(apiClientProvider).getAdminStats();
}

@riverpod
Future<List<AdminPharmacyDto>> adminPharmacies(Ref ref, {bool all = false}) async {
  return ref.read(apiClientProvider).getAdminPharmacies(all);
}

@riverpod
Future<List<AdminReportDto>> adminReports(Ref ref, {bool pendingOnly = true}) async {
  return ref.read(apiClientProvider).getAdminReports(pendingOnly);
}

@riverpod
Future<PagedPatientsResult> adminPatients(Ref ref, {String? search, int page = 1}) async {
  return ref.read(apiClientProvider).getAdminPatients(search: search, page: page, pageSize: 20);
}

@riverpod
Future<PagedMedicineCatalogResult> adminMedicineCatalog(Ref ref, {String? search, int page = 1, bool? chronicOnly}) async {
  return ref.read(apiClientProvider).getAdminMedicineCatalog(
        search: search,
        page: page,
        pageSize: 20,
        chronicOnly: chronicOnly,
      );
}

final adminTicketQueueProvider = FutureProvider<List<AdminTicketDto>>((ref) {
  return ref.read(apiClientProvider).getAdminTicketQueue();
});

final shortageDemandProvider = FutureProvider<ShortageDemandResponse>((ref) {
  return ref.read(apiClientProvider).getShortageDemand();
});

class AdminDashboardTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  @override
  set state(int value) => super.state = value;
}
final adminDashboardTabProvider = NotifierProvider<AdminDashboardTabNotifier, int>(AdminDashboardTabNotifier.new);

class AdminTicketSubTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  @override
  set state(int value) => super.state = value;
}
final adminTicketSubTabProvider = NotifierProvider<AdminTicketSubTabNotifier, int>(AdminTicketSubTabNotifier.new);

class AdminTicketFilterNotifier extends Notifier<String?> {
  @override
  String? build() => 'Open';
  @override
  set state(String? value) => super.state = value;
}
final adminTicketFilterProvider = NotifierProvider<AdminTicketFilterNotifier, String?>(AdminTicketFilterNotifier.new);

/// Centralized Management Console for the Nawaqs Platform.
/// Provides 5 dedicated tabs: Overview, Patients, Pharmacies & Verification, Medicines Catalog, and Reports.
class AdminDashboardScreen extends HookConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(adminDashboardTabProvider);

    final titles = [
      'لوحة العمليات',
      'سجل المرضى',
      'الصيدليات والتوثيق',
      'دليل الأدوية (EDA)',
      'التذاكر والبلاغات',
    ];

    return Scaffold(

      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.brand700.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  size: 20, color: AppColors.brand700),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'نواقص · الإدارة العليا',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    titles[selectedTab],
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
      body: IndexedStack(
        index: selectedTab,
        children: const [
          _AdminOverviewTab(),
          _AdminPatientsTab(),
          _AdminPharmaciesTab(),
          _AdminMedicineCatalogTab(),
          _AdminReportsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (i) => ref.read(adminDashboardTabProvider.notifier).state = i,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'المرضى',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_pharmacy_outlined),
            selectedIcon: Icon(Icons.local_pharmacy_rounded),
            label: 'الصيدليات',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication_rounded),
            label: 'الأدوية',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'التذاكر والبلاغات',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: OVERVIEW & SYSTEM KPIS
// ─────────────────────────────────────────────────────────────────────────────

class _AdminOverviewTab extends HookConsumerWidget {
  const _AdminOverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final pharmacies = ref.watch(adminPharmaciesProvider(all: false));

    return RefreshIndicator(
      color: AppColors.accentBlue,
      onRefresh: () async {
        ref.invalidate(adminStatsProvider);
        ref.invalidate(adminPharmaciesProvider);
        ref.invalidate(adminReportsProvider);
        ref.invalidate(adminTicketQueueProvider);
        ref.invalidate(shortageDemandProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── System Health Header ──────────────────────────────────────────
          stats.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.accentBlue),
              ),
            ),
            error: (e, _) => Center(child: Text('تعذر تحميل الإحصائيات: $e')),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(child: SectionLabel('مؤشرات سلامة الشبكة')),
                          StatusChip(
                            '${(s.averageTrustScore * 100).round()}% ثقة',
                            tone: s.averageTrustScore >= 0.8
                                ? ChipTone.success
                                : ChipTone.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              label: 'إجمالي المرضى',
                              value: '${s.totalPatients}',
                              tone: ChipTone.neutral,
                              icon: Icons.person_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatBox(
                              label: 'الصيدليات',
                              value: '${s.totalPharmacies}',
                              tone: ChipTone.neutral,
                              icon: Icons.local_pharmacy_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatBox(
                              label: 'طلبات التوثيق',
                              value: '${s.pendingApprovals}',
                              tone: s.pendingApprovals > 0
                                  ? ChipTone.warning
                                  : ChipTone.success,
                              icon: Icons.pending_actions_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              label: 'حجوزات جارية',
                              value: '${s.activeReservations}',
                              tone: ChipTone.neutral,
                              icon: Icons.hourglass_bottom_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatBox(
                              label: 'حجوزات منفذة',
                              value: '${s.completedReservations}',
                              tone: ChipTone.success,
                              icon: Icons.check_circle_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatBox(
                              label: 'بلاغات معلقة',
                              value: '${s.pendingReports}',
                              tone: s.pendingReports > 0
                                  ? ChipTone.danger
                                  : ChipTone.neutral,
                              icon: Icons.report_problem_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Attention banner for pending approvals ──────────────────
                if (s.pendingApprovals > 0)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'يوجد ${s.pendingApprovals} صيدلية بانتظار مراجعة التوثيق والمستندات.',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warningText),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('طابور الدعم'),
          const SizedBox(height: 10),
          ref.watch(adminTicketQueueProvider).when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text('تعذر تحميل تذاكر الدعم: $e'),
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return const Text('لا توجد تذاكر دعم مفتوحة حالياً',
                        style: TextStyle(color: AppColors.textSecondary));
                  }
                  return Column(
                    children: tickets.take(5).map((t) {
                      return Card(
                        child: ListTile(
                          title: Text(t.subject,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${t.reporterEmail} · ${_ticketStatusArabic(t.status)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () async {
                            final res = await context.push<String>('/admin/ticket-detail', extra: t);
                            ref.invalidate(adminTicketQueueProvider);
                            if (res != null) {
                              ref.read(adminTicketSubTabProvider.notifier).state = 0;
                              ref.read(adminTicketFilterProvider.notifier).state =
                                  (res == 'InProgress' || res == 'InReview') ? 'InProgress' : 'Closed';
                              ref.read(adminDashboardTabProvider.notifier).state = 4;
                            }
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          const SizedBox(height: 20),
          const SectionLabel('أدوية مطلوبة (نواقص)'),
          const SizedBox(height: 10),
          ref.watch(shortageDemandProvider).when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accentBlue),
                    ),
                  ),
                ),
                error: (e, _) => Text('تعذر تحميل طلبات النواقص: $e'),
                data: (demand) {
                  if (demand.rows.isEmpty) {
                    return const Text('لا توجد طلبات نواقص مسجلة حالياً',
                        style: TextStyle(color: AppColors.textSecondary));
                  }
                  return Column(
                    children: demand.rows.take(6).map((row) {
                      return ListTile(
                        dense: true,
                        title: Text(row.medicationName),
                        subtitle: Text(row.city.isEmpty ? 'كل المدن' : row.city),
                        trailing: Text('${row.waitingCount} منتظر'),
                      );
                    }).toList(),
                  );
                },
              ),
          const SizedBox(height: 20),

          // ── Pending Verification Preview ──────────────────────────────────
          const SectionLabel('طلبات التوثيق الأخيرة'),
          const SizedBox(height: 10),
          pharmacies.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue),
            ),
            error: (e, _) => Text('خطأ في تحميل الصيدليات: $e'),
            data: (list) {
              if (list.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: const Center(
                    child: Text(
                      'لا توجد طلبات توثيق معلقة حالياً ✓',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.successText),
                    ),
                  ),
                );
              }
              return Column(
                children: list
                    .take(4)
                    .map((p) => _PharmacyReviewCard(pharmacy: p))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _ticketStatusArabic(String s) => switch (s) {
      'Open' => 'مفتوحة',
      'InProgress' => 'قيد المعالجة',
      'Resolved' => 'تم الحل',
      'Closed' => 'مغلقة',
      _ => s,
    };

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: PATIENTS MANAGEMENT
// ─────────────────────────────────────────────────────────────────────────────

class _AdminPatientsTab extends HookConsumerWidget {
  const _AdminPatientsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchCtrl = useTextEditingController();
    final searchQuery = useState('');
    final page = useState(1);

    final pagedResult = ref.watch(
      adminPatientsProvider(search: searchQuery.value, page: page.value),
    );

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchCtrl,
            builder: (context, value, _) {
              return TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: 'البحث بالاسم، البريد أو الهاتف...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            searchCtrl.clear();
                            searchQuery.value = '';
                            page.value = 1;
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                ),
                onSubmitted: (v) {
                  searchQuery.value = v.trim();
                  page.value = 1;
                },
              );
            },
          ),
        ),

        // ── Results list ────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            color: AppColors.accentBlue,
            onRefresh: () async => ref.invalidate(adminPatientsProvider),
            child: pagedResult.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accentBlue),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('تعذر تحميل بيانات المرضى: $e'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(adminPatientsProvider),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
              data: (result) {
                if (result.items.isEmpty) {
                  return const Center(
                    child: Text('لا يوجد مرضى مطابقين للبحث.'),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'إجمالي النتائج: ${result.totalCount} مريض',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    ...result.items.map((patient) => _PatientCard(patient: patient)),
                    const SizedBox(height: 12),

                    // ── Pagination controls ─────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: page.value > 1
                              ? () => page.value = page.value - 1
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                        Text(
                          'صفحة ${result.pageNumber} من ${result.totalPages > 0 ? result.totalPages : 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          onPressed: page.value < result.totalPages
                              ? () => page.value = page.value + 1
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PatientCard extends StatelessWidget {
  final PatientSummaryDto patient;

  const _PatientCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accentBlueBg,
                child: const Icon(Icons.person_rounded,
                    size: 20, color: AppColors.accentBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName?.isNotEmpty == true
                          ? patient.fullName!
                          : 'مريض مسجل',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      patient.email,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusChip(
                'مفعل',
                tone: ChipTone.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              if (patient.phone?.isNotEmpty == true) ...[
                const Icon(Icons.phone_outlined,
                    size: 15, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(patient.phone!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
              ] else
                const Spacer(),
              StatusChip(
                '${patient.reservationCount} طلبات',
                tone: ChipTone.neutral,
              ),
              const SizedBox(width: 6),
              if (patient.complaintCount > 0)
                StatusChip(
                  '${patient.complaintCount} شكاوى',
                  tone: ChipTone.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3: PHARMACIES & VERIFICATION
// ─────────────────────────────────────────────────────────────────────────────

class _AdminPharmaciesTab extends HookConsumerWidget {
  const _AdminPharmaciesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showAll = useState(false);
    final pharmacies = ref.watch(adminPharmaciesProvider(all: showAll.value));

    return Column(
      children: [
        // ── Filter switch ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('قيد التوثيق فقط'),
                selected: !showAll.value,
                onSelected: (_) => showAll.value = false,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('جميع الصيدليات'),
                selected: showAll.value,
                onSelected: (_) => showAll.value = true,
              ),
            ],
          ),
        ),

        // ── Pharmacy List ───────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            color: AppColors.accentBlue,
            onRefresh: () async => ref.invalidate(adminPharmaciesProvider),
            child: pharmacies.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accentBlue),
              ),
              error: (e, _) => Center(child: Text('خطأ في تحميل الصيدليات: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text(showAll.value
                        ? 'لا توجد صيدليات مسجلة.'
                        : 'لا توجد صيدليات بانتظار التوثيق حالياً ✓'),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'العدد: ${list.length} صيدلية',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    ...list.map((p) => _PharmacyReviewCard(pharmacy: p)),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PharmacyReviewCard extends HookConsumerWidget {
  final AdminPharmacyDto pharmacy;

  const _PharmacyReviewCard({required this.pharmacy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (statusLabel, statusTone) = switch (pharmacy.verificationStatus) {
      'Approved' => ('معتمدة', ChipTone.success),
      'Rejected' => ('مرفوضة', ChipTone.danger),
      _ => ('قيد المراجعة', ChipTone.warning),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pharmacy.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${pharmacy.addressLine} · ${pharmacy.city}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusChip(statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(pharmacy.phone,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusChip(
                    'مخزون: ${pharmacy.inventoryCount}',
                    tone: ChipTone.neutral,
                  ),
                  const SizedBox(width: 6),
                  StatusChip(
                    'ثقة: ${(pharmacy.trustScore * 100).round()}%',
                    tone: pharmacy.trustScore >= 0.8
                        ? ChipTone.success
                        : ChipTone.warning,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await context.push('/admin/pharmacy-review',
                        extra: pharmacy);
                    ref.invalidate(adminPharmaciesProvider);
                    ref.invalidate(adminStatsProvider);
                  },
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: Text(pharmacy.verificationStatus == 'Pending'
                      ? 'مراجعة واعتماد'
                      : 'إدارة وتفاصيل الصيدلية'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Call
              IconButton(
                icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                tooltip: 'اتصال هاتفي بالصيدلية',
                onPressed: pharmacy.phone.isEmpty
                    ? null
                    : () async {
                        final url = Uri(scheme: 'tel', path: pharmacy.phone);
                        if (await canLaunchUrl(url)) await launchUrl(url);
                      },
              ),
              // WhatsApp
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 18, color: Color(0xFF25D366)),
                tooltip: 'مراسلة عبر واتساب',
                onPressed: pharmacy.phone.isEmpty
                    ? null
                    : () async {
                        final clean = pharmacy.phone.replaceAll(RegExp(r'[^0-9]'), '');
                        final phoneWithCode =
                            clean.startsWith('0') ? '20${clean.substring(1)}' : clean;
                        final url = Uri.parse('https://wa.me/$phoneWithCode');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
              ),
              // Toggle Active / Suspended
              IconButton(
                icon: Icon(
                  pharmacy.verificationStatus == 'Approved'
                      ? Icons.pause_circle_outline_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 18,
                  color: pharmacy.verificationStatus == 'Approved'
                      ? AppColors.warning
                      : AppColors.success,
                ),
                tooltip: pharmacy.verificationStatus == 'Approved'
                    ? 'تعليق / إيقاف الصيدلية مؤقتاً'
                    : 'تفعيل واعتماد الصيدلية',
                onPressed: () async {
                  final isApproved = pharmacy.verificationStatus == 'Approved';
                  final targetStatus = isApproved ? 'Rejected' : 'Approved';
                  final title = isApproved ? 'تعليق حساب الصيدلية' : 'تفعيل حساب الصيدلية';
                  final message = isApproved
                      ? 'هل تريد تعليق صيدلية "${pharmacy.name}" وإيقاف ظهور أدويتها للمرضى مؤقتاً؟'
                      : 'هل تريد تفعيل واعتماد صيدلية "${pharmacy.name}" واستئناف ظهورها للمرضى؟';

                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: Text(title),
                      content: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: isApproved ? AppColors.warning : AppColors.success,
                          ),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: Text(isApproved ? 'تعليق' : 'تفعيل'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      await ref.read(apiClientProvider).updatePharmacyStatus(
                            pharmacy.id,
                            UpdatePharmacyStatusRequest(status: targetStatus),
                          );
                      ref.invalidate(adminPharmaciesProvider);
                      ref.invalidate(adminStatsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isApproved
                                ? 'تم تعليق صيدلية ${pharmacy.name}.'
                                : 'تم تفعيل صيدلية ${pharmacy.name} بنجاح.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(describeApiError(e))),
                        );
                      }
                    }
                  }
                },
              ),
              // Delete Pharmacy
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.danger),
                tooltip: 'حذف الصيدلية نهائياً',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('حذف الصيدلية نهائياً'),
                      content: Text(
                        'هل أنت متأكد من حذف صيدلية "${pharmacy.name}" ومخزونها بالكامل؟ هذا الإجراء غير قابل للتراجع.',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.danger),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('حذف نهائياً'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      await ref.read(apiClientProvider).deletePharmacy(pharmacy.id);
                      ref.invalidate(adminPharmaciesProvider);
                      ref.invalidate(adminStatsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم حذف صيدلية ${pharmacy.name} بنجاح.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(describeApiError(e))),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4: MEDICINE CATALOG (EDA REGISTRY)
// ─────────────────────────────────────────────────────────────────────────────

class _AdminMedicineCatalogTab extends HookConsumerWidget {
  const _AdminMedicineCatalogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchCtrl = useTextEditingController();
    final searchQuery = useState('');
    final page = useState(1);
    final chronicOnly = useState<bool?>(null);

    final catalogResult = ref.watch(
      adminMedicineCatalogProvider(
        search: searchQuery.value,
        page: page.value,
        chronicOnly: chronicOnly.value,
      ),
    );

    return Column(
      children: [
        // ── Search & Filters ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchCtrl,
                  builder: (context, value, _) {
                    return TextField(
                      controller: searchCtrl,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText:
                            'البحث في دليل الأدوية المصري (بالاسم أو المادة)...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  searchCtrl.clear();
                                  searchQuery.value = '';
                                  page.value = 1;
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide:
                              const BorderSide(color: AppColors.hairline),
                        ),
                      ),
                      onSubmitted: (v) {
                        searchQuery.value = v.trim();
                        page.value = 1;
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  searchQuery.value = searchCtrl.text.trim();
                  page.value = 1;
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(52, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Icon(Icons.search_rounded, size: 22),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                label: const Text('أدوية الأمراض المزمنة فقط'),
                selected: chronicOnly.value == true,
                onSelected: (val) {
                  chronicOnly.value = val ? true : null;
                  page.value = 1;
                },
              ),
            ],
          ),
        ),

        // ── Catalog List ────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            color: AppColors.accentBlue,
            onRefresh: () async => ref.invalidate(adminMedicineCatalogProvider),
            child: catalogResult.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accentBlue),
              ),
              error: (e, _) => Center(child: Text('خطأ في تحميل الدليل: $e')),
              data: (result) {
                if (result.items.isEmpty) {
                  return const Center(
                    child: Text('لا توجد أدوية مطابقة للبحث في السجل المصري.'),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'إجمالي المسجل: ${result.totalCount} دواء',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    ...result.items.map((m) => _MedicineCatalogCard(medicine: m)),
                    const SizedBox(height: 12),

                    // ── Pagination controls ─────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: page.value > 1
                              ? () => page.value = page.value - 1
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                        Text(
                          'صفحة ${result.pageNumber} من ${result.totalPages > 0 ? result.totalPages : 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          onPressed: page.value < result.totalPages
                              ? () => page.value = page.value + 1
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MedicineCatalogCard extends StatelessWidget {
  final MedicineCatalogItemDto medicine;

  const _MedicineCatalogCard({required this.medicine});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.tradeName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    if (medicine.activeIngredient != null)
                      Text(
                        medicine.activeIngredient!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.brand700,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              if (medicine.isChronic)
                const StatusChip('مزمن', tone: ChipTone.warning),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (medicine.dosageForm != null)
                Text(
                  medicine.dosageForm!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              if (medicine.strength != null) ...[
                const Text(' · ',
                    style: TextStyle(color: AppColors.textSecondary)),
                Text(
                  medicine.strength!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              const Spacer(),
              if (medicine.officialPriceEGP != null)
                Text(
                  medicine.officialPriceEGP!.toArabicPrice(),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
            ],
          ),
          if (medicine.manufacturer != null) ...[
            const SizedBox(height: 4),
            Text(
              'الشركة المصنعة: ${medicine.manufacturer}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 5: REPORTS & COMPLAINTS MODERATION
// ─────────────────────────────────────────────────────────────────────────────

class _AdminReportsTab extends HookConsumerWidget {
  const _AdminReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subTab = ref.watch(adminTicketSubTabProvider);
    final pendingOnly = useState(true);
    final ticketStatusFilter = ref.watch(adminTicketFilterProvider);
    final reports = ref.watch(adminReportsProvider(pendingOnly: pendingOnly.value));
    final ticketsAsync = ref.watch(adminTicketQueueProvider);

    return Column(
      children: [
        // Sub-tabs segment
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('تذاكر الدعم', style: TextStyle(fontWeight: FontWeight.w700)),
                      icon: Icon(Icons.support_agent_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('بلاغات الصيدليات', style: TextStyle(fontWeight: FontWeight.w700)),
                      icon: Icon(Icons.flag_outlined, size: 18),
                    ),
                  ],
                  selected: {subTab},
                  onSelectionChanged: (val) =>
                      ref.read(adminTicketSubTabProvider.notifier).state = val.first,
                ),
              ),
            ],
          ),
        ),

        if (subTab == 0) ...[
          // Tickets filter row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('المفتوحة'),
                    selected: ticketStatusFilter == 'Open',
                    onSelected: (_) =>
                        ref.read(adminTicketFilterProvider.notifier).state = 'Open',
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('قيد المعالجة'),
                    selected: ticketStatusFilter == 'InProgress' || ticketStatusFilter == 'InReview',
                    onSelected: (_) =>
                        ref.read(adminTicketFilterProvider.notifier).state = 'InProgress',
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('المغلقة'),
                    selected: ticketStatusFilter == 'Closed' || ticketStatusFilter == 'Resolved',
                    onSelected: (_) =>
                        ref.read(adminTicketFilterProvider.notifier).state = 'Closed',
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('الكل'),
                    selected: ticketStatusFilter == null,
                    onSelected: (_) =>
                        ref.read(adminTicketFilterProvider.notifier).state = null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accentBlue,
              onRefresh: () async => ref.invalidate(adminTicketQueueProvider),
              child: ticketsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accentBlue),
                ),
                error: (e, _) => Center(child: Text('خطأ في تحميل تذاكر الدعم: $e')),
                data: (tickets) {
                  final filtered = ticketStatusFilter == null
                      ? tickets
                      : tickets.where((t) {
                          if (ticketStatusFilter == 'Open') {
                            return t.status == 'Open';
                          }
                          if (ticketStatusFilter == 'InProgress' || ticketStatusFilter == 'InReview') {
                            return t.status == 'InProgress' || t.status == 'InReview';
                          }
                          if (ticketStatusFilter == 'Closed' || ticketStatusFilter == 'Resolved') {
                            return t.status == 'Closed' || t.status == 'Resolved';
                          }
                          return t.status == ticketStatusFilter;
                        }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('لا توجد تذاكر مطابقة حالياً ✓'),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: filtered.map((t) {
                      final isProg = t.status == 'InProgress' || t.status == 'InReview';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: t.status == 'Open'
                                ? AppColors.warningBg
                                : (isProg
                                    ? AppColors.accentBlueBg
                                    : AppColors.hairline),
                            child: Icon(
                              t.status == 'Open'
                                  ? Icons.mark_email_unread_outlined
                                  : (isProg
                                      ? Icons.hourglass_top_rounded
                                      : Icons.check_circle_outline),
                              color: t.status == 'Open'
                                  ? AppColors.warningText
                                  : (isProg
                                      ? AppColors.accentBlue
                                      : AppColors.textSecondary),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            t.subject,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${t.reporterEmail} · ${_ticketStatusArabic(t.status)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: const Icon(Icons.chevron_left_rounded),
                          onTap: () async {
                            final res = await context.push<String>('/admin/ticket-detail', extra: t);
                            ref.invalidate(adminTicketQueueProvider);
                            if (res != null) {
                              final target = (res == 'InProgress' || res == 'InReview')
                                  ? 'InProgress'
                                  : (res == 'Closed' || res == 'Resolved')
                                      ? 'Closed'
                                      : res;
                              ref.read(adminTicketFilterProvider.notifier).state = target;
                            }
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ] else ...[
          // Reports filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('المعلقة فقط'),
                  selected: pendingOnly.value,
                  onSelected: (_) => pendingOnly.value = true,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('جميع البلاغات'),
                  selected: !pendingOnly.value,
                  onSelected: (_) => pendingOnly.value = false,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accentBlue,
              onRefresh: () async => ref.invalidate(adminReportsProvider),
              child: reports.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accentBlue),
                ),
                error: (e, _) => Center(child: Text('خطأ في تحميل البلاغات: $e')),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('لا توجد بلاغات بانتظار المراجعة ✓'),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: list.map((r) => _ReportReviewCard(report: r)).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReportReviewCard extends HookConsumerWidget {
  final AdminReportDto report;

  const _ReportReviewCard({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acting = useState<bool?>(null);

    Future<void> review(bool confirm) async {
      acting.value = confirm;
      try {
        await ref
            .read(apiClientProvider)
            .reviewReport(report.id, ReviewReportRequest(confirm: confirm));
        ref.invalidate(adminReportsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(confirm
                  ? 'تم تأكيد البلاغ وتعديل تقييم الصيدلية.'
                  : 'تم رفض البلاغ وحفظ السجل.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر مراجعة البلاغ: $e')),
          );
        }
      } finally {
        acting.value = null;
      }
    }

    final isPending = report.status == 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.pharmacyName,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
              ),
              StatusChip(
                report.status == 'Pending'
                    ? 'قيد المراجعة'
                    : (report.status == 'Confirmed' ? 'مؤكد' : 'مرفوض'),
                tone: report.status == 'Confirmed'
                    ? ChipTone.danger
                    : (report.status == 'Pending'
                        ? ChipTone.warning
                        : ChipTone.neutral),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'مقدم البلاغ: ${report.reporterEmail}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (report.medicationName != null) ...[
            const SizedBox(height: 4),
            Text(
              'الدواء المبلغ عنه: ${report.medicationName}',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ],
          if (report.description != null && report.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.page,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                report.description!,
                style: const TextStyle(fontSize: 12, height: 1.3),
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: acting.value != null ? null : () => review(false),
                    child: const Text('رفض البلاغ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: acting.value != null ? null : () => review(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    child: const Text('تأكيد البلاغ'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final ChipTone tone;
  final IconData icon;

  const _StatBox({
    required this.label,
    required this.value,
    required this.tone,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10.5, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
