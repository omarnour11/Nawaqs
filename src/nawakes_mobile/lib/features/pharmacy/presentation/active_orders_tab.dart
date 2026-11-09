import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_dashboard_models.dart';
import 'package:url_launcher/url_launcher.dart';


class ActiveOrdersTab extends HookConsumerWidget {
  const ActiveOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pharmacyReservationsControllerProvider);
    final selectedTab = useState(0);

    return state.when(
      loading: () => const _LoadingShimmer(),
      error: (e, _) => _ErrorBanner(
        message: e.toString(),
        onRetry: () => ref.invalidate(pharmacyReservationsControllerProvider),
      ),
      data: (reservations) {
        final nowUtc = DateTime.now().toUtc();
        final activeReservations = reservations
            .where((r) =>
                (r.status == 'Active' || r.status == 'Ready') &&
                r.expiresAt.toUtc().isAfter(nowUtc))
            .toList();

        final completedReservations = reservations
            .where((r) => r.status == 'Completed')
            .toList();

        final failedReservations = reservations
            .where((r) =>
                r.status == 'Cancelled' ||
                r.status == 'Expired' ||
                ((r.status == 'Active' || r.status == 'Ready') &&
                    r.expiresAt.toUtc().isBefore(nowUtc)) ||
                (r.clinicalContraindicationReason != null &&
                    r.clinicalContraindicationReason!.isNotEmpty))
            .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(
                        'الجارية (${activeReservations.length})',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                      selected: selectedTab.value == 0,
                      onSelected: (val) {
                        if (val) selectedTab.value = 0;
                      },
                      selectedColor: NawaqsColors.mint,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(
                        'المستلمة (${completedReservations.length})',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                      selected: selectedTab.value == 1,
                      onSelected: (val) {
                        if (val) selectedTab.value = 1;
                      },
                      selectedColor: const Color(0xFFDCFCE7),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(
                        'الملغية (${failedReservations.length})',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                      selected: selectedTab.value == 2,
                      onSelected: (val) {
                        if (val) selectedTab.value = 2;
                      },
                      selectedColor: const Color(0xFFFEF2F2),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async =>
                    ref.invalidate(pharmacyReservationsControllerProvider),
                child: selectedTab.value == 0
                    ? (activeReservations.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 140),
                              _EmptyOrders(),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: activeReservations.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _OrderCard(
                                reservation: activeReservations[i],
                                ref: ref,
                                initiallyExpanded: activeReservations.length == 1,
                              ),
                            ),
                          ))
                    : selectedTab.value == 1
                        ? (completedReservations.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 140),
                                  Center(
                                    child: Text(
                                      'لا توجد طلبات مستلمة بعد',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: completedReservations.length,
                                itemBuilder: (context, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _OrderCard(
                                    reservation: completedReservations[i],
                                    ref: ref,
                                    initiallyExpanded: false,
                                  ),
                                ),
                              ))
                        : (failedReservations.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 140),
                                  Center(
                                    child: Text(
                                      'لا توجد طلبات متعثرة أو ملغية',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: failedReservations.length,
                                itemBuilder: (context, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _FailedOrderCard(
                                    reservation: failedReservations[i],
                                    ref: ref,
                                  ),
                                ),
                              )),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrderCard extends HookWidget {
  final dynamic reservation;
  final WidgetRef ref;
  final bool initiallyExpanded;
  const _OrderCard({
    required this.reservation,
    required this.ref,
    this.initiallyExpanded = false,
  });

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
      if (isCompleted) return 'تم الاستلام ✓';
      if (isExpired) return 'منتهي الصلاحية ⏰';
      switch (status) {
        case 'Active':
          return 'قيد التجهيز ⏳';
        case 'Ready':
          return 'جاهز للاستلام 📦';
        case 'Completed':
          return 'تم الاستلام ✓';
        case 'Cancelled':
          return 'ملغي ❌';
        case 'Expired':
          return 'منتهي الصلاحية ⏰';
        default:
          return status;
      }
    }

    Color statusColor() {
      if (isCompleted) return const Color(0xFF0D9488);
      if (isExpired) return AppColors.danger;
      switch (reservation.status) {
        case 'Active':
          return const Color(0xFFD97706);
        case 'Ready':
          return const Color(0xFF16A34A);
        case 'Completed':
          return const Color(0xFF0D9488);
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

    final isExpanded = useState(initiallyExpanded);
    final isDelivery = reservation.fulfillmentType == 'Delivery';

    // ── Compact Ribbon View (شريط منظم لكل أوردر يمنع ملء الشاشة) ──
    if (!isExpanded.value) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDelivery
                ? const Color(0xFF3B82F6).withValues(alpha: 0.35)
                : AppColors.hairline,
            width: isDelivery ? 1.3 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => isExpanded.value = true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDelivery
                        ? const Color(0xFFEFF6FF)
                        : AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDelivery
                        ? Icons.delivery_dining_rounded
                        : Icons.storefront_rounded,
                    color: isDelivery
                        ? const Color(0xFF1D4ED8)
                        : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reservation.medicationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isDelivery)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'توصيل 🛵',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              reservation.patientDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isReady
                                ? '· جاهز للتسليم'
                                : isCompleted
                                    ? '· تم التسليم'
                                    : isExpired
                                        ? '· انتهت المهلة'
                                        : '· متبقي ${countdown()}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusArabic(reservation.status),
                    style: TextStyle(
                      color: statusColor(),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showClinicalReviewSheet(context, ref, reservation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Collapse header
            InkWell(
              onTap: () => isExpanded.value = false,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: AppColors.accentBlue),
                    const SizedBox(width: 4),
                    const Text('طي تفاصيل الطلب',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.accentBlue)),
                    const Spacer(),
                    Text('رمز الطلب: #${reservation.reservationCode}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
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
                            'الصنف المطلوب للمريض:',
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
                      label: isReady || isCompleted ? 'حالة الطلب' : 'صلاحية الحجز',
                      value: isReady
                          ? 'جاهز للتسليم 📦'
                          : isCompleted
                              ? 'تم الاستلام بنجاح ✓'
                              : (isExpired
                                  ? 'انتهت المهلة ⏰'
                                  : countdown()),
                      valueColor: isReady || isCompleted
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

              if (reservation.fulfillmentType == 'Delivery') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.delivery_dining_rounded, color: Color(0xFF1D4ED8), size: 18),
                          const SizedBox(width: 6),
                          const Text('طلب توصيل للمنزل (دليفري)',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E40AF))),
                          const Spacer(),
                          if (reservation.deliveryStatus != null)
                            Text(reservation.deliveryStatus!,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                        ],
                      ),
                      if (reservation.deliveryAddress != null && reservation.deliveryAddress!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('📍 العنوان: ${reservation.deliveryAddress}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A))),
                      ],
                      if (reservation.deliveryContactPhone != null && reservation.deliveryContactPhone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('📞 هاتف العميل: ${reservation.deliveryContactPhone}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A))),
                      ],
                      if (reservation.deliveryNotes != null && reservation.deliveryNotes!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('📝 ملاحظات: ${reservation.deliveryNotes}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                      ],
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => _dispatchRunnerViaWhatsApp(context, reservation),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('📲 إرسال للطيار عبر واتساب'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          minimumSize: const Size.fromHeight(38),
                          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                        onPressed: () => _showHandoverVerificationDialog(context, ref, reservation),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                        label: const Text('تم الاستلام'),
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
              ] else if (isCompleted) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'تم تسليم الطلب والتأكد من كود الاستلام بنجاح ✓',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (reservation.status == 'Expired' || isExpired) ...[
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
    return ListView(
      padding: const EdgeInsets.all(16),
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
Future<void> _dispatchRunnerViaWhatsApp(BuildContext context, dynamic reservation) async {
  final buf = StringBuffer();
  buf.writeln('🛵 *طلب توصيل دواء جديد - نواقص*');
  buf.writeln('--------------------------------');
  buf.writeln('💊 *الدواء:* ${reservation.medicationName}');
  buf.writeln('🔢 *كود الطلب:* ${reservation.reservationCode}');
  buf.writeln('👤 *العميل:* ${reservation.patientDisplayName}');
  if (reservation.deliveryContactPhone != null && reservation.deliveryContactPhone!.isNotEmpty) {
    buf.writeln('📞 *هاتف العميل:* ${reservation.deliveryContactPhone}');
  }
  if (reservation.deliveryAddress != null && reservation.deliveryAddress!.isNotEmpty) {
    buf.writeln('📍 *العنوان التفصيلي:* ${reservation.deliveryAddress}');
  }
  if (reservation.deliveryNotes != null && reservation.deliveryNotes!.isNotEmpty) {
    buf.writeln('📝 *ملاحظات التوصيل:* ${reservation.deliveryNotes}');
  }
  buf.writeln('💵 *طريقة الدفع:* كاش عند الاستلام للطيار');
  if (reservation.deliveryLatitude != null && reservation.deliveryLongitude != null) {
    buf.writeln('🗺️ *رابط لوكيشن العميل الدقيق (GPS):*');
    buf.writeln('https://maps.google.com/?q=${reservation.deliveryLatitude},${reservation.deliveryLongitude}');
  }
  buf.writeln('--------------------------------');
  buf.writeln('يرجى تسليم الدواء واستلام الكود والمبلغ نقدًا من العميل.');

  final encoded = Uri.encodeComponent(buf.toString());
  final uri = Uri.parse('https://wa.me/?text=$encoded');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق واتساب.')),
      );
    }
  }
}

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
                            .markReady(reservation.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم اعتماد الأمان السريري للدواء بنجاح.')),
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
                    icon: const Icon(Icons.verified_user_outlined, size: 18),
                    label: const Text('آمن سريرياً · اعتماد الفحص الطبي'),
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


/// Dialog enforcing strict QR or OTP proof before an order can be marked delivered
void _showHandoverVerificationDialog(BuildContext context, WidgetRef ref, dynamic reservation) {
  final codeCtrl = TextEditingController();
  final isDelivery = reservation.fulfillmentType == 'Delivery';
  final expectedFullCode = (reservation.reservationCode as String).replaceAll('-', '').toUpperCase();
  final expectedOtp = expectedFullCode.length >= 4 ? expectedFullCode.substring(expectedFullCode.length - 4) : expectedFullCode;
  String? errorText;

  showDialog(
    context: context,
    builder: (dCtx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isDelivery ? Icons.two_wheeler_rounded : Icons.verified_rounded,
                color: NawaqsColors.tealDark, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isDelivery ? 'إثبات تسليم مندوب التوصيل' : 'إثبات استلام العميل بالصيدلية',
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 15.5),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDelivery
                  ? 'لحماية حقوق المريض والطيار، يجب إدخال كود التحقق السري (OTP) المسلم من المريض لمندوب التوصيل عند باب المنزل.'
                  : 'لحماية حقوق الصيدلية والعميل، يجب فحص QR كود المريض أو إدخال كود الحجز/OTP الموضح على هاتف العميل.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: isDelivery ? 'كود التحقق السري (OTP أو كود الحجز) *' : 'كود الحجز / الـ QR من شاشة العميل *',
                hintText: isDelivery ? 'مثال: $expectedOtp' : 'مثال: ${reservation.reservationCode}',
                prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                errorText: errorText,
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              final entered = codeCtrl.text.trim().replaceAll('-', '').toUpperCase();
              if (entered.isEmpty) {
                setState(() {
                  errorText = 'يرجى إدخال كود التحقق لإثبات التسليم';
                });
                return;
              }

              final matchesFull = entered == expectedFullCode;
              final matchesOtp = entered == expectedOtp;

              if (!matchesFull && !matchesOtp) {
                setState(() {
                  errorText = 'كود التحقق غير صحيح! لا يمكن إغلاق الطلب دون إثبات التسليم من العميل.';
                });
                return;
              }

              Navigator.pop(dCtx);
              try {
                await ref
                    .read(pharmacyReservationsControllerProvider.notifier)
                    .completeReservation(reservation.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم التحقق بنجاح وتأكيد تسليم الطلب للمريض.'),
                      backgroundColor: AppColors.success,
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
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('تحقق وتسليم الطلب'),
          ),
        ],
      ),
    ),
  );
}

/// Card representing a Cancelled or Expired Reservation with Patient Follow-up Action
class _FailedOrderCard extends StatelessWidget {
  final dynamic reservation;
  final WidgetRef ref;

  const _FailedOrderCard({required this.reservation, required this.ref});

  @override
  Widget build(BuildContext context) {
    final phone = (reservation.deliveryContactPhone as String?)?.isNotEmpty == true
        ? reservation.deliveryContactPhone as String
        : '01000000000';
    final reason = (reservation.clinicalContraindicationReason as String?)?.isNotEmpty == true
        ? reservation.clinicalContraindicationReason as String
        : reservation.status == 'Expired'
            ? 'انتهت صلاحية الحجز ولم يتم الحضور للاستلام'
            : 'تم الإلغاء من قبل المريض';

    final isClinical = (reservation.clinicalContraindicationReason as String?)?.isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isClinical ? const Color(0xFFFEF2F2) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isClinical ? const Color(0xFFFCA5A5) : Colors.grey.shade300),
                ),
                child: Text(
                  isClinical
                      ? 'تعارض طبي سريري'
                      : reservation.status == 'Expired'
                          ? 'منتهي الصلاحية'
                          : 'طلب ملغي',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isClinical ? const Color(0xFFDC2626) : AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                reservation.reservationCode ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            reservation.medicationName ?? 'دواء',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 15, color: NawaqsColors.ink),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'سبب التعثر: $reason',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('tel:$phone');
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: NawaqsColors.tealDark),
                  label: Text('اتصال بالعميل للمتابعة ($phone)', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: NawaqsColors.tealDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}