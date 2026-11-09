import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/services/local_notifications_service.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart'
    show describeApiError;
import 'package:nawakes_mobile/core/ui/widgets.dart'
    show unreadNotificationsCountProvider, consumedActionNotificationsProvider;
import 'package:nawakes_mobile/features/notifications/presentation/notifications_screen.dart'
    show myNotificationsProvider;

/// In-memory cache of notification IDs that were already presented to the user
/// in dialogs during this app session to prevent persistent annoying popups on every rebuild.
final dismissedPopupAlertIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Patient bottom nav per the design spec: 4 items, icon above 11px label,
/// active item in accent blue. Find / Passes / Account / Support.
class PatientShell extends HookConsumerWidget {
  final Widget child;

  const PatientShell({super.key, required this.child});

  static const _locations = ['/home', '/passes', '/profile', '/support'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final selectedIndex =
        _locations.indexWhere((l) => loc.startsWith(l)).clamp(0, 3);

    final hasCheckedAlerts = useRef(false);

    useEffect(() {
      Future.microtask(() async {
        if (hasCheckedAlerts.value) return;
        hasCheckedAlerts.value = true;

        try {
          final notifService = ref.read(localNotificationsServiceProvider);
          await notifService.initialize(
            onSelectNotification: (payload) {
              if (payload != null && payload.isNotEmpty && context.mounted) {
                context.push(payload);
              }
            },
          );
          await notifService.requestPermissions();

          final notifs = await ref.read(apiClientProvider).getNotifications();
          final dismissedIds = ref.read(dismissedPopupAlertIdsProvider);
          final critical = notifs
              .where((n) =>
                  !n.isRead &&
                  !dismissedIds.contains(n.id) &&
                  (n.type == 'AvailabilityOfferSent' ||
                      n.type == 'MedicationAvailable' ||
                      n.type == 'ClinicalConflict'))
              .toList();

          if (critical.isNotEmpty && context.mounted) {
            final alert = critical.first;

            // Mark as dismissed in-memory immediately so subsequent rebuilds never pop it up again
            ref
                .read(dismissedPopupAlertIdsProvider.notifier)
                .update((s) => {...s, alert.id});

            await notifService.showCriticalNotification(
              id: alert.id.hashCode,
              title: alert.title,
              body: alert.body,
              payload: '/notifications',
            );

            final isExpired = alert.type == 'OfferExpired' ||
                (alert.type == 'AvailabilityOfferSent' &&
                    DateTime.now()
                            .toUtc()
                            .difference(alert.createdAt)
                            .inMinutes >=
                        15);
            final isClinicalConflict = alert.type == 'ClinicalConflict';
            final altMatch = RegExp(
              r'(?:بديلاً آمناً:|بديل:|البديل:)\s*([^\s.،,]+(?:\s+[^\s.،,]+)*)',
              caseSensitive: false,
            ).firstMatch(alert.body);
            final altMed = altMatch?.group(1)?.replaceAll(RegExp(r'[.،,]+$'), '').trim();

            if (!context.mounted) return;

            // Helper to dismiss and mark read in backend reliably
            Future<void> dismissAndMarkRead() async {
              try {
                await ref
                    .read(apiClientProvider)
                    .markNotificationsRead(MarkReadRequest(id: alert.id));
                ref.invalidate(unreadNotificationsCountProvider);
                ref.invalidate(myNotificationsProvider);
              } catch (_) {}
            }

            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (dialogCtx) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      Icon(
                        isClinicalConflict
                            ? Icons.health_and_safety_rounded
                            : Icons.notification_important_rounded,
                        color: isClinicalConflict
                            ? NawaqsColors.tealDark
                            : AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isClinicalConflict
                              ? 'استشارة الصيدلي: ترشيح بديل آمن 💊'
                              : 'تنبيه عاجل: توفر دواء مطلوب!',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isClinicalConflict
                                ? AppColors.accentBlueBg
                                : AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: (isClinicalConflict
                                        ? AppColors.accentBlue
                                        : AppColors.primary)
                                    .withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isClinicalConflict
                                    ? Icons.medication_liquid_rounded
                                    : Icons.medication_rounded,
                                color: isClinicalConflict
                                    ? AppColors.accentBlue
                                    : AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  alert.body,
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      height: 1.45,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isExpired) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.dangerBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.timer_off_outlined,
                                    color: AppColors.dangerText, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'انتهت مهلة هذا العرض أو نفد المخزون (خلص)',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: AppColors.dangerText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ] else if (!isClinicalConflict) ...[
                          const Text(
                            'فرصة فورية لحجز الدواء وتثبيت طلبك قبل نفاد الكمية في الصيدلية.',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    if (isClinicalConflict) ...[
                      // ── 3 Explicit Arabic Actions for Alternative Medication ──
                      // 1. احجز من نفس الصيدلية (لو متاح)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: NawaqsColors.tealDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                          label: Text(
                            altMed != null && altMed.isNotEmpty
                                ? 'احجز $altMed من نفس الصيدلية (لو متاح)'
                                : 'احجز من نفس الصيدلية (لو متاح)',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          onPressed: () async {
                            Navigator.of(dialogCtx).pop();
                            await dismissAndMarkRead();

                            try {
                              if (alert.relatedEntityId != null &&
                                  alert.relatedEntityId!.isNotEmpty) {
                                await ref
                                    .read(apiClientProvider)
                                    .reserveAlternative(alert.relatedEntityId!);
                                ref
                                    .read(consumedActionNotificationsProvider.notifier)
                                    .mark(alert.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: AppColors.primary,
                                      content: Text(
                                          'تم تأكيد حجز البديل بنجاح لمدة ساعتين!'),
                                    ),
                                  );
                                  context.go('/passes');
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppColors.primary,
                                    content: Text(
                                        'الدواء البديل غير متوفر حالياً في هذه الصيدلية. جاري تحويلك للبحث عنه في الصيدليات الأخرى...'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                                if (altMed != null && altMed.isNotEmpty) {
                                  context.push(
                                      '/search?query=${Uri.encodeComponent(altMed)}');
                                }
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 2. ابحث عن الدواء البديل
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NawaqsColors.tealDark,
                            side: const BorderSide(color: NawaqsColors.tealDark),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: Text(
                            altMed != null && altMed.isNotEmpty
                                ? 'ابحث عن الدواء البديل ($altMed)'
                                : 'ابحث عن الدواء البديل',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          onPressed: () async {
                            Navigator.of(dialogCtx).pop();
                            await dismissAndMarkRead();

                            if (context.mounted &&
                                altMed != null &&
                                altMed.isNotEmpty) {
                              context.push(
                                  '/search?query=${Uri.encodeComponent(altMed)}');
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 6),

                      // 3. خروج / إغلاق
                      Center(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textMuted,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text(
                            'خروج',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          onPressed: () async {
                            Navigator.of(dialogCtx).pop();
                            await dismissAndMarkRead();
                          },
                        ),
                      ),
                    ] else ...[
                      // ── Default Availability Offer Flow ──
                      if (!isExpired)
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brand900,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            Navigator.of(dialogCtx).pop();
                            await dismissAndMarkRead();

                            try {
                              if (alert.type == 'AvailabilityOfferSent' &&
                                  alert.relatedEntityId != null) {
                                await ref
                                    .read(apiClientProvider)
                                    .claimQueueOffer(alert.relatedEntityId!);
                                ref
                                    .read(consumedActionNotificationsProvider.notifier)
                                    .mark(alert.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'تم تأكيد حجز العرض بنجاح لمدة ساعتين!')),
                                  );
                                  context.go('/passes');
                                }
                              } else {
                                final medMatch = RegExp(
                                  r'(?:دواء|طلبكم لـ|توفر)\s*([^\s]+(?:\s+[^\s]+){0,2})',
                                  caseSensitive: false,
                                ).firstMatch(alert.body);
                                var medName = medMatch?.group(1)?.trim();
                                if (medName != null) {
                                  medName = medName
                                      .replaceAll(
                                          RegExp(r'(?:متوفر|الآن|في|صيدلية).*$',
                                              caseSensitive: false),
                                          '')
                                      .replaceAll(RegExp(r'[.،,]+$'), '')
                                      .trim();
                                }
                                if (medName != null && medName.isNotEmpty) {
                                  context.push(
                                      '/search?query=${Uri.encodeComponent(medName)}');
                                } else {
                                  context.go('/passes');
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'تعذر إتمام الحجز: ${describeApiError(e)}')),
                                );
                              }
                            }
                          },
                          child: const Text('حجز الآن'),
                        ),
                      OutlinedButton(
                        onPressed: () async {
                          Navigator.of(dialogCtx).pop();
                          await dismissAndMarkRead();
                        },
                        child: const Text('خروج'),
                      ),
                    ],
                  ],
                );
              },
            );
          }
        } catch (_) {}
      });
      return null;
    }, const []);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => switch (i) {
          0 => context.go('/home'),
          1 => context.go('/passes'),
          2 => context.go('/profile'),
          _ => context.go('/support'),
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'الحجوزات',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_2_outlined),
            selectedIcon: Icon(Icons.person_2_rounded),
            label: 'الحساب',
          ),
          const NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent_rounded),
            label: 'الدعم',
          ),
        ].map((d) => d).toList(),
      ),
    );
  }
}
