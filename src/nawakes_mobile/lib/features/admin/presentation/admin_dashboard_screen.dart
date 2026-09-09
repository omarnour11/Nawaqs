import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/admin/data/admin_models.dart';
import 'package:nawakes_mobile/features/support/data/ticket_models.dart';
import 'package:intl/intl.dart' show DateFormat;

part 'admin_dashboard_screen.g.dart';

@riverpod
Future<DashboardStatsDto> adminStats(Ref ref) async {
  return ref.read(apiClientProvider).getAdminStats();
}

@riverpod
Future<List<AdminPharmacyDto>> adminPharmacies(Ref ref) async {
  return ref.read(apiClientProvider).getAdminPharmacies(false);
}

@riverpod
Future<List<AdminReportDto>> adminReports(Ref ref) async {
  return ref.read(apiClientProvider).getAdminReports(true);
}

@riverpod
Future<List<AdminTicketDto>> adminTickets(Ref ref) async {
  return ref.read(apiClientProvider).getAdminTicketQueue();
}

/// الثقة والامتثال — operations home per mockup:
/// network health card, pending/attention stats, verification queue.
class AdminDashboardScreen extends HookConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final pharmacies = ref.watch(adminPharmaciesProvider);
    final tickets = ref.watch(adminTicketsProvider);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accentBlue,
          onRefresh: () async {
            ref.invalidate(adminStatsProvider);
            ref.invalidate(adminPharmaciesProvider);
            ref.invalidate(adminTicketsProvider);
            ref.invalidate(adminReportsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              NawaqsTopBar(
                eyebrow: 'نواقص / العمليات',
                title: 'الثقة والامتثال',
                onBell: () => context.push('/notifications'),
                extraActions: [
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 21),
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ],
              ),
              const ScreenSubtitle('حافظ على شبكة الرعاية واضحة وموثوقة'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Network health card ─────────────────────────────────
                    stats.when(
                      loading: () => const SizedBox(
                          height: 120,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.accentBlue))),
                      error: (e, _) => const Text('تعذر تحميل الإحصائيات'),
                      data: (s) => Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                    child: SectionLabel('صحة الشبكة')),
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                          color: AppColors.successIcon,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text('مباشر',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.successText)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${(s.averageTrustScore).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    const Text('متوسط درجة الثقة',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${s.approvedPharmacies}',
                                        style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    const Text('صيدليات موثقة',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded,
                                        size: 15, color: AppColors.successIcon),
                                    const SizedBox(width: 6),
                                    Text(
                                        '${s.inStockItems} دواء متاح · ${s.outOfStockItems} ناقص',
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.successText)),
                                  ],
                                ),
                                Text('${s.totalPharmacies} صيدلية',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Pending / attention stats ───────────────────────────
                    stats.maybeWhen(
                      data: (s) => GestureDetector(
                        onTap: () => context.push('/admin/reports'),
                        child: Row(
                          children: [
                            Expanded(
                              child: StatCardNeutral(
                                value: s.pendingApprovals,
                                label: 'قيد الانتظار',
                                icon: Icons.description_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StatCardTintedSmall(
                                value: s.pendingReports,
                                label: 'بلاغات معلقة',
                                icon: Icons.warning_amber_outlined,
                                bg: AppColors.warningBg,
                                fg: AppColors.warningText,
                                iconColor: AppColors.warningIcon,
                              ),
                            ),
                          ],
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 10),

                    // Reports moderation link
                    _LinkRow(
                      icon: Icons.rate_review_outlined,
                      label: 'مراجعة البلاغات',
                      trailing: stats.value?.pendingReports ?? 0,
                      onTap: () => context.push('/admin/reports'),
                    ),
                    const SizedBox(height: 14),

                    // ── Verification queue ──────────────────────────────────
                    const Row(
                      children: [
                        SectionLabel('قائمة التحقق'),
                      ],
                    ),
                    const Text('بيانات اعتماد الصيدليات',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    pharmacies.when(
                      loading: () => const Center(
                          child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            color: AppColors.accentBlue),
                      )),
                      error: (e, _) => const Text('تعذر تحميل القائمة'),
                      data: (list) {
                        final pending = list
                            .where((p) => p.verificationStatus == 'Pending')
                            .toList();
                        if (pending.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.successBg,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    color: AppColors.successText, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text('مفيش طلبات توثيق معلقة',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.successText)),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: pending
                              .map((p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _QueueCard(pharmacy: p),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── Support ticket queue ────────────────────────────────
                    const SectionLabel('تذاكر الدعم'),
                    const SizedBox(height: 8),
                    tickets.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                      data: (list) {
                        if (list.isEmpty) {
                          return const Text('مفيش تذاكر مفتوحة',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary));
                        }
                        return Column(
                          children: list
                              .map((t) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: GestureDetector(
                                      onTap: () => context.push(
                                          '/admin/ticket-detail',
                                          extra: t),
                                      child: _TicketQueueCard(ticket: t),
                                    ),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Neutral stat card ──────────────────────────────────────────────────────────
class StatCardNeutral extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  const StatCardNeutral(
      {super.key,
      required this.value,
      required this.label,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.topStart,
            child: Icon(icon, size: 16, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Text('$value',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ── Tinted stat card (small) ──────────────────────────────────────────────────
class StatCardTintedSmall extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color iconColor;

  const StatCardTintedSmall({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.topStart,
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text('$value',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: fg, height: 1.1)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: fg.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

// ── Verification queue card ───────────────────────────────────────────────────
class _QueueCard extends HookConsumerWidget {
  final AdminPharmacyDto pharmacy;
  const _QueueCard({required this.pharmacy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewing = useState(false);

    Future<void> review(bool approve) async {
      String? reason;
      if (!approve) {
        final controller = TextEditingController();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('رفض الصيدلية'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'سبب الرفع للصيدلي…'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.dangerText),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('رفض')),
            ],
          ),
        );
        if (confirmed != true) return;
        reason = controller.text.trim();
        if (reason.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('سبب الرفض مطلوب.')),
            );
          }
          return;
        }
      }

      reviewing.value = true;
      try {
        await ref.read(apiClientProvider).reviewPharmacy(
              pharmacy.id,
              ReviewPharmacyRequest(approve: approve, rejectionReason: reason),
            );
        ref.invalidate(adminPharmaciesProvider);
        ref.invalidate(adminStatsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(approve
                    ? '${pharmacy.name} توثقت.'
                    : '${pharmacy.name} اترفضت.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      } finally {
        reviewing.value = false;
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pharmacy.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        '${pharmacy.city} · ${DateFormat('d MMM · HH:mm').format(pharmacy.createdAt.toLocal())}',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.description_outlined,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                  '${(pharmacy.licenseDocUrl?.isNotEmpty == true ? 1 : 0) + (pharmacy.nationalIdDocUrl?.isNotEmpty == true ? 1 : 0)} من 2 مستندات',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: reviewing.value ? null : () => review(true),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('توثيق'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.successText,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: reviewing.value ? null : () => review(false),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('رفض'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.dangerText,
                      side: const BorderSide(
                          color: AppColors.dangerIcon, width: 1.3),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Support ticket queue card ─────────────────────────────────────────────────
class _TicketQueueCard extends HookConsumerWidget {
  final AdminTicketDto ticket;
  const _TicketQueueCard({required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState(false);

    Future<void> act(bool startProgress) async {
      busy.value = true;
      try {
        await ref.read(apiClientProvider).resolveTicket(
              ticket.id,
              ResolveTicketRequest(startProgress: startProgress, resolution: startProgress ? null : 'تم التواصل مع الصيدلية وتأكيد الحالة.'),
            );
        ref.invalidate(adminTicketsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      } finally {
        busy.value = false;
      }
    }

    final (statusLabel, tone) = switch (ticket.status) {
      'Open' => ('مفتوحة', ChipTone.warning),
      'InProgress' => ('قيد المعالجة', ChipTone.neutral),
      _ => (ticket.status, ChipTone.success),
    };

    return Container(
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Text(ticket.subject,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              StatusChip(statusLabel, tone: tone),
            ],
          ),
          const SizedBox(height: 4),
          Text(ticket.reporterEmail,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy.value ? null : () => act(true),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('ابدأ المعالجة'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy.value ? null : () => act(false),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('تم الحل'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand900,
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Simple tappable link row (admin quick actions).
class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? trailing;
  final VoidCallback onTap;

  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
              if (trailing != null && trailing! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('$trailing',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warningText)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
