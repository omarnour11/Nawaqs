import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';

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
        if (reservations.isEmpty) {
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
            itemCount: reservations.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OrderCard(reservation: reservations[i], ref: ref),
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

    final expiresAt = reservation.expiresAt.toUtc();
    final remaining = expiresAt.difference(now.value);
    final isExpired = remaining.isNegative;
    final isActive = reservation.status == 'Active';

    String countdown() {
      if (isExpired) return 'Expired';
      final h = remaining.inHours.toString().padLeft(2, '0');
      final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
      final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }

    Color statusColor() {
      switch (reservation.status) {
        case 'Active':
          return AppColors.accent;
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(reservation.patientDisplayName,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                    reservation.status,
                    style: TextStyle(
                      color: statusColor(),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Info row
            Row(
              children: [
                // Pickup code
                Expanded(
                  child: _InfoItem(
                    icon: Icons.qr_code_rounded,
                    label: 'Pickup code',
                    value: reservation.reservationCode,
                  ),
                ),
                // Countdown
                Expanded(
                  child: _InfoItem(
                    icon: Icons.timer_outlined,
                    label: 'Expires in',
                    value: countdown(),
                    valueColor: isExpired
                        ? AppColors.danger
                        : remaining.inMinutes < 10
                            ? AppColors.warning
                            : AppColors.success,
                  ),
                ),
              ],
            ),

            if (isActive) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  // جاهز للاستلام
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
                      icon: const Icon(Icons.task_outlined, size: 17),
                      label: const Text('جاهز'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        side: const BorderSide(color: AppColors.hairline),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                                    const SnackBar(
                                        content: Text('الاستلام اتم بنجاح.')),
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
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 17),
                      label: Text(isCompleting.value ? 'جارٍ…' : 'تم الاستلام'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
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
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: const Text('إلغاء'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.dangerText,
                        side: const BorderSide(
                            color: AppColors.dangerIcon, width: 1.2),
                        minimumSize: const Size(0, 42),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ]
                        else if (reservation.status == 'Expired') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Auto-expired — the item returned to In Stock automatically.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textHint),
                ),
              ),
            ],
          ],
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
            Text('No Active Orders', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'New patient reservations will appear here in real-time.',
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
            Text('Failed to load orders', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
