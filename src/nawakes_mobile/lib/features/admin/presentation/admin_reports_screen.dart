import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/admin/data/admin_models.dart';
import 'package:intl/intl.dart' show DateFormat;

part 'admin_reports_screen.g.dart';

@riverpod
Future<List<AdminReportDto>> pendingReports(Ref ref) async {
  return ref.read(apiClientProvider).getAdminReports(true);
}

/// مراجعة البلاغات — community reports moderation (confirm / dismiss).
class AdminReportsScreen extends HookConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pendingReportsProvider);
    final showAll = useState(false);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accentBlue,
          onRefresh: () async => ref.invalidate(pendingReportsProvider),
          child: state.when(
            data: (reports) {
              final pending = reports
                  .where((r) => r.status == 'Pending')
                  .toList();
              final shown = showAll.value ? reports : pending;

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  NawaqsTopBar(
                    eyebrow: 'نواقص / العمليات',
                    title: 'مراجعة البلاغات',
                    back: true,
                    showBell: false,
                  ),
                  ScreenSubtitle(
                      'بلاغات المجتمع عن توفر الأدوية — تأكيدها بيرفع ثقة الصيدلية'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Pill(
                                label: 'معلقة (${pending.length})',
                                active: !showAll.value,
                                onTap: () => showAll.value = false),
                            const SizedBox(width: 8),
                            _Pill(
                                label: 'الكل (${reports.length})',
                                active: showAll.value,
                                onTap: () => showAll.value = true),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (shown.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppColors.successBg,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    color: AppColors.successText, size: 22),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                      'مفيش بلاغات معلقة — كل حاجة اتذراست',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.successText)),
                                ),
                              ],
                            ),
                          )
                        else
                          ...shown.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ReportCard(report: r),
                              )),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accentBlue)),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تعذر تحميل البلاغات',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(pendingReportsProvider),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Pill(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.accentBlueBg : const Color(0xFFF1F2F4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color:
                    active ? AppColors.accentBlue : AppColors.textSecondary)),
      ),
    );
  }
}

class _ReportCard extends HookConsumerWidget {
  final AdminReportDto report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState(false);
    final pending = report.status == 'Pending';

    Future<void> act(bool confirm) async {
      busy.value = true;
      try {
        await ref.read(apiClientProvider).reviewReport(
              report.id,
              ReviewReportRequest(confirm: confirm),
            );
        ref.invalidate(pendingReportsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(confirm
                    ? 'البلاغ اتأكد — درجة ثقة الصيدلية هتتأثر.'
                    : 'البلاغ اترفض.')),
          );
        }
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

    final isFound = report.type == 'Found';
    final (typeLabel, typeIcon, typeColor) = isFound
        ? (
            'لقيت الدواء هنا',
            Icons.check_circle_outline_rounded,
            AppColors.successText
          )
        : (
            'معلومة مش دقيقة',
            Icons.error_outline_rounded,
            AppColors.dangerText
          );

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
              Icon(typeIcon, color: typeColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    '"$typeLabel" — ${report.medicationName ?? "دواء غير محدد"}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('في ${report.pharmacyName} · بلاغ من ${report.reporterEmail}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          if (report.description != null &&
              report.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(report.description!,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.5)),
          ],
          const SizedBox(height: 6),
          Text(
              DateFormat('d MMM · hh:mm a').format(report.createdAt.toLocal()),
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy.value ? null : () => act(true),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('تأكيد'),
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
                    onPressed: busy.value ? null : () => act(false),
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
          ] else ...[
            const SizedBox(height: 8),
            StatusChip(
              report.status == 'Confirmed' ? 'مؤكد' : 'مرفوض',
              tone: report.status == 'Confirmed'
                  ? ChipTone.success
                  : ChipTone.danger,
            ),
          ],
        ],
      ),
    );
  }
}
