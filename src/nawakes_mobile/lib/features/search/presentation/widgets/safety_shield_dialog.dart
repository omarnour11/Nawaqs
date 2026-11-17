import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

/// Safety decision containing permission to proceed and family member flag.
class SafetyCheckDecision {
  final bool proceed;
  final bool isForFamilyMember;

  const SafetyCheckDecision({required this.proceed, this.isForFamilyMember = false});
}

/// Pre-checkout clinical safety shield.
///
/// Calls GET /reservations/safety-check before confirming a reservation and
/// surfaces the result:
/// - Critical alert  → blocking dialog with "الدواء ليس لي" option for pregnancy contraindication.
/// - Warning         → amber dialog, user can proceed at their own risk.
/// - Clean           → reserve immediately.
Future<SafetyCheckDecision> guardReservationWithSafetyCheck(
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
    return const SafetyCheckDecision(proceed: true);
  }

  if (!context.mounted) return const SafetyCheckDecision(proceed: false);
  if (check.alerts.isEmpty) return const SafetyCheckDecision(proceed: true);

  final decision = await showDialog<SafetyCheckDecision>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _SafetyShieldDialog(
      medicationName: medicationName,
      check: check!,
      hasCritical: check.hasCriticalAlerts,
    ),
  );

  return decision ?? const SafetyCheckDecision(proceed: false);
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
              if (check.alerts.any((a) =>
                  a.category == 'PregnancyContraindication' ||
                  a.id == 'PREG_CONTRAINDICATION')) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.maxFinite,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pop(const SafetyCheckDecision(proceed: false)),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('فهمت، مش هكمل الحجز'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.dangerText,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.maxFinite,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.family_restroom_rounded,
                                      color: Color(0xFFD97706)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('تأكيد طلب لفرد آخر بالأسرة',
                                        style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                              content: const Text(
                                'إقرار سريري:\nهل تؤكدين أن هذا الدواء مخصص لشخص آخر في العائلة ولن يتم استخدامه من قِبلكِ كحامل؟\n\nسيتم إشعار الصيدلي بذلك في تفاصيل الطلب للتحقق عند التسليم.',
                                style: TextStyle(fontSize: 13, height: 1.5),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('تراجع'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFD97706)),
                                  child: const Text('نعم، أؤكد أن الدواء ليس لي'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            Navigator.of(context).pop(const SafetyCheckDecision(
                                proceed: true, isForFamilyMember: true));
                          }
                        },
                        icon: const Icon(Icons.family_restroom_rounded,
                            size: 18, color: Color(0xFFD97706)),
                        label: const Text('الدواء ليس لي (طلب لفرد آخر بالأسرة)',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFD97706), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.maxFinite,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context)
                        .pop(const SafetyCheckDecision(proceed: false)),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('فهمت، مش هكمل الحجز'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.dangerText,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ]
          : [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context)
                          .pop(const SafetyCheckDecision(proceed: false)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context)
                          .pop(const SafetyCheckDecision(proceed: true)),
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
