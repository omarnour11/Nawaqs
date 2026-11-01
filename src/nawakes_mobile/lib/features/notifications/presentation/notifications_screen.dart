import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/notifications/data/notification_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
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
        title: const Text('الإشعارات'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                ref.read(unreadNotificationsCountProvider.notifier).resetToZero();
                await ref.read(apiClientProvider).markNotificationsRead(MarkReadRequest());
                ref.invalidate(unreadNotificationsCountProvider);
                ref.invalidate(myNotificationsProvider);
              } catch (_) {}
            },
            child: const Text('تحديد الكل كمقروء'),
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
                    const Text('لا توجد إشعارات جديدة',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                      'تحديثات الحجز وتنبيهات التوفر وأخبار الصيدليات ستظهر هنا.',
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
              const Text('تعذر تحميل الإشعارات حالياً',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(myNotificationsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
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
        'ClinicalConflict' => (Icons.warning_amber_rounded, AppColors.danger),
        _ => (Icons.info_outline_rounded, AppColors.info),
      };

  void _navigateToTarget(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    switch (item.type) {
      case 'ReservationCreated':
      case 'ReservationCompleted':
      case 'ReservationExpired':
      case 'ReservationCancelled':
      case 'ClinicalConflict':
        {
          final match = RegExp(
            r'(?:ورشح لك بديلاً آمناً|ورشح لك بديلاً|رشح لك بديل|البديل المقترح|بديل):\s*([^.\n]+)',
            caseSensitive: false,
          ).firstMatch(item.body);
          final alt = match
              ?.group(1)
              ?.replaceAll(RegExp(r'[.،,]+$'), '')
              .trim();
          if (alt != null && alt.isNotEmpty) {
            context.push('/search?query=${Uri.encodeComponent(alt)}');
          } else {
            context.go('/passes');
          }
        }
        break;
      case 'MedicationAvailable':
      case 'AvailabilityOfferSent':
      case 'OfferExpired':
        context.go('/alerts');
        break;
      case 'CaregiverInviteReceived':
      case 'CaregiverInviteAccepted':
      case 'FamilyMedicationRefilled':
      case 'FamilyMedicationLow':
        context.go('/family-cabinet');
        break;
      case 'TicketReply':
      case 'TicketStatusChanged':
      case 'Support':
        context.go('/support');
        break;
      case 'PharmacyApproved':
      case 'PharmacyRejected':
        context.go('/pharmacy');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = _visual;
    final marking = useState(false);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () async {
          if (!item.isRead) {
            marking.value = true;
            try {
              await ref
                  .read(apiClientProvider)
                  .markNotificationsRead(MarkReadRequest(id: item.id));
              ref.read(unreadNotificationsCountProvider.notifier).decrement();
              ref.invalidate(myNotificationsProvider);
              ref.invalidate(unreadNotificationsCountProvider);
            } catch (_) {}
          }
          if (context.mounted) {
            _navigateToTarget(context);
          }
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
                    Text(DateFormat('d MMM · hh:mm a').format(item.createdAt.toLocal()),
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textHint)),
                    if (item.type == 'ClinicalConflict') ...[
                      () {
                        final match = RegExp(
                          r'(?:ورشح لك بديلاً آمناً|ورشح لك بديلاً|رشح لك بديل|البديل المقترح|بديل):\s*([^.\n]+)',
                          caseSensitive: false,
                        ).firstMatch(item.body);
                        final alt = match
                            ?.group(1)
                            ?.replaceAll(RegExp(r'[.،,]+$'), '')
                            .trim();
                        if (alt == null || alt.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand900,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () async {
                                if (item.relatedEntityId != null && item.relatedEntityId!.isNotEmpty) {
                                  try {
                                    await ref.read(apiClientProvider).reserveAlternative(item.relatedEntityId!);
                                    if (!item.isRead) {
                                      try {
                                        await ref.read(apiClientProvider).markNotificationsRead(MarkReadRequest(id: item.id));
                                        ref.read(unreadNotificationsCountProvider.notifier).decrement();
                                        ref.invalidate(myNotificationsProvider);
                                        ref.invalidate(unreadNotificationsCountProvider);
                                      } catch (_) {}
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تم تأكيد حجز البديل بنجاح لمدة ساعتين!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      context.go('/passes');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('تعذر حجز البديل: ${describeApiError(e)}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  if (!item.isRead) {
                                    try {
                                      await ref.read(apiClientProvider).markNotificationsRead(MarkReadRequest(id: item.id));
                                      ref.read(unreadNotificationsCountProvider.notifier).decrement();
                                      ref.invalidate(myNotificationsProvider);
                                      ref.invalidate(unreadNotificationsCountProvider);
                                    } catch (_) {}
                                  }
                                  if (context.mounted) {
                                    context.push('/search?query=${Uri.encodeComponent(alt)}');
                                  }
                                }
                              },
                              icon: const Icon(Icons.flash_on_rounded, size: 16),
                              label: Text(
                                'حجز البديل ($alt) بنقرة واحدة',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        );
                      }(),
                    ],
                    if (item.type == 'AvailabilityOfferSent' && item.relatedEntityId != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              try {
                                await ref.read(apiClientProvider).claimQueueOffer(item.relatedEntityId!);
                                if (!item.isRead) {
                                  try {
                                    await ref.read(apiClientProvider).markNotificationsRead(MarkReadRequest(id: item.id));
                                    ref.read(unreadNotificationsCountProvider.notifier).decrement();
                                    ref.invalidate(myNotificationsProvider);
                                    ref.invalidate(unreadNotificationsCountProvider);
                                  } catch (_) {}
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم تأكيد حجز العرض بنجاح لمدة ساعتين!')),
                                  );
                                  context.go('/passes');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('تعذر تأكيد الحجز: ${describeApiError(e)}')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                            label: const Text(
                              'تأكيد حجز العرض الآن (خلال 15 دقيقة)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textHint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
