import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart'
    show describeApiError;
import 'package:nawakes_mobile/features/reservations/presentation/my_reservations_controller.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:intl/intl.dart';

class MyReservationsScreen extends HookConsumerWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsState = ref.watch(myReservationsControllerProvider);
    final filter = useState<String>('All');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: reservationsState.when(
            data: (reservations) {
              final List<ReservationResponse> shown = switch (filter.value) {
                'Active' => reservations.where((r) => r.status == 'Active').toList(),
                'History' => reservations.where((r) => r.status != 'Active').toList(),
                _ => reservations,
              };

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => ref.invalidate(myReservationsControllerProvider),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text('My Reservations',
                                  style: TextStyle(
                                      fontSize: 21, fontWeight: FontWeight.w800)),
                            ),
                            IconButton.filledTonal(
                              onPressed: () =>
                                  ref.invalidate(myReservationsControllerProvider),
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Row(
                          children: [
                            _FilterPill('All', filter),
                            const SizedBox(width: 8),
                            _FilterPill('Active', filter),
                            const SizedBox(width: 8),
                            _FilterPill('History', filter),
                          ],
                        ),
                      ),
                    ),
                    if (shown.isEmpty)
                      const SliverFillRemaining(child: _EmptyReservations())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                        sliver: SliverList.separated(
                          itemCount: shown.length,
                          separatorBuilder: (c, i2) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final r = shown[i];
                            return r.status == 'Active'
                                ? _ActiveReservationCard(reservation: r)
                                : _PastReservationCard(reservation: r);
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
            loading: () => const _LoadingShimmer(),
            error: (error, _) => _ErrorBanner(
              message: error.toString(),
              onRetry: () => ref.invalidate(myReservationsControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Active reservation: big pickup-code card with live countdown ─────────────
class _ActiveReservationCard extends HookConsumerWidget {
  final ReservationResponse reservation;
  const _ActiveReservationCard({required this.reservation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useState(DateTime.now().toUtc());
    final isCancelling = useState(false);

    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        now.value = DateTime.now().toUtc();
      });
      return timer.cancel;
    }, const []);

    final expiresAt = reservation.expiresAt.toUtc();
    final createdAt = reservation.createdAt.toUtc();
    final remaining = expiresAt.difference(now.value);
    final timeSinceCreation = now.value.difference(createdAt);
    final canCancel = timeSinceCreation.inMinutes >= 15 && !remaining.isNegative;

    final countdown = remaining.isNegative
        ? 'Expired'
        : '${remaining.inHours.toString().padLeft(2, '0')}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

    Future<void> cancel() async {
      isCancelling.value = true;
      try {
        await ref.read(myReservationsControllerProvider.notifier).cancel(reservation.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reservation cancelled.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e)), backgroundColor: AppColors.danger),
          );
        }
      } finally {
        isCancelling.value = false;
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.medication_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reservation.medicationName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15.5)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.local_pharmacy_rounded,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(reservation.pharmacyName,
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('ACTIVE',
                      style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5)),
                ),
              ],
            ),
          ),

          // Pickup code "QR" panel — dashed-style visual
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border, width: 1.2),
            ),
            child: Column(
              children: [
                const Text('SHOW THIS CODE AT THE PHARMACY',
                    style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textHint)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.4),
                  ),
                  child: Text(
                    reservation.reservationCode,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        color: AppColors.primaryDark,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TIME REMAINING',
                        style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 2),
                    Text(countdown,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: remaining.isNegative
                                ? AppColors.danger
                                : remaining.inMinutes < 15
                                    ? AppColors.warning
                                    : AppColors.primary,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                  ],
                ),
                const Spacer(),
                if (canCancel)
                  OutlinedButton.icon(
                    onPressed: isCancelling.value ? null : cancel,
                    icon: isCancelling.value
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cancel_outlined, size: 17),
                    label: Text(isCancelling.value ? 'Cancelling…' : 'Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger, width: 1.3),
                      minimumSize: const Size(110, 42),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                  )
                else if (!remaining.isNegative)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      'Cancellation locked\n(>15 mins)',
                      style: TextStyle(color: AppColors.textHint, fontSize: 10.5, height: 1.3),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Past reservation: compact history row ────────────────────────────────────
class _PastReservationCard extends StatelessWidget {
  final ReservationResponse reservation;
  const _PastReservationCard({required this.reservation});

  (Color, IconData, String) get _statusVisual => switch (reservation.status) {
        'Completed' => (AppColors.success, Icons.check_circle_outline_rounded, 'Completed'),
        'Expired' => (AppColors.textHint, Icons.schedule_rounded, 'Expired'),
        'Cancelled' => (AppColors.danger, Icons.cancel_outlined, 'Cancelled'),
        _ => (AppColors.textHint, Icons.history_rounded, reservation.status),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _statusVisual;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reservation.medicationName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(
                    '${reservation.pharmacyName} · ${DateFormat('MMM d, hh:mm a').format(reservation.createdAt.toLocal())}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(reservation.status,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700, fontSize: 10.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReservations extends StatelessWidget {
  const _EmptyReservations();

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
              decoration: const BoxDecoration(
                  color: AppColors.primarySurface, shape: BoxShape.circle),
              child:
                  const Icon(Icons.bookmarks_outlined, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 18),
            const Text('No Reservations Yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'When you reserve a medication it will appear here with a pickup code and countdown.',
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(
          3,
          (i) => Container(
            height: 180,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
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
            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 50),
            const SizedBox(height: 14),
            const Text('Failed to load',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final ValueNotifier<String> filter;
  const _FilterPill(this.label, this.filter);

  @override
  Widget build(BuildContext context) {
    final selected = filter.value == label;
    return GestureDetector(
      onTap: () => filter.value = label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}
