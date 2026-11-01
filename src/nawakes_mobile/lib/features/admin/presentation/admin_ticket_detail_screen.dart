import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/config.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/support/data/ticket_models.dart';
import 'package:nawakes_mobile/features/support/presentation/ticket_thread.dart';
import 'package:nawakes_mobile/features/admin/data/admin_models.dart';
import 'package:nawakes_mobile/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:nawakes_mobile/features/admin/presentation/pharmacy_review_screen.dart';
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
    final pharmaciesState = ref.watch(adminPharmaciesProvider(all: true));

    final AdminPharmacyDto? linkedPharmacy = ticket.pharmacyId != null
        ? pharmaciesState.value?.cast<AdminPharmacyDto?>().firstWhere(
            (p) => p?.id.toLowerCase() == ticket.pharmacyId!.toLowerCase(),
            orElse: () => null,
          )
        : null;

    Future<void> act(bool startProgress) async {
      if (!startProgress && resolutionCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى كتابة ملخص الحل قبل إغلاق التذكرة.')),
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
          final targetFilter = startProgress ? 'InProgress' : 'Closed';
          ref.read(adminTicketSubTabProvider.notifier).state = 0;
          ref.read(adminTicketFilterProvider.notifier).state = targetFilter;
          ref.read(adminDashboardTabProvider.notifier).state = 4;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(startProgress
                  ? 'تم تحويل التذكرة إلى قيد المعالجة.'
                  : 'تم إغلاق التذكرة وتأكيد الحل.'),
            ),
          );
          context.pop(targetFilter);
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
      'InProgress' || 'InReview' => ('قيد المعالجة', ChipTone.neutral),
      'Resolved' => ('تم الحل', ChipTone.success),
      'Closed' => ('مغلقة', ChipTone.danger),
      _ => (ticket.status, ChipTone.warning),
    };

    final isOpen = ticket.status == 'Open';
    final isInProgress = ticket.status == 'InProgress' || ticket.status == 'InReview';

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

                  // ── Evidence photo attachment ───────────────────────────
                  if (ticket.attachmentUrl != null && ticket.attachmentUrl!.isNotEmpty) ...[
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
                          const SectionLabel('صورة الإثبات المرفقة من المريض'),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      ticket.attachmentUrl!.startsWith('http')
                                          ? ticket.attachmentUrl!
                                          : '${AppConfig.apiBaseUrl.replaceAll('/api/v1', '')}${ticket.attachmentUrl}',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                children: [
                                  Image.network(
                                    ticket.attachmentUrl!.startsWith('http')
                                        ? ticket.attachmentUrl!
                                        : '${AppConfig.apiBaseUrl.replaceAll('/api/v1', '')}${ticket.attachmentUrl}',
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(20),
                                        child: Icon(Icons.broken_image_rounded, size: 36),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text('اضغط للتكبير', style: TextStyle(color: Colors.white, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Related pharmacy details & quick action ──────────────
                  if (linkedPharmacy != null) ...[
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
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.accentBlueBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.local_pharmacy_rounded, color: AppColors.accentBlue, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      linkedPharmacy.name,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                    ),
                                    Text(
                                      '${linkedPharmacy.addressLine} · ${linkedPharmacy.phone}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PharmacyReviewScreen(pharmacy: linkedPharmacy),
                                ),
                              );
                            },
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                            label: const Text('عرض بيانات وتراخيص الصيدلية بالكامل'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accentBlue,
                              minimumSize: const Size(double.infinity, 40),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else if (ticket.pharmacyId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: InfoCell(
                        label: 'معرّف الصيدلية',
                        value: ticket.pharmacyId!.substring(0, 8),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (ticket.reservationId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: InfoCell(
                        label: 'الحجز المرتبط',
                        value: '#${ticket.reservationId!.substring(0, 8)}',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

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
                                      'تم استلام التذكرة', 'تم تسجيلها في النظام'),
                                  StepperStep.done('تم الحل',
                                      ticket.resolution ?? '—'),
                                ]
                              : isInProgress
                                  ? [
                                      StepperStep.done('تم استلام التذكرة',
                                          'تم تسجيلها في النظام'),
                                      StepperStep.pending('جاري المعالجة',
                                          'التواصل مع الأطراف وتأكيد التفاصيل',
                                          pendingIcon: Icons.schedule_rounded),
                                    ]
                                  : [
                                      StepperStep.done('تم استلام التذكرة',
                                          'تم تسجيلها في النظام'),
                                      StepperStep.pending('جاري المعالجة',
                                          'بانتظار البدء — اضغط على ابدأ المعالجة أدناه',
                                          pendingIcon: Icons.schedule_rounded),
                                    ],
                        ),
                      ],
                    ),
                  ),
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
                          SizedBox(width: 10),
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
