import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

/// Pre-checkout clinical safety shield.
///
/// Calls GET /reservations/safety-check before confirming a reservation and
/// surfaces the result:
/// - Critical alert  → blocking red dialog (reserve refused).
/// - Warning         → amber dialog, user can proceed at their own risk.
/// - Clean           → reserve immediately.
Future<bool> guardReservationWithSafetyCheck(
  BuildContext context,
  WidgetRef ref, {
  required String inventoryItemId,
  required String medicationName,
}) async {
  ReservationSafetyCheckResult? check;
  try {
    check = await ref
        .read(apiClientProvider)
        .checkReservationSafety(inventoryItemId: inventoryItemId);
  } catch (_) {
    // Safety endpoint unavailable → fail open (server re-checks on reserve).
    return true;
  }

  if (!context.mounted) return false;
  if (check.alerts.isEmpty) return true;

  final hasCritical = check.hasCriticalAlerts;
  final proceed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _SafetyShieldDialog(
      medicationName: medicationName,
      check: check!,
      hasCritical: hasCritical,
    ),
  );

  return proceed == true;
}

class _SafetyShieldDialog extends StatelessWidget {
  final String medicationName;
  final ReservationSafetyCheckResult check;
  final bool hasCritical;

  const _SafetyShieldDialog({
    required this.medicationName,
    required this.check,
    required this.hasCritical,
  });

  @override
  Widget build(BuildContext context) {
    final bg = hasCritical ? AppColors.dangerBg : AppColors.warningBg;
    final fg = hasCritical ? AppColors.dangerText : AppColors.warningText;
    final icon = hasCritical ? Icons.gpp_bad_rounded : Icons.gpp_maybe_rounded;
    final title = hasCritical
        ? 'توقف — خطر دوائي محتمل'
        : 'تنبيه أمان دوائي';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: fg, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'بخصوص $medicationName:',
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...check.alerts.map((alert) => _AlertTile(alert: alert)),
            if (check.duplicateActiveIngredientMedications.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'نفس المادة الفعالة موجودة أصلاً في: ${check.duplicateActiveIngredientMedications.join('، ')}',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
      actions: hasCritical
          ? [
              // Critical → the only way out is cancel; shield stays closed.
              SizedBox(
                width: double.maxFinite,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('فهمت، مش هكمل الحجز'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.dangerText,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ]
          : [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.warningText,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('كمّل على مسؤوليتي'),
                    ),
                  ),
                ],
              ),
            ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final SafetyAlert alert;

  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final critical = alert.severity == 'Critical';
    final fg = critical ? AppColors.dangerText : AppColors.warningText;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: critical ? AppColors.dangerBg : AppColors.warningBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                critical ? Icons.priority_high_rounded : Icons.info_outline,
                size: 16,
                color: fg,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  alert.title,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: fg),
                ),
              ),
            ],
          ),
          if (alert.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              alert.description,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textPrimary),
            ),
          ],
          if (alert.recommendation.isNotEmpty &&
              alert.recommendation != alert.description) ...[
            const SizedBox(height: 4),
            Text(
              'التوصية: ${alert.recommendation}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
