import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/config.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/support/data/ticket_models.dart';
import 'package:nawakes_mobile/features/support/presentation/ticket_thread.dart';
import 'package:nawakes_mobile/features/reservations/presentation/my_reservations_controller.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/core/services/image_picker_service.dart';
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

      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accentBlue,
          onRefresh: () async => ref.invalidate(myTicketsProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              const NawaqsTopBar(eyebrow: 'نواقص', title: 'التذاكر والبلاغات'),
              const ScreenSubtitle('بلّغ عن مشكلة أو قدّم شكوى وتابع حلها خطوة بخطوة'),
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
                                      onTap: () => showTicketThreadSheet(context, t),
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

class _PharmacyOption {
  final String id;
  final String name;
  const _PharmacyOption({required this.id, required this.name});
}

// ─── New ticket form card ─────────────────────────────────────────────────────
class _NewTicketCard extends HookConsumerWidget {
  final VoidCallback onDone;
  final VoidCallback onCancel;
  const _NewTicketCard({required this.onDone, required this.onCancel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(myReservationsControllerProvider);
    final subjectCtrl = useTextEditingController();
    final descCtrl = useTextEditingController();
    final category = useState<TicketCategory>(TicketCategory.reservationIssue);
    final selectedPharmacy = useState<_PharmacyOption?>(null);
    final selectedReservation = useState<ReservationResponse?>(null);
    final attachmentUrl = useState<String?>(null);
    final isUploading = useState(false);
    final submitting = useState(false);

    // Extract last 3 unique pharmacies from reservations
    final reservations = reservationsAsync.value ?? [];
    final recentPharmacies = useMemoized(() {
      final map = <String, String>{};
      for (final r in reservations) {
        if (r.pharmacyId.isNotEmpty && !map.containsKey(r.pharmacyId)) {
          map[r.pharmacyId] = r.pharmacyName;
          if (map.length >= 5) break;
        }
      }
      return map.entries
          .map((e) => _PharmacyOption(id: e.key, name: e.value))
          .toList();
    }, [reservations]);

    // Reservations filtered by selected pharmacy (up to 3)
    final pharmacyReservations = useMemoized(() {
      if (selectedPharmacy.value == null) return <ReservationResponse>[];
      return reservations
          .where((r) => r.pharmacyId == selectedPharmacy.value!.id)
          .take(5)
          .toList();
    }, [reservations, selectedPharmacy.value]);

    Future<void> pickProofImage() async {
      final picker = ref.read(imagePickerServiceProvider);
      final file = await picker.pickFromGallery(maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (file == null) return;

      isUploading.value = true;
      try {
        final url = await ref.read(apiClientProvider).uploadFilePath(file.path);
        attachmentUrl.value = url;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرفاق صورة الإثبات بنجاح.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل رفع الصورة: ${describeApiError(e)}')),
          );
        }
      } finally {
        isUploading.value = false;
      }
    }

    String categoryToLabel(TicketCategory cat) {
      switch (cat) {
        case TicketCategory.reservationIssue:
          return 'مشكلة حجز';
        case TicketCategory.inaccurateStock:
          return 'معلومة غير دقيقة';
        case TicketCategory.pharmacyConduct:
          return 'تعامل الصيدلية';
        case TicketCategory.accountIssue:
          return 'مشكلة حساب';
        case TicketCategory.other:
          return 'أخرى';
      }
    }

    Future<void> submit() async {
      submitting.value = true;
      try {
        await ref.read(apiClientProvider).createTicket(CreateTicketRequest(
              subject: subjectCtrl.text.trim(),
              description: descCtrl.text.trim(),
              category: category.value,
              pharmacyId: selectedPharmacy.value?.id,
              reservationId: selectedReservation.value?.id,
              attachmentUrl: attachmentUrl.value,
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

    Future<void> reviewAndSubmit() async {
      if (subjectCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اكتب الموضوع والوصف.')),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.rate_review_outlined, color: AppColors.brand900, size: 22),
              SizedBox(width: 8),
              Text('مراجعة بيانات التذكرة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TicketReviewRow(label: 'التصنيف', value: categoryToLabel(category.value)),
                if (selectedPharmacy.value != null)
                  _TicketReviewRow(label: 'الصيدلية المعنية', value: selectedPharmacy.value!.name),
                if (selectedReservation.value != null)
                  _TicketReviewRow(label: 'الطلب المرتبط', value: selectedReservation.value!.medicationName),
                _TicketReviewRow(label: 'الموضوع', value: subjectCtrl.text.trim()),
                _TicketReviewRow(label: 'التفاصيل', value: descCtrl.text.trim()),
                if (attachmentUrl.value != null)
                  const _TicketReviewRow(label: 'المرفقات', value: 'تم إرفاق صورة إثبات/مستند ✓'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('تعديل التذكرة'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('تأكيد وإرسال التذكرة'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await submit();
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

          // ── Recent Pharmacies Selector ──────────────────────────────
          if (recentPharmacies.isNotEmpty) ...[
            const Text(
              'الصيدلية محل المشكلة (من آخر تعاملاتك):',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ...recentPharmacies.map((p) {
                  final isSelected = selectedPharmacy.value?.id == p.id;
                  return ChoiceChip(
                    label: Text(p.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      selectedPharmacy.value = selected ? p : null;
                      selectedReservation.value = null;
                    },
                    selectedColor: AppColors.accentBlueBg,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.accentBlue : AppColors.textPrimary,
                    ),
                  );
                }),
                if (selectedPharmacy.value != null)
                  ActionChip(
                    avatar: const Icon(Icons.close_rounded, size: 14),
                    label: const Text('إلغاء التحديد'),
                    onPressed: () {
                      selectedPharmacy.value = null;
                      selectedReservation.value = null;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // ── Specific Reservation at Pharmacy Dropdown ───────────────
          if (selectedPharmacy.value != null && pharmacyReservations.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الطلب أو الحجز المرتبط بالمشكلة:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedReservation.value?.id,
                    hint: const Text('اختر الحجز أو الدواء المتأثر', style: TextStyle(fontSize: 12.5)),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('شكوى عامة بدون حجز محدد', style: TextStyle(fontSize: 12)),
                      ),
                      ...pharmacyReservations.map((r) => DropdownMenuItem<String>(
                            value: r.id,
                            child: Text(
                              '${r.medicationName} (كود #${r.reservationCode}) · ${DateFormat('d MMM').format(r.createdAt.toLocal())}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (val) {
                      if (val == null) {
                        selectedReservation.value = null;
                      } else {
                        final found = pharmacyReservations.firstWhere((r) => r.id == val);
                        selectedReservation.value = found;
                        if (subjectCtrl.text.isEmpty) {
                          subjectCtrl.text = 'مشكلة في حجز ${found.medicationName}';
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

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

          // ── Photo Attachment Section ────────────────────────────────
          const SectionLabel('صورة إثبات (اختياري)'),
          const SizedBox(height: 6),
          if (attachmentUrl.value != null) ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    attachmentUrl.value!.startsWith('http')
                        ? attachmentUrl.value!
                        : '${AppConfig.apiBaseUrl.replaceAll('/api/v1', '')}${attachmentUrl.value}',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image_rounded),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 16, color: AppColors.successText),
                          SizedBox(width: 4),
                          Text('تم إرفاق الصورة كإثبات',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.successText)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () => attachmentUrl.value = null,
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.dangerText),
                        label: const Text('حذف الصورة', style: TextStyle(color: AppColors.dangerText, fontSize: 12)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ] else ...[
            OutlinedButton.icon(
              onPressed: isUploading.value ? null : pickProofImage,
              icon: isUploading.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(isUploading.value ? 'جاري رفع الصورة…' : 'إرفاق صورة إثبات / روشتة / إيصال'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
          ],

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
                  onPressed: (submitting.value || isUploading.value) ? null : reviewAndSubmit,
                  style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13))),
                  child: submitting.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('مراجعة وإرسال التذكرة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _TicketReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 1),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
          if (ticket.attachmentUrl != null && ticket.attachmentUrl!.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.attachment_rounded, size: 14, color: AppColors.accentBlue),
                SizedBox(width: 4),
                Text('يوجد صورة إثبات مرفقة', style: TextStyle(fontSize: 11, color: AppColors.accentBlue, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
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
