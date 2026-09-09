import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/support/data/ticket_models.dart';
import 'package:nawakes_mobile/features/support/presentation/ticket_thread.dart';
import 'package:intl/intl.dart' show DateFormat;

/// تفاصيل تذكرة — full admin ticket view: reporter, description, related
/// reservation, resolution stepper, and progress/resolve actions.
class AdminTicketDetailScreen extends HookConsumerWidget {
  final AdminTicketDto ticket;

  const AdminTicketDetailScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState(false);
    final resolutionCtrl = useTextEditingController();

    Future<void> act(bool startProgress) async {
      if (!startProgress && resolutionCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اكتب ملخص الحل قبل إغلاق التذكرة.')),
        );
        return;
      }
      busy.value = true;
      try {
        await ref.read(apiClientProvider).resolveTicket(
              ticket.id,
              ResolveTicketRequest(
                startProgress: startProgress,
                resolution: startProgress ? null : resolutionCtrl.text.trim(),
              ),
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(startProgress
                    ? 'التذكرة بقت قيد المعالجة.'
                    : 'التذكرة اتقفلت.')),
          );
          context.pop();
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

    final (statusLabel, statusTone) = switch (ticket.status) {
      'Open' => ('مفتوحة', ChipTone.warning),
      'InProgress' => ('قيد المعالجة', ChipTone.neutral),
      'Resolved' => ('تم الحل', ChipTone.success),
      'Closed' => ('مقفولة', ChipTone.danger),
      _ => (ticket.status, ChipTone.warning),
    };

    final isOpen = ticket.status == 'Open';
    final isInProgress = ticket.status == 'InProgress';

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            NawaqsTopBar(
              eyebrow: 'نواقص / العمليات',
              title: 'التذكرة',
              back: true,
              showBell: false,
              extraActions: [StatusChip(statusLabel, tone: statusTone)],
            ),
            ScreenSubtitle(
                'رقم #${ticket.id.substring(0, 8)} · ${DateFormat('d MMM · HH:mm').format(ticket.createdAt.toLocal())}'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Reporter + subject ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(15),
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
                            Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: AppColors.dangerBg,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                ticket.reporterEmail.isNotEmpty
                                    ? ticket.reporterEmail[0].toUpperCase()
                                    : '؟',
                                style: const TextStyle(
                                    color: AppColors.dangerText,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ticket.subject,
                                      style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${ticket.reporterEmail} · ${_categoryLabel(ticket.category)}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 10),
                        const SectionLabel('وصف المشكلة'),
                        const SizedBox(height: 6),
                        Text(ticket.description,
                            style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.65,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Related entities ─────────────────────────────────────
                  if (ticket.reservationId != null ||
                      ticket.pharmacyId != null)
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('مرتبط بـ'),
                          const SizedBox(height: 10),
                          if (ticket.reservationId != null)
                            InfoCell(
                                label: 'الحجز',
                                value:
                                    '#${ticket.reservationId!.substring(0, 8)}'),
                          if (ticket.pharmacyId != null) ...[
                            const SizedBox(height: 8),
                            InfoCell(
                                label: 'الصيدلية',
                                value: ticket.pharmacyId!.substring(0, 8)),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  // ── Resolution tracker ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('خطوات الحل'),
                        const SizedBox(height: 10),
                        StepperWidget(
                          steps: ticket.status == 'Resolved'
                              ? [
                                  StepperStep.done(
                                      'تم استلام التذكرة', 'اتسجلت في النظام'),
                                  StepperStep.done('تم الحل',
                                      ticket.resolution ?? '—'),
                                ]
                              : isInProgress
                                  ? [
                                      StepperStep.done('تم استلام التذكرة',
                                          'اتسجلت في النظام'),
                                      StepperStep.pending('جاري المعالجة',
                                          'التواصل مع الأطراف وتأكيد التفاصيل',
                                          pendingIcon: Icons.schedule_rounded),
                                    ]
                                  : [
                                      StepperStep.done('تم استلام التذكرة',
                                          'اتسجلت في النظام'),
                                      StepperStep.pending('جاري المعالجة',
                                          'لسه مبدأتش — ابدأ المعالجة تحت',
                                          pendingIcon: Icons.schedule_rounded),
                                    ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 12),

                  // ── محادثة التذكرة (أدمن ↔ مريض) ─────────────────────────
                  TicketThreadSection(
                      ticketId: ticket.id,
                      canReply: true),
                  const SizedBox(height: 12),

                  // ── Actions ──────────────────────────────────────────────
                  if (isOpen || isInProgress) ...[
                    if (isInProgress) ...[
                      TextField(
                        controller: resolutionCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملخص الحل (مطلوب للإغلاق)',
                          hintText: 'مثلاً: تم التواصل مع الصيدلية وتأكيد الحالة…',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        if (isOpen)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: busy.value ? null : () => act(true),
                              icon: const Icon(Icons.play_arrow_rounded,
                                  size: 17),
                              label: const Text('ابدأ المعالجة'),
                              style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(13))),
                            ),
                          ),
                        if (isOpen) const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: busy.value ? null : () => act(false),
                            icon: const Icon(Icons.check_rounded, size: 17),
                            label: const Text('تم الحل'),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand900,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(13))),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              color: AppColors.successText, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                'تم الحل: ${ticket.resolution ?? "—"}',
                                style: const TextStyle(
                                    fontSize: 13, height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String c) => switch (c) {
        'ReservationIssue' => 'مشكلة حجز',
        'InaccurateStock' => 'معلومة غير دقيقة',
        'PharmacyConduct' => 'تعامل الصيدلية',
        'AccountIssue' => 'الحساب',
        _ => 'أخرى',
      };
}
