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

class PassesScreen extends HookConsumerWidget {
  const PassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(passesControllerProvider);
    final filter = useState<String>('الكل');

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: state.when(
          data: (reservations) {
            final active = reservations
                .where((r) => r.status == 'Active' || r.status == 'Ready')
                .toList();
            final past =
                reservations.where((r) => r.status != 'Active' && r.status != 'Ready').toList();
            final shown = switch (filter.value) {
              'نشطة' => active,
              'السجل' => past,
              _ => reservations,
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
                            _Pill('الكل', filter, count: reservations.length),
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
                          ...shown.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PassRow(reservation: r),
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
        color: AppColors.card,
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
  final ReservationResponse reservation;
  const _PassRow({required this.reservation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (chip, tone) = _statusChip(reservation.status);
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/pass-detail', extra: reservation),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              IconTile(
                reservation.status == 'Active' || reservation.status == 'Ready'
                    ? Icons.qr_code_2_rounded
                    : Icons.receipt_long_rounded,
                bg: (reservation.status == 'Active' || reservation.status == 'Ready')
                    ? AppColors.accentBlueBg
                    : const Color(0xFFF1F2F4),
                color: (reservation.status == 'Active' || reservation.status == 'Ready')
                    ? AppColors.accentBlue
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reservation.medicationName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                        '${reservation.pharmacyName} · ${DateFormat('d MMM').format(reservation.createdAt.toLocal())}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  chip,
                  const SizedBox(height: 4),
                  Text(reservation.reservationCode,
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

  (StatusChip, ChipTone) _statusChip(String status) => switch (status) {
        'Active' => (const StatusChip('محجوز', tone: ChipTone.neutral), ChipTone.neutral),
        'Ready' => (const StatusChip('جاهز للاستلام', tone: ChipTone.success), ChipTone.success),
        'Completed' => (const StatusChip('تم الاستلام', tone: ChipTone.success), ChipTone.success),
        'Expired' => (const StatusChip('انتهى', tone: ChipTone.danger), ChipTone.danger),
        'Cancelled' => (const StatusChip('ملغي', tone: ChipTone.danger), ChipTone.danger),
        _ => (StatusChip(status, tone: ChipTone.warning), ChipTone.warning),
      };
}

// ─── Full pass detail (mockup's teal hero + QR + stepper) ─────────────────────
class PassDetailScreen extends HookConsumerWidget {
  final ReservationResponse reservation;
  const PassDetailScreen({super.key, required this.reservation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useState(DateTime.now().toUtc());
    final copied = useState(false);

    useEffect(() {
      final t = Timer.periodic(const Duration(seconds: 1), (_) => now.value = DateTime.now().toUtc());
      return t.cancel;
    }, const []);

    final remaining = reservation.expiresAt.toUtc().difference(now.value);
    final expired = remaining.isNegative;
    final minutesLeft = remaining.inMinutes;
    final isReady = reservation.status == 'Ready';
    final isDone = reservation.status == 'Completed';
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            NawaqsTopBar(
              eyebrow: 'نواقص',
              title: 'تصريح الحجز',
              back: true,
              showBell: false,
            ),
            ScreenSubtitle(expired
                ? 'التصريح انتهى'
                : 'اعرضه وقت الاستلام · محجوز لمدة $minutesLeft دقيقة'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                      style: const TextStyle(
                                          color: Color(0xFFDFF3EA),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text('كود الحجز',
                                  style: TextStyle(
                                      color: Color(0xFFBFE0D6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(reservation.reservationCode,
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
                                      text: reservation.reservationCode));
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
                            data: reservation.reservationCode,
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
                      color: AppColors.card,
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
                                  Text(reservation.pharmacyName,
                                      style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(reservation.medicationName,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                                    .format(reservation.createdAt.toLocal()),
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
                      color: AppColors.card,
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
                                  StepperStep.done('تم الاستلام', 'اتأكد الكود عند الكاشير'),
                                ]
                              : isReady
                                  ? [
                                      StepperStep.done('محجوز', 'محجوز لك في الصيدلية'),
                                      StepperStep.done('جاهز للاستلام', 'اعرض التصريح والروشتة'),
                                    ]
                                  : [
                                      StepperStep.done('محجوز', 'محجوز لك في الصيدلية'),
                                      StepperStep.pending('جاهز للاستلام',
                                          'الصيدلية هتأكدلك لما يبقى جاهز',
                                          pendingIcon: Icons.schedule_rounded),
                                    ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Actions ───────────────────────────────────────────────
                  if (!isDone && !expired) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: reservation.pharmacyPhone.isEmpty
                                ? null
                                : () async {
                                    final url = Uri(
                                        scheme: 'tel',
                                        path: reservation.pharmacyPhone);
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url);
                                    }
                                  },
                            icon: const Icon(Icons.call_outlined, size: 17),
                            label: const Text('اتصال بالصيدلية'),
                            style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push('/support'),
                            icon: const Icon(Icons.help_outline_rounded, size: 17),
                            label: const Text('محتاج مساعدة؟'),
                            style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (!isDone &&
                      !expired &&
                      reservation.status == 'Active')
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            try {
                              await ref.read(passesControllerProvider.notifier).cancel(reservation.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم إلغاء الحجز.')),
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
                          child: const Text('إلغاء الحجز',
                              style: TextStyle(fontWeight: FontWeight.w700)),
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
