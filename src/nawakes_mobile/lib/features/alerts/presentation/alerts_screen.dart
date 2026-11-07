import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/alerts/data/alert_models.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/profile/data/medication_models.dart';
import 'package:intl/intl.dart' show DateFormat;

part 'alerts_screen.g.dart';

@riverpod
Future<List<AlertDto>> myAlerts(Ref ref) async {
  return ref.read(apiClientProvider).getMyAlerts();
}

/// The patient's active regimen, for the "من أدويتي" quick-pick chips.
@riverpod
Future<List<PatientMedicationDto>> myRegimenMeds(Ref ref) async {
  try {
    final meds = await ref.read(apiClientProvider).getMyMedications();
    return meds.where((m) => m.isActive).toList();
  } catch (_) {
    return [];
  }
}

/// Availability state for one alert: how many nearby pharmacies stock it.
@riverpod
Future<int> alertAvailability(Ref ref, String medicationName) async {
  try {
    double lat = 30.0444, lng = 31.2357;
    try {
      final pos = await ref.read(locationServiceProvider).getCurrentLocation();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}
    final res = await ref.read(apiClientProvider).searchMedications(
          medicationName,
          lat,
          lng,
          20.0,
          'Distance',
        );
    return res.results.where((r) => r.status == 'InStock').length;
  } catch (_) {
    return -1; // unknown
  }
}

/// تنبيهات التوفر — patient sets an alert for a medication + radius.
class AlertsScreen extends HookConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsState = ref.watch(myAlertsProvider);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accentBlue,
          onRefresh: () async {
            ref.invalidate(myAlertsProvider);
            ref.invalidate(myRegimenMedsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              const NawaqsTopBar(eyebrow: 'نواقص / الحساب', title: 'تنبيهات التوفر'),
              const ScreenSubtitle('هنبلّغك أول ما الدواء يبقى متاح قريب منك'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CreateAlertCard(
                        onCreated: () => ref.invalidate(myAlertsProvider)),
                    const SizedBox(height: 14),
                    alertsState.when(
                      loading: () => const Center(
                          child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(
                            color: AppColors.accentBlue),
                      )),
                      error: (e, _) => const Text('تعذر تحميل التنبيهات',
                          style: TextStyle(color: AppColors.textSecondary)),
                      data: (alerts) {
                        if (alerts.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.notifications_none_rounded,
                                    size: 40, color: AppColors.textMuted),
                                SizedBox(height: 10),
                                Text('مفيش تنبيهات',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15)),
                                SizedBox(height: 4),
                                Text(
                                  'فعّل تنبيه لأي دواء مش موجود حاليًا، وأول ما يتوفر هتوصلك إشعارات فورية.',
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
                        final activeCount =
                            alerts.where((a) => a.isActive).length;
                        final offerCount =
                            alerts.where((a) => a.hasActiveOffer).length;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: SectionLabel(
                                      'التنبيهات ($activeCount نشطة)'),
                                ),
                                if (offerCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.warningBg,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.local_offer_rounded,
                                            size: 13,
                                            color: AppColors.warningText),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$offerCount عرض نشط',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color:
                                                  AppColors.warningText),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...alerts.map((a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _AlertRow(alert: a),
                                )),
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

// ─── New alert card: autocomplete + my-meds chips + radius ───────────────────
class _CreateAlertCard extends HookConsumerWidget {
  final VoidCallback onCreated;
  const _CreateAlertCard({required this.onCreated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameCtrl = useTextEditingController();
    final focusNode = useFocusNode();
    final radius = useState<double>(10.0);
    final submitting = useState(false);
    final suggestions = useState<List<String>>([]);
    final suggestTimer = useRef<Timer?>(null);
    final showSuggestions = useState(false);
    final regimen = ref.watch(myRegimenMedsProvider);

    // Debounced autocomplete against /search/suggest (backed by the EDA catalog).
    void onNameChanged(String text) {
      showSuggestions.value = text.trim().length >= 2;
      suggestTimer.value?.cancel();
      if (text.trim().length < 2) {
        suggestions.value = [];
        return;
      }
      suggestTimer.value = Timer(const Duration(milliseconds: 350), () async {
        try {
          final result = await ref
              .read(apiClientProvider)
              .suggestMedications(text.trim());
          if (context.mounted) suggestions.value = result;
        } catch (_) {}
      });
    }

    useEffect(() => () => suggestTimer.value?.cancel(), const []);

    Future<void> submit() async {
      final name = nameCtrl.text.trim();
      if (name.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اكتب اسم الدواء (حرفين على الأقل).')),
        );
        return;
      }
      submitting.value = true;
      try {
        double lat = 30.0444, lng = 31.2357;
        try {
          final locationService = ref.read(locationServiceProvider);
          final pos = await locationService.getCurrentLocation();
          if (pos != null) {
            lat = pos.latitude;
            lng = pos.longitude;
          }
        } catch (_) {}

        await ref.read(apiClientProvider).createAlert(CreateAlertRequest(
              medicationName: name,
              radiusKm: radius.value,
              latitude: lat,
              longitude: lng,
            ));
        nameCtrl.clear();
        suggestions.value = [];
        showSuggestions.value = false;
        onCreated();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('التنبيه اتعمل على "$name".')),
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
          const SectionLabel('تنبيه جديد'),
          const SizedBox(height: 10),
          TextField(
            controller: nameCtrl,
            focusNode: focusNode,
            onChanged: onNameChanged,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => submit(),
            decoration: const InputDecoration(
              hintText: 'اسم الدواء — من الدليل أو اكتب حر',
              prefixIcon: Icon(Icons.medication_rounded,
                  size: 19, color: AppColors.textMuted),
            ),
          ),
          if (showSuggestions.value && suggestions.value.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: AppColors.page,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                children: suggestions.value
                    .take(5)
                    .map((s) => InkWell(
                          onTap: () {
                            nameCtrl.text = s;
                            showSuggestions.value = false;
                            focusNode.unfocus();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            child: Row(
                              children: [
                                const Icon(Icons.medication_liquid_rounded,
                                    size: 15, color: AppColors.textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(s,
                                      style: const TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),

          // Quick-pick chips from the patient's own current regimen.
          regimen.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (meds) {
              if (meds.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('من أدويتك الحالية',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: meds.take(6).map((m) {
                        final selected =
                            nameCtrl.text.trim() == m.medicationName.trim();
                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            nameCtrl.text = m.medicationName;
                            showSuggestions.value = false;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accentBlue
                                  : AppColors.accentBlueBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              m.medicationName +
                                  (m.strength != null
                                      ? ' ${m.strength}'
                                      : ''),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : AppColors.accentBlue,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 6),
          Row(
            children: [
              const Text('نطاق التنبيه',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700)),
              Expanded(
                child: Slider(
                  value: radius.value,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '${radius.value.round()} كم',
                  activeColor: AppColors.accentBlue,
                  onChanged: (v) => radius.value = v,
                ),
              ),
              Text('${radius.value.round()} كم',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentBlue)),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submitting.value ? null : submit,
              icon: submitting.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_alert_rounded, size: 17),
              label: const Text('فعّل التنبيه'),
              style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13))),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Alert row: toggle + queue state + availability ──────────────────────────
class _AlertRow extends HookConsumerWidget {
  final AlertDto alert;
  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleting = useState(false);
    final toggling = useState(false);
    final availability = ref.watch(alertAvailabilityProvider(alert.medicationName));

    Future<void> remove() async {
      deleting.value = true;
      try {
        await ref.read(apiClientProvider).deleteAlert(alert.id);
        ref.invalidate(myAlertsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      } finally {
        deleting.value = false;
      }
    }

    Future<void> toggle(bool value) async {
      toggling.value = true;
      try {
        await ref
            .read(apiClientProvider)
            .toggleAlert(alert.id, ToggleAlertRequest(isActive: value));
        ref.invalidate(myAlertsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      } finally {
        toggling.value = false;
      }
    }

    final offerActive = alert.hasActiveOffer;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: offerActive ? AppColors.warningIcon : AppColors.hairline,
          width: offerActive ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(
                offerActive
                    ? Icons.local_offer_rounded
                    : alert.isActive
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                bg: offerActive
                    ? AppColors.warningBg
                    : alert.isActive
                        ? AppColors.accentBlueBg
                        : const Color(0xFFF1F2F4),
                color: offerActive
                    ? AppColors.warningText
                    : alert.isActive
                        ? AppColors.accentBlue
                        : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(alert.medicationName,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: alert.isActive
                                ? AppColors.successBg
                                : const Color(0xFFF1F2F4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            alert.isActive ? 'نشط' : 'موقوف',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: alert.isActive
                                  ? AppColors.successText
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.lastNotifiedAt != null
                          ? 'آخر تنبيه: ${DateFormat('d MMM · hh:mm a').format(alert.lastNotifiedAt!.toLocal())} · نطاق ${alert.radiusKm.round()} كم'
                          : 'لسه مفيش تنبيهات · نطاق ${alert.radiusKm.round()} كم',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    // Live availability: متاح حالياً في X صيدلية قريبة
                    availability.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (count) {
                        if (count < 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                count > 0
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                size: 13,
                                color: count > 0
                                    ? AppColors.successIcon
                                    : AppColors.dangerIcon,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                count > 0
                                    ? 'متاح حالياً في $count صيدلية قريبة'
                                    : 'مش متاح قريب منك دلوقتي',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: count > 0
                                      ? AppColors.successText
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Pause/resume switch — paused alerts stop generating offers.
              toggling.value
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Switch(
                      value: alert.isActive,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.accentBlue,
                      onChanged: toggle,
                    ),
            ],
          ),
          if (offerActive) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_offer_rounded,
                      size: 16, color: AppColors.warningText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'فيه عرض حجز ليك دلوقتي (${alert.queuePosition > 0 ? 'دور ${alert.queuePosition}' : 'دورك جاهز'}) — ينتهي ${alert.offerExpiresAt != null ? DateFormat('hh:mm a').format(alert.offerExpiresAt!.toLocal()) : ''}. افتح الإشعارات للتأكيد.',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warningText),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/notifications'),
                    child: const Text('تأكيد',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: deleting.value ? null : remove,
                icon: deleting.value
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline_rounded,
                        size: 16, color: AppColors.textMuted),
                label: const Text('حذف',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
