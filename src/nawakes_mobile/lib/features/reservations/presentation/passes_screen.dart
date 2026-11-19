import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/reservations/data/offline_reservation_pass_store.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/core/utils/arabic_digits.dart';

part 'passes_screen.g.dart';

final offlinePassStore = OfflineReservationPassStore();

/// التصاريح tab — list of reservations; opening one shows the full pass.
/// Falls back to cached passes when the network fails so the pickup code
/// stays reachable in basements with no reception.
@riverpod
class PassesController extends _$PassesController {
  @override
  FutureOr<List<ReservationResponse>> build() async {
    try {
      final reservations = await ref.read(apiClientProvider).getMyReservations();
      await offlinePassStore.saveActive(reservations);
      return reservations;
    } catch (_) {
      return offlinePassStore.loadActive();
    }
  }

  Future<void> cancel(String id) async {
    await ref.read(apiClientProvider).cancelReservation(id);
    ref.invalidateSelf();
  }
}

/// Unified pharmacy order group: collates all medications booked in the same batch/pharmacy
/// so that the patient sees ONE single pass with ONE unified pickup code NWQ-XXXXXX and QR.
class PassOrderGroup {
  final String orderCode;
  final String pharmacyId;
  final String pharmacyName;
  final String pharmacyPhone;
  final List<ReservationResponse> items;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String fulfillmentType;
  final String? deliveryAddress;
  final String? deliveryContactPhone;
  final String? clinicalContraindicationReason;
  final double? pharmacyLatitude;
  final double? pharmacyLongitude;

  PassOrderGroup({
    required this.orderCode,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.pharmacyPhone,
    required this.items,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.fulfillmentType,
    this.deliveryAddress,
    this.deliveryContactPhone,
    this.clinicalContraindicationReason,
    this.pharmacyLatitude,
    this.pharmacyLongitude,
  });

  bool get isSingleMedication => items.length <= 1;
  String get medicationSummary => items.map((i) => i.medicationName).join(' · ');
}

List<PassOrderGroup> groupReservations(List<ReservationResponse> reservations) {
  final Map<String, List<ReservationResponse>> map = {};
  for (final r in reservations) {
    final key = '${r.pharmacyId}_${r.reservationCode}';
    map.putIfAbsent(key, () => []).add(r);
  }

  return map.values.map((group) {
    final first = group.first;
    final earliestExpiry = group.map((g) => g.expiresAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final anyContraindication = group.firstWhere(
      (g) => g.clinicalContraindicationReason != null,
      orElse: () => first,
    ).clinicalContraindicationReason;

    final status = group.any((g) => g.status == 'Ready')
        ? 'Ready'
        : group.any((g) => g.status == 'Active')
            ? 'Active'
            : first.status;

    return PassOrderGroup(
      orderCode: first.reservationCode,
      pharmacyId: first.pharmacyId,
      pharmacyName: first.pharmacyName,
      pharmacyPhone: first.pharmacyPhone,
      items: group,
      status: status,
      expiresAt: earliestExpiry,
      createdAt: first.createdAt,
      fulfillmentType: first.fulfillmentType,
      deliveryAddress: first.deliveryAddress,
      deliveryContactPhone: first.deliveryContactPhone,
      clinicalContraindicationReason: anyContraindication,
      pharmacyLatitude: first.pharmacyLatitude,
      pharmacyLongitude: first.pharmacyLongitude,
    );
  }).toList();
}

class PassesScreen extends HookConsumerWidget {
  const PassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(passesControllerProvider);
    final filter = useState<String>('الكل');

    return Scaffold(

      body: SafeArea(
        bottom: false,
        child: state.when(
          data: (reservations) {
            final grouped = groupReservations(reservations);
            final active = grouped
                .where((r) => r.status == 'Active' || r.status == 'Ready')
                .toList();
            final past =
                grouped.where((r) => r.status != 'Active' && r.status != 'Ready').toList();
            final shown = switch (filter.value) {
              'نشطة' => active,
              'السجل' => past,
              _ => grouped,
            };

            return RefreshIndicator(
              color: AppColors.accentBlue,
              onRefresh: () async => ref.invalidate(passesControllerProvider),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  const NawaqsTopBar(eyebrow: 'نواقص', title: 'التصاريح'),
                  ScreenSubtitle('اعرض التصريح عند الكاشير وقت الاستلام'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Pill('الكل', filter, count: grouped.length),
                            const SizedBox(width: 8),
                            _Pill('نشطة', filter, count: active.length),
                            const SizedBox(width: 8),
                            _Pill('السجل', filter, count: past.length),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (shown.isEmpty)
                          const _EmptyPasses()
                        else
                          ...shown.map((order) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PassRow(order: order),
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر تحميل التصاريح',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(passesControllerProvider),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final ValueNotifier<String> filter;
  final int count;
  const _Pill(this.label, this.filter, {required this.count});

  @override
  Widget build(BuildContext context) {
    final active = filter.value == label;
    return GestureDetector(
      onTap: () => filter.value = label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.accentBlueBg : const Color(0xFFF1F2F4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('$label ($count)',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.accentBlue : AppColors.textSecondary)),
      ),
    );
  }
}

class _EmptyPasses extends StatelessWidget {
  const _EmptyPasses();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 44, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('مفيش تصاريح حالية',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'لما تحجز دواء، التصريح هيظهر هنا بكود الاستلام و QR.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.55),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => context.go('/home'),
            style: FilledButton.styleFrom(
                minimumSize: const Size(150, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13))),
            child: const Text('ابحث عن دواء'),
          ),
        ],
      ),
    );
  }
}

// ─── Compact pass row ─────────────────────────────────────────────────────────
class _PassRow extends HookConsumerWidget {
  final PassOrderGroup? order;
  final ReservationResponse? reservation;
  const _PassRow({this.order, this.reservation}) : assert(order != null || reservation != null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveOrder = order ??
        PassOrderGroup(
          orderCode: reservation!.reservationCode,
          pharmacyId: reservation!.pharmacyId,
          pharmacyName: reservation!.pharmacyName,
          pharmacyPhone: reservation!.pharmacyPhone,
          items: [reservation!],
          status: reservation!.status,
          expiresAt: reservation!.expiresAt,
          createdAt: reservation!.createdAt,
          fulfillmentType: reservation!.fulfillmentType,
          deliveryAddress: reservation!.deliveryAddress,
          deliveryContactPhone: reservation!.deliveryContactPhone,
          clinicalContraindicationReason: reservation!.clinicalContraindicationReason,
          pharmacyLatitude: reservation!.pharmacyLatitude,
          pharmacyLongitude: reservation!.pharmacyLongitude,
        );

    final isExpired = effectiveOrder.expiresAt.toUtc().isBefore(DateTime.now().toUtc()) &&
        effectiveOrder.status != 'Completed';
    final (chip, tone) = _statusChip(effectiveOrder.status, isExpired);
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/pass-detail', extra: effectiveOrder),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              IconTile(
                effectiveOrder.status == 'Active' || effectiveOrder.status == 'Ready'
                    ? Icons.qr_code_2_rounded
                    : Icons.receipt_long_rounded,
                bg: (effectiveOrder.status == 'Active' || effectiveOrder.status == 'Ready')
                    ? AppColors.accentBlueBg
                    : const Color(0xFFF1F2F4),
                color: (effectiveOrder.status == 'Active' || effectiveOrder.status == 'Ready')
                    ? AppColors.accentBlue
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      effectiveOrder.items.length > 1
                          ? '${effectiveOrder.pharmacyName} (${ArabicDigits.convert(effectiveOrder.items.length)} أدوية)'
                          : effectiveOrder.items.first.medicationName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      effectiveOrder.items.length > 1
                          ? effectiveOrder.medicationSummary
                          : '${effectiveOrder.pharmacyName} · ${DateFormat('d MMM').format(effectiveOrder.createdAt.toLocal())}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (effectiveOrder.clinicalContraindicationReason != null) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '⚠️ تعارض طبي: الصيدلي رشح بديلاً',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dangerText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  chip,
                  const SizedBox(height: 4),
                  Text(effectiveOrder.orderCode,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (StatusChip, ChipTone) _statusChip(String status, bool isExpired) => switch (status) {
        'Completed' => (const StatusChip('تم الاستلام', tone: ChipTone.success), ChipTone.success),
        'Ready' => (const StatusChip('جاهز للاستلام', tone: ChipTone.success), ChipTone.success),
        'Expired' => (const StatusChip('انتهى', tone: ChipTone.danger), ChipTone.danger),
        'Cancelled' => (const StatusChip('ملغي', tone: ChipTone.danger), ChipTone.danger),
        'Active' when isExpired => (const StatusChip('انتهى', tone: ChipTone.danger), ChipTone.danger),
        'Active' => (const StatusChip('محجوز', tone: ChipTone.neutral), ChipTone.neutral),
        _ => (StatusChip(status, tone: ChipTone.warning), ChipTone.warning),
      };
}

// ─── Full pass detail (mockup's teal hero + QR + stepper) ─────────────────────
class PassDetailScreen extends HookConsumerWidget {
  final ReservationResponse? reservation;
  final PassOrderGroup? orderGroup;
  const PassDetailScreen({super.key, this.reservation, this.orderGroup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = orderGroup ??
        PassOrderGroup(
          orderCode: reservation!.reservationCode,
          pharmacyId: reservation!.pharmacyId,
          pharmacyName: reservation!.pharmacyName,
          pharmacyPhone: reservation!.pharmacyPhone,
          items: [reservation!],
          status: reservation!.status,
          expiresAt: reservation!.expiresAt,
          createdAt: reservation!.createdAt,
          fulfillmentType: reservation!.fulfillmentType,
          deliveryAddress: reservation!.deliveryAddress,
          deliveryContactPhone: reservation!.deliveryContactPhone,
          clinicalContraindicationReason: reservation!.clinicalContraindicationReason,
          pharmacyLatitude: reservation!.pharmacyLatitude,
          pharmacyLongitude: reservation!.pharmacyLongitude,
        );
    final res = order.items.first;

    final now = useState(DateTime.now().toUtc());
    final copied = useState(false);

    useEffect(() {
      final t = Timer.periodic(const Duration(seconds: 1), (_) => now.value = DateTime.now().toUtc());
      return t.cancel;
    }, const []);

    final remaining = order.expiresAt.toUtc().difference(now.value);
    final expired = remaining.isNegative;
    final isReady = order.status == 'Ready';
    final isDone = order.status == 'Completed';
    return Scaffold(

      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            NawaqsTopBar(
              eyebrow: 'نواقص',
              title: order.items.length > 1 ? 'تصريح طلب موحد' : 'تصريح الحجز',
              back: true,
              showBell: false,
            ),
            // ── Brand Kit Page 16: Nuqous Header & Status Indicator ──
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  NuqousMascot(
                    height: 76,
                    mood: isDone
                        ? NuqousMood.celebrating
                        : (expired || order.status == 'Expired' || order.status == 'Cancelled')
                            ? NuqousMood.worried
                            : NuqousMood.celebrating,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isDone
                        ? 'تم الاستلام بنجاح ✓'
                        : (expired || order.status == 'Expired')
                            ? 'انتهت صلاحية الحجز ⏰'
                            : order.status == 'Cancelled'
                                ? 'الحجز ملغي ❌'
                                : isReady
                                    ? 'جاهز للاستلام 📦'
                                    : 'اتحجز بنجاح!',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDone
                          ? const Color(0xFF15803D)
                          : (expired || order.status == 'Expired' || order.status == 'Cancelled')
                              ? AppColors.dangerText
                              : NawaqsColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDone
                        ? 'تم تسليم الأدوية بنجاح من ${order.pharmacyName}'
                        : (expired || order.status == 'Expired')
                            ? 'انتهت المهلة المحددة (ساعتان) ورجعت الأصناف للمخزون'
                            : order.status == 'Cancelled'
                                ? 'تم إلغاء هذا الحجز ورجعت الأصناف للمخزون'
                                : isReady
                                    ? 'الأدوية مجهزة وفي انتظارك في ${order.pharmacyName}'
                                    : 'الأدوية محجوزة في ${order.pharmacyName}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFFDCFCE7)
                          : (expired || order.status == 'Expired' || order.status == 'Cancelled')
                              ? const Color(0xFFFEE2E2)
                              : NawaqsColors.coralSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDone
                            ? const Color(0xFF86EFAC)
                            : (expired || order.status == 'Expired' || order.status == 'Cancelled')
                                ? const Color(0xFFFCA5A5)
                                : NawaqsColors.coral.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isDone
                              ? 'تم التسليم'
                              : (expired || order.status == 'Expired')
                                  ? '00:00:00'
                                  : order.status == 'Cancelled'
                                      ? 'ملغي'
                                      : '${remaining.inHours.toString().padLeft(2, '0')}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: isDone || order.status == 'Cancelled' ? 22 : 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: isDone || order.status == 'Cancelled' ? 0 : 2,
                            color: isDone
                                ? const Color(0xFF15803D)
                                : (expired || order.status == 'Expired' || order.status == 'Cancelled')
                                    ? AppColors.dangerText
                                    : NawaqsColors.coral,
                          ),
                        ),
                        Text(
                          isDone
                              ? 'تم التحقق من كود الاستلام بنجاح'
                              : (expired || order.status == 'Expired')
                                  ? 'انتهت مدة الحجز (الصنف متاح للآخرين)'
                                  : order.status == 'Cancelled'
                                      ? 'تم إلغاء الحجز'
                                      : 'الوقت المتبقي للاستلام (ساعتين)',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDone
                                ? const Color(0xFF15803D)
                                : (expired || order.status == 'Expired' || order.status == 'Cancelled')
                                    ? AppColors.dangerText
                                    : NawaqsColors.coral,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (order.clinicalContraindicationReason != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: AppColors.dangerIcon.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.warning_amber_rounded,
                                  size: 22, color: AppColors.dangerText),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تنبيه تعارض طبي من الصيدلي',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.dangerText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'سبب الاعتذار: ${order.clinicalContraindicationReason}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dangerText,
                              height: 1.4,
                            ),
                          ),
                          if (res.recommendedAlternativeMedication != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.hairline),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'الدواء البديل المقترح من الصيدلي:',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    res.recommendedAlternativeMedication!,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: context.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: () {
                                      final alt = res.recommendedAlternativeMedication!;
                                      context.push('/search?query=${Uri.encodeComponent(alt)}');
                                    },
                                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                                    label: const Text('حجز الدواء البديل فوراً بنقرة واحدة'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.brand900,
                                      minimumSize: const Size(double.infinity, 42),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Teal pass hero ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.brand900,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6, height: 6,
                                      decoration: const BoxDecoration(
                                          color: Color(0xFF5DDBA0),
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isDone
                                          ? 'تم الاستلام'
                                          : expired
                                              ? 'منتهي'
                                              : isReady
                                                  ? 'جاهز للاستلام'
                                                  : 'مؤكد',
                                      style: TextStyle(
                                          color: Color(0xFFDFF3EA),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(order.items.length > 1 ? 'كود الطلب الموحد' : 'كود الحجز',
                                  style: const TextStyle(
                                      color: Color(0xFFBFE0D6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(order.orderCode,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5)),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () async {
                                  await Clipboard.setData(ClipboardData(
                                      text: order.orderCode));
                                  copied.value = true;
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(copied.value
                                          ? Icons.check_rounded
                                          : Icons.copy_rounded,
                                          size: 14, color: Colors.white),
                                      const SizedBox(width: 6),
                                      Text(copied.value ? 'تم النسخ' : 'نسخ الكود',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'كود OTP الأمني: ${order.orderCode.replaceAll('-', '').length >= 4 ? order.orderCode.replaceAll('-', '').substring(order.orderCode.replaceAll('-', '').length - 4) : order.orderCode}',
                                  style: const TextStyle(
                                    color: Color(0xFFDFF3EA),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // QR
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: QrImageView(
                            data: order.orderCode,
                            version: QrVersions.auto,
                            size: 76,
                            eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: AppColors.brand900),
                            dataModuleStyle: const QrDataModuleStyle(
                                color: AppColors.brand900,
                                dataModuleShape: QrDataModuleShape.square),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Pickup from card ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('الاستلام من'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const IconTile(Icons.storefront_outlined,
                                bg: AppColors.accentBlueBg,
                                color: AppColors.accentBlue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(order.pharmacyName,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text(
                                    order.items.length > 1
                                        ? '${ArabicDigits.convert(order.items.length)} أدوية في هذا الحجز الموحد'
                                        : order.items.first.medicationName,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (order.items.length > 1) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.hairline),
                          const SizedBox(height: 8),
                          ...order.items.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded,
                                        size: 16, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.medicationName,
                                        style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InfoCell(
                                label: 'انتهاء التصريح',
                                value: expired
                                    ? 'انتهى'
                                    : '${remaining.inHours} س ${remaining.inMinutes % 60} د',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InfoCell(
                                label: 'تاريخ الإنشاء',
                                value: DateFormat('d MMM · hh:mm a')
                                    .format(order.createdAt.toLocal()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Status tracker ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('حالة الاستلام'),
                        const SizedBox(height: 10),
                        StepperWidget(
                          steps: isDone
                              ? [
                                  StepperStep.done('محجوز', 'حجزك اتفعّل في الصيدلية'),
                                  StepperStep.done('جاهز للاستلام', 'الصيدلية جهزت الطلب'),
                                  StepperStep.done('تم الاستلام والتسليم', 'تم استلام الدواء بنجاح'),
                                ]
                              : (expired || order.status == 'Expired')
                                  ? [
                                      StepperStep.done('محجوز مسبقاً', 'تم إنشاء الحجز'),
                                      StepperStep.pending('انتهت مهلة الاستلام ⏰',
                                          'انتهت مهلة الساعتين ورجع الصنف لمخزون الصيدلية',
                                          pendingIcon: Icons.timer_off_outlined),
                                    ]
                                  : order.status == 'Cancelled'
                                      ? [
                                          StepperStep.pending('حجز ملغي ❌',
                                              'تم إلغاء الحجز من الصيدلية أو العميل',
                                              pendingIcon: Icons.cancel_outlined),
                                        ]
                                      : isReady
                                          ? [
                                              StepperStep.done('محجوز', 'محجوز لك في الصيدلية'),
                                              StepperStep.done('جاهز للاستلام 📦', 'الصيدلية جهزت الطلب وهو في انتظارك'),
                                            ]
                                          : [
                                              StepperStep.done('محجوز', 'محجوز لك في الصيدلية'),
                                              StepperStep.pending('جاهز للاستلام',
                                                  'الصيدلية هتأكدلك أول ما الطلب يجهز',
                                                  pendingIcon: Icons.schedule_rounded),
                                            ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Delivery Information (Home delivery address & recipient contact) ──
                  if (order.fulfillmentType == 'Delivery' || (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFF15803D), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'طلب توصيل للمنزل',
                                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                                if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
                                  Text(
                                    order.deliveryAddress!,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF166534)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (order.deliveryContactPhone != null && order.deliveryContactPhone!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'هاتف المستلم للتواصل: ${order.deliveryContactPhone}',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Brand Kit Page 16: Primary Action Buttons (اتجاه / اتصل) ──
                  if (!isDone && !expired) ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              final lat = order.pharmacyLatitude ?? 30.0444;
                              final lng = order.pharmacyLongitude ?? 31.2357;
                              final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: NawaqsColors.coral,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            icon: const Icon(Icons.navigation_rounded, size: 18),
                            label: const Text(
                              'اتجاه',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: order.pharmacyPhone.isEmpty
                                ? null
                                : () async {
                                    final url = Uri(
                                        scheme: 'tel',
                                        path: order.pharmacyPhone);
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url);
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: NawaqsColors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                            label: const Text(
                              'اتصال بالصيدلية',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/support'),
                      icon: const Icon(Icons.help_outline_rounded, size: 17),
                      label: const Text('محتاج مساعدة مع الحجز؟'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (!isDone &&
                      !expired &&
                      order.status == 'Active')
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            try {
                              for (final item in order.items) {
                                await ref.read(passesControllerProvider.notifier).cancel(item.id);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم إلغاء الحجز بنجاح.')),
                                );
                                context.pop();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(describeApiError(e))),
                                );
                              }
                            }
                          },
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.dangerText),
                          child: Text(
                            order.items.length > 1 ? 'إلغاء حجز جميع الأدوية' : 'إلغاء الحجز',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
