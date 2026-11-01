import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_dashboard_models.dart';


class ActiveOrdersTab extends HookConsumerWidget {
  const ActiveOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pharmacyReservationsControllerProvider);

    return state.when(
      loading: () => const _LoadingShimmer(),
      error: (e, _) => _ErrorBanner(
        message: e.toString(),
        onRetry: () => ref.invalidate(pharmacyReservationsControllerProvider),
      ),
      data: (reservations) {
        final activeReservations = reservations
            .where((r) =>
                (r.status == 'Active' || r.status == 'Ready') &&
                (r.status == 'Ready' || r.expiresAt.toUtc().isAfter(DateTime.now().toUtc())))
            .toList();

        if (activeReservations.isEmpty) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(pharmacyReservationsControllerProvider),
            child: ListView(
              children: const [
                SizedBox(height: 160),
                _EmptyOrders(),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(pharmacyReservationsControllerProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: activeReservations.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OrderCard(reservation: activeReservations[i], ref: ref),
            ),
          ),
        );
      },
    );
  }
}

class _OrderCard extends HookWidget {
  final dynamic reservation;
  final WidgetRef ref;
  const _OrderCard({required this.reservation, required this.ref});

  @override
  Widget build(BuildContext context) {
    final now = useState(DateTime.now().toUtc());
    final isCompleting = useState(false);

    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        now.value = DateTime.now().toUtc();
      });
      return timer.cancel;
    }, const []);

    final expiresAt = reservation.expiresAt.isUtc
        ? reservation.expiresAt
        : reservation.expiresAt.toUtc();
    final remaining = expiresAt.difference(now.value);
    final isExpired = remaining.isNegative && reservation.status != 'Completed';
    final isActive = reservation.status == 'Active';
    final isReady = reservation.status == 'Ready';
    final isCompleted = reservation.status == 'Completed';

    String countdown() {
      if (isCompleted) return 'تم الاستلام';
      if (isReady) {
        return 'جاهز للاستلام';
      }
      if (isExpired) return 'انتهت المهلة';
      final h = remaining.inHours.toString().padLeft(2, '0');
      final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
      final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }

    String statusArabic(String status) {
      switch (status) {
        case 'Active':
          return 'محجوز';
        case 'Ready':
          return 'جاهز للاستلام';
        case 'Completed':
          return 'تم الاستلام';
        case 'Cancelled':
          return 'ملغي';
        case 'Expired':
          return 'منتهي';
        default:
          return status;
      }
    }

    Color statusColor() {
      switch (reservation.status) {
        case 'Active':
          return AppColors.accent;
        case 'Ready':
          return AppColors.success;
        case 'Completed':
          return AppColors.success;
        case 'Cancelled':
          return AppColors.danger;
        case 'Expired':
          return AppColors.textHint;
        default:
          return AppColors.textSecondary;
      }
    }

    final hasClinicalData = (reservation.allergies != null && reservation.allergies!.isNotEmpty) ||
        (reservation.chronicConditions != null && reservation.chronicConditions!.isNotEmpty) ||
        reservation.allowPharmacistViewActiveMedications;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showClinicalReviewSheet(context, ref, reservation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Dedicated Prominent Requested Medication Banner ───────
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.brand700.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brand700.withValues(alpha: 0.25), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brand900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.medication_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الدواء المطلوب للاستلام:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reservation.medicationName,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brand900,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: const Text(
                        '1 علبة',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.brand900),
                      ),
                    ),
                  ],
                ),
              ),

              // Header row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reservation.medicationName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined,
                                size: 13, color: AppColors.accentBlue),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                reservation.patientDisplayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusArabic(reservation.status),
                      style: TextStyle(
                        color: statusColor(),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              // Clinical Safety Preview Pill
              if (hasClinicalData) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showClinicalReviewSheet(context, ref, reservation),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: reservation.allergies != null && reservation.allergies!.isNotEmpty
                          ? AppColors.dangerBg
                          : AppColors.accentBlueBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: reservation.allergies != null && reservation.allergies!.isNotEmpty
                            ? AppColors.dangerIcon.withValues(alpha: 0.3)
                            : AppColors.accentBlue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          reservation.allergies != null && reservation.allergies!.isNotEmpty
                              ? Icons.warning_amber_rounded
                              : Icons.health_and_safety_outlined,
                          size: 16,
                          color: reservation.allergies != null && reservation.allergies!.isNotEmpty
                              ? AppColors.dangerText
                              : AppColors.accentBlue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reservation.allergies != null && reservation.allergies!.isNotEmpty
                                ? 'يوجد تنبيه حساسية طبية مسجلة من المريض · اضغط للفحص'
                                : 'الملف الطبي للمريض متاح للمراجعة السريرية · اضغط للفحص',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: reservation.allergies != null && reservation.allergies!.isNotEmpty
                                  ? AppColors.dangerText
                                  : AppColors.accentBlue,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded, size: 16, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Info row
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.qr_code_rounded,
                      label: 'كود الاستلام',
                      value: reservation.reservationCode,
                    ),
                  ),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.timer_outlined,
                      label: isReady ? 'حالة الحجز' : 'صلاحية الحجز',
                      value: countdown(),
                      valueColor: isReady
                          ? AppColors.success
                          : (isExpired
                              ? AppColors.danger
                              : remaining.inMinutes < 10
                                  ? AppColors.warning
                                  : AppColors.success),
                    ),
                  ),
                ],
              ),

              if (isActive || isReady) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    // جاهز للاستلام (لو لسه Active)
                    if (isActive) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isCompleting.value
                              ? null
                              : () async {
                                  isCompleting.value = true;
                                  try {
                                    await ref
                                        .read(pharmacyReservationsControllerProvider.notifier)
                                        .markReady(reservation.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('الحجز اتعلّم "جاهز للاستلام".')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(describeApiError(e))),
                                      );
                                    }
                                  } finally {
                                    isCompleting.value = false;
                                  }
                                },
                          icon: const Icon(Icons.task_outlined, size: 16),
                          label: const Text('جاهز'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            side: const BorderSide(color: AppColors.hairline),
                            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // اتسلم (Complete)
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: isCompleting.value
                            ? null
                            : () async {
                                isCompleting.value = true;
                                try {
                                  await ref
                                      .read(pharmacyReservationsControllerProvider.notifier)
                                      .completeReservation(reservation.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('الاستلام اتم بنجاح.')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(describeApiError(e))),
                                    );
                                  }
                                } finally {
                                  isCompleting.value = false;
                                }
                              },
                        icon: isCompleting.value
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_rounded, size: 16),
                        label: Text(isCompleting.value ? 'جارٍ…' : 'تم الاستلام'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // إلغاء
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isCompleting.value
                            ? null
                            : () => _cancelDialog(context, ref, reservation.id),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('إلغاء'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dangerText,
                          side: const BorderSide(color: AppColors.dangerIcon, width: 1.2),
                          minimumSize: const Size(0, 40),
                          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (reservation.status == 'Expired') ...[
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'انتهى الحجز تلقائياً — الصنف رجع للمخزون.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textHint),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _cancelDialog(
    BuildContext context, WidgetRef ref, String reservationId) async {
  final reasonCtrl = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('إلغاء الحجز'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('المخزون هيرجع متاح فورًا وهيتبلغ المريض.',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'السبب (اختياري) — مثلاً: المريض ما ظهرش',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع')),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.dangerText),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء الحجز')),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref
        .read(pharmacyReservationsControllerProvider.notifier)
        .cancelReservation(reservationId, reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الحجز اتلغى والمخزون رجع متاح.')),
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

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoItem({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textHint),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text('لا توجد طلبات جارية', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'ستظهر حجوزات المرضى الجديدة هنا فور وصولها بشكل لحظي.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          4,
          (i) => Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 52),
            const SizedBox(height: 16),
            Text('تعذر تحميل الطلبات', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}


/// Bottom Sheet for Pharmacist Clinical Review (Allergies, Chronic Conditions, Active Medications, and Alternatives)
void _showClinicalReviewSheet(BuildContext context, WidgetRef ref, dynamic reservation) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final allergies = (reservation.allergies ?? '').trim();
      final chronic = (reservation.chronicConditions ?? '').trim();
      final List<String> activeMeds = reservation.activeMedications != null
          ? List<String>.from(reservation.activeMedications!)
          : [];
      final bool allowsMeds = reservation.allowPharmacistViewActiveMedications;

      final anonCode = reservation.reservationCode.replaceAll('-', '');
      final patientTag = anonCode.length >= 4
          ? 'مريض #${anonCode.substring(0, 4).toUpperCase()}'
          : 'مريض #${reservation.reservationCode}';

      return DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ListView(
              controller: scrollCtrl,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlueBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.health_and_safety_rounded,
                          color: AppColors.accentBlue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'المراجعة السريرية للطلب',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '$patientTag · طلب: ${reservation.medicationName}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Allergies Section ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: allergies.isNotEmpty ? AppColors.dangerBg : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: allergies.isNotEmpty
                          ? AppColors.dangerIcon.withValues(alpha: 0.4)
                          : AppColors.hairline,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            allergies.isNotEmpty
                                ? Icons.warning_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: allergies.isNotEmpty
                                ? AppColors.dangerText
                                : AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'الحساسية الطبية المسجلة',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: allergies.isNotEmpty
                                  ? AppColors.dangerText
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (allergies.isNotEmpty) ...[
                        Text(
                          allergies,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dangerText,
                              height: 1.4),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'يرجى التأكد من عدم وجود تعارض تحسسي بين هذا الدواء والحساسية المذكورة.',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.dangerText),
                        ),
                      ] else ...[
                        const Text(
                          'لا توجد حساسية دوائية مسجلة من قبل المريض.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Chronic Conditions Section ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.monitor_heart_outlined,
                              size: 18, color: AppColors.accentBlue),
                          SizedBox(width: 8),
                          Text(
                            'الأمراض المزمنة للمريض',
                            style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (chronic.isNotEmpty) ...[
                        Text(
                          chronic,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.4),
                        ),
                      ] else ...[
                        const Text(
                          'لا توجد أمراض مزمنة مسجلة.',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Active Medications Section ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.medication_liquid_outlined,
                              size: 18, color: AppColors.accentBlue),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'أدوية المريض الحالية (لفحص التداخلات)',
                              style: TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: allowsMeds
                                  ? AppColors.successBg
                                  : AppColors.fieldBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              allowsMeds ? 'بإذن المريض' : 'غير مشاركة',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: allowsMeds
                                    ? AppColors.successText
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!allowsMeds) ...[
                        const Text(
                          'المريض لم يفعل خيار مشاركة أدويته الحالية.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ] else if (activeMeds.isEmpty) ...[
                        const Text(
                          'لا يتناول المريض أدوية نشطة مسجلة حالياً.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ] else ...[
                        ...activeMeds.map((med) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle,
                                      size: 6, color: AppColors.accentBlue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      med,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Clinical Decision Buttons ─────────────────────────────────
                if (reservation.status == 'Active' || reservation.status == 'Ready') ...[
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      try {
                        await ref
                            .read(pharmacyReservationsControllerProvider.notifier)
                            .completeReservation(reservation.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تأكيد الاستلام بنجاح.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(describeApiError(e))),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('آمن سريرياً · تأكيد واستلام الدواء'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _showClinicalRejectDialog(context, ref, reservation);
                    },
                    icon: const Icon(Icons.report_problem_outlined,
                        size: 18, color: AppColors.dangerText),
                    label: const Text(
                      'تعارض طبي / اعتذار وترشيح بديل للمريض',
                      style: TextStyle(
                          color: AppColors.dangerText,
                          fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.dangerIcon),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Dialog to submit a Clinical Rejection and Suggest an Alternative Medication
void _showClinicalRejectDialog(BuildContext context, WidgetRef ref, dynamic reservation) {
  final reasonCtrl = TextEditingController();
  final altCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.medical_services_outlined, color: AppColors.dangerText, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'تعارض طبي وترشيح بديل',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الدواء المطلوب: ${reservation.medicationName}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'سيتم تحرير الصنف للمخزون فوراً وإرسال إشعار عاجل للمريض بالاعتذار مع البديل الذي ترشحه.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'سبب التعارض الطبي *',
                hintText: 'مثلاً: تعارض مع حساسية الأسبرين أو ضغط الدم',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: altCtrl,
              decoration: const InputDecoration(
                labelText: 'الدواء البديل المقترح *',
                hintText: 'مثلاً: باراسيتامول 500 مجم أو كونكور 2.5',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.dangerText),
          onPressed: () async {
            final reason = reasonCtrl.text.trim();
            final alt = altCtrl.text.trim();
            if (reason.isEmpty || alt.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('يرجى إدخال سبب التعارض والدواء البديل.')),
              );
              return;
            }

            Navigator.pop(dialogCtx);
            try {
              final client = ref.read(apiClientProvider);
              await client.clinicalRejectReservation(
                reservation.id,
                ClinicalRejectRequest(
                  reason: reason,
                  recommendedMedicationName: alt,
                ),
              );
              ref.invalidate(pharmacyReservationsControllerProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'تم تسجيل التعارض الطبي وإخطار المريض بالدواء البديل بنجاح.'),
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
          },
          child: const Text('إرسال الاعتذار والبديل'),
        ),
      ],
    ),
  );
}
