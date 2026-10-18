import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/notifications/data/notification_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:intl/intl.dart';

part 'notifications_screen.g.dart';

@riverpod
Future<List<NotificationDto>> myNotifications(Ref ref) async {
  return ref.read(apiClientProvider).getNotifications();
}

class NotificationsScreen extends HookConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myNotificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref.read(apiClientProvider).markNotificationsRead(MarkReadRequest());
                ref.invalidate(myNotificationsProvider);
              } catch (_) {}
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: state.when(
        data: (items) {
          if (items.isEmpty) {
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
                      child: const Icon(Icons.notifications_none_rounded,
                          color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(height: 18),
                    const Text('You\'re all caught up',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                      'Reservation updates, availability alerts and pharmacy news will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(myNotificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (c, i2) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _NotificationCard(item: items[i]),
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 50),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(myNotificationsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends HookConsumerWidget {
  final NotificationDto item;
  const _NotificationCard({required this.item});

  (IconData, Color) get _visual => switch (item.type) {
        'ReservationCreated' => (Icons.bookmark_added_rounded, AppColors.success),
        'ReservationCompleted' => (Icons.task_alt_rounded, AppColors.success),
        'ReservationExpired' => (Icons.schedule_rounded, AppColors.warning),
        'ReservationCancelled' => (Icons.cancel_outlined, AppColors.danger),
        'MedicationAvailable' => (Icons.medication_rounded, AppColors.primary),
        'PharmacyApproved' => (Icons.verified_rounded, AppColors.success),
        'PharmacyRejected' => (Icons.gavel_rounded, AppColors.danger),
        'AvailabilityOfferSent' => (Icons.notifications_active_rounded, AppColors.accentBlue),
        'OfferExpired' => (Icons.timer_off_outlined, AppColors.warning),
        'CaregiverInviteReceived' => (Icons.person_add_alt_1_rounded, AppColors.accentBlue),
        'CaregiverInviteAccepted' => (Icons.group_add_rounded, AppColors.success),
        'FamilyMedicationRefilled' => (Icons.inventory_2_outlined, AppColors.success),
        'FamilyMedicationLow' => (Icons.warning_amber_rounded, AppColors.warning),
        _ => (Icons.info_outline_rounded, AppColors.info),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = _visual;
    final marking = useState(false);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: item.isRead
            ? null
            : () async {
                marking.value = true;
                try {
                  await ref
                      .read(apiClientProvider)
                      .markNotificationsRead(MarkReadRequest(id: item.id));
                  ref.invalidate(myNotificationsProvider);
                } catch (_) {}
              },
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 19),
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
                            item.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration:
                                const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(item.body,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary, height: 1.45)),
                    const SizedBox(height: 5),
                    Text(DateFormat('MMM d · hh:mm a').format(item.createdAt.toLocal()),
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textHint)),
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
