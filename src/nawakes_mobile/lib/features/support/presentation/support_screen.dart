import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/support/data/ticket_models.dart';
import 'package:nawakes_mobile/features/support/presentation/ticket_thread.dart';
import 'package:intl/intl.dart' show DateFormat;

part 'support_screen.g.dart';

@riverpod
Future<List<TicketDto>> myTickets(Ref ref) async {
  return ref.read(apiClientProvider).getMyTickets();
}

/// الدعم — my tickets + new ticket form (mockup's support module).
class SupportScreen extends HookConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsState = ref.watch(myTicketsProvider);
    final showForm = useState(false);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accentBlue,
          onRefresh: () async => ref.invalidate(myTicketsProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              const NawaqsTopBar(eyebrow: 'نواقص', title: 'الدعم'),
              const ScreenSubtitle('بلّغ عن مشكلة وتابع حلها خطوة بخطوة'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!showForm.value) ...[
                      FilledButton.icon(
                        onPressed: () => showForm.value = true,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('تذكرة جديدة'),
                        style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13))),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (showForm.value)
                      _NewTicketCard(
                        onDone: () {
                          showForm.value = false;
                          ref.invalidate(myTicketsProvider);
                        },
                        onCancel: () => showForm.value = false,
                      ),
                    const SizedBox(height: 4),
                    ticketsState.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.accentBlue)),
                      ),
                      error: (e, _) => const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('تعذر تحميل التذاكر',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      data: (tickets) {
                        if (tickets.isEmpty && !showForm.value) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.help_outline_rounded,
                                    size: 40, color: AppColors.textMuted),
                                SizedBox(height: 10),
                                Text('مفيش تذاكر مفتوحة',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15)),
                                SizedBox(height: 4),
                                Text(
                                  'لو حصلت مشكلة في حجز أو معلومة توفر غير دقيقة، افتح تذكرة وهنتابعها.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                      height: 1.55),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (tickets.isNotEmpty) ...[
                              const SectionLabel('تذاكري'),
                              const SizedBox(height: 8),
                              ...tickets.map((t) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: GestureDetector(
                                      onTap: () => showTicketThreadSheet(
                                          context, t.id, t.subject),
                                      child: _TicketRow(ticket: t),
                                    ),
                                  ))
                            ],
                          ],
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

// ─── New ticket form card ─────────────────────────────────────────────────────
class _NewTicketCard extends HookConsumerWidget {
  final VoidCallback onDone;
  final VoidCallback onCancel;
  const _NewTicketCard({required this.onDone, required this.onCancel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectCtrl = useTextEditingController();
    final descCtrl = useTextEditingController();
    final category = useState<TicketCategory>(TicketCategory.other);
    final submitting = useState(false);

    Future<void> submit() async {
      if (subjectCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اكتب الموضوع والوصف.')),
        );
        return;
      }
      submitting.value = true;
      try {
        await ref.read(apiClientProvider).createTicket(CreateTicketRequest(
              subject: subjectCtrl.text.trim(),
              description: descCtrl.text.trim(),
              category: category.value,
            ));
        subjectCtrl.clear();
        descCtrl.clear();
        onDone();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('التذكرة اتسجلت وهنتابعها.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      } finally {
        submitting.value = false;
      }
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('تذكرة جديدة'),
          const SizedBox(height: 10),
          TextField(
            controller: subjectCtrl,
            decoration: const InputDecoration(
                hintText: 'الموضوع — مثلاً: الدواء مكانش موجود'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'اشرح المشكلة بالتفصيل…'),
          ),
          const SizedBox(height: 10),
          const SectionLabel('النوع'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CategoryChip(
                  label: 'مشكلة حجز',
                  selected: category.value == TicketCategory.reservationIssue,
                  onTap: () => category.value = TicketCategory.reservationIssue),
              _CategoryChip(
                  label: 'معلومة غير دقيقة',
                  selected: category.value == TicketCategory.inaccurateStock,
                  onTap: () => category.value = TicketCategory.inaccurateStock),
              _CategoryChip(
                  label: 'تعامل الصيدلية',
                  selected: category.value == TicketCategory.pharmacyConduct,
                  onTap: () => category.value = TicketCategory.pharmacyConduct),
              _CategoryChip(
                  label: 'أخرى',
                  selected: category.value == TicketCategory.other,
                  onTap: () => category.value = TicketCategory.other),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13))),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: submitting.value ? null : submit,
                  style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13))),
                  child: submitting.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('إرسال'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentBlueBg : const Color(0xFFF1F2F4),
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? Border.all(color: AppColors.accentBlue, width: 1.2)
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.accentBlue : AppColors.textSecondary)),
      ),
    );
  }
}

// ─── Ticket row ───────────────────────────────────────────────────────────────
class _TicketRow extends StatelessWidget {
  final TicketDto ticket;
  const _TicketRow({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (ticket.status) {
      'Open' => ('مفتوحة', ChipTone.warning),
      'InProgress' => ('قيد المعالجة', ChipTone.neutral),
      'Resolved' => ('تم الحل', ChipTone.success),
      'Closed' => ('مقفولة', ChipTone.danger),
      _ => (ticket.status, ChipTone.warning),
    };

    return Container(
      padding: const EdgeInsets.all(13),
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
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              StatusChip(label, tone: tone),
            ],
          ),
          const SizedBox(height: 4),
          Text(ticket.description,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(
              '${_categoryLabel(ticket.category)} · ${DateFormat('d MMM · hh:mm a').format(ticket.createdAt.toLocal())}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          if (ticket.resolution != null && ticket.resolution!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('الحل: ${ticket.resolution}',
                  style: const TextStyle(fontSize: 12, height: 1.5)),
            ),
          ],
        ],
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
