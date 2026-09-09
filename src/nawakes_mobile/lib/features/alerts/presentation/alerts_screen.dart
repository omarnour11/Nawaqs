import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/alerts/data/alert_models.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:intl/intl.dart' show DateFormat;

part 'alerts_screen.g.dart';

@riverpod
Future<List<AlertDto>> myAlerts(Ref ref) async {
  return ref.read(apiClientProvider).getMyAlerts();
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
          onRefresh: () async => ref.invalidate(myAlertsProvider),
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
                        child: CircularProgressIndicator(color: AppColors.accentBlue),
                      )),
                      error: (e, _) => const Text('تعذر تحميل التنبيهات',
                          style: TextStyle(color: AppColors.textSecondary)),
                      data: (alerts) {
                        if (alerts.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.notifications_none_rounded,
                                    size: 40, color: AppColors.textMuted),
                                SizedBox(height: 10),
                                Text('مفيش تنبيهات',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800, fontSize: 15)),
                                SizedBox(height: 4),
                                Text(
                                  'فعّل تنبيه لأي دواء مش موجود حاليًا، وأول ما يتوفر هتوصلك إشعارات.',
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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionLabel(
                                'التنبيهات (${alerts.where((a) => a.isActive).length} نشطة)'),
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

// ─── New alert card ───────────────────────────────────────────────────────────
class _CreateAlertCard extends HookConsumerWidget {
  final VoidCallback onCreated;
  const _CreateAlertCard({required this.onCreated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameCtrl = useTextEditingController();
    final radius = useState<double>(10.0);
    final submitting = useState(false);

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
        final locationService = ref.read(locationServiceProvider);
        final pos = await locationService.getCurrentLocation();
        await ref.read(apiClientProvider).createAlert(CreateAlertRequest(
              medicationName: name,
              radiusKm: radius.value,
              latitude: pos?.latitude ?? 30.0444,
              longitude: pos?.longitude ?? 31.2357,
            ));
        nameCtrl.clear();
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
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => submit(),
            decoration: const InputDecoration(
              hintText: 'اسم الدواء — مثلاً إنسولين',
              prefixIcon: Icon(Icons.medication_rounded,
                  size: 19, color: AppColors.textMuted),
            ),
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

// ─── Alert row ────────────────────────────────────────────────────────────────
class _AlertRow extends HookConsumerWidget {
  final AlertDto alert;
  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleting = useState(false);

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

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          IconTile(
            alert.isActive
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            bg: alert.isActive ? AppColors.accentBlueBg : const Color(0xFFF1F2F4),
            color: alert.isActive ? AppColors.accentBlue : AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.medicationName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  alert.lastNotifiedAt != null
                      ? 'آخر تنبيه: ${DateFormat('d MMM · hh:mm a').format(alert.lastNotifiedAt!.toLocal())}'
                      : 'لسه مفيش تنبيهات · نطاق ${alert.radiusKm.round()} كم',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: deleting.value ? null : remove,
            icon: deleting.value
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_outline_rounded,
                    color: AppColors.textMuted, size: 20),
          ),
        ],
      ),
    );
  }
}
