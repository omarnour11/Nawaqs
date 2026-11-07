import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:nawakes_mobile/core/network/api_client.dart' show apiClientProvider;
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart' show describeApiError;
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';

class MedicationDepletionCard extends HookConsumerWidget {
  const MedicationDepletionCard({
    super.key,
    required this.medication,
    this.onChanged,
  });

  final FamilyMedicationModel medication;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitting = useState(false);
    final isDepleted = medication.daysRemaining <= 0;
    final now = DateTime.now();
    final isExpiringToday = medication.expiryDate != null &&
        medication.expiryDate!.year == now.year &&
        medication.expiryDate!.month == now.month &&
        medication.expiryDate!.day == now.day;
    final isExpired = medication.expiryDate != null &&
        !isExpiringToday &&
        medication.expiryDate!.isBefore(now);

    Color barColor;
    if (medication.daysRemaining > 14) {
      barColor = AppColors.success;
    } else if (medication.daysRemaining >= 7) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.dangerIcon;
    }

    Future<void> refill() async {
      if (submitting.value) return;
      submitting.value = true;
      try {
        await ref.read(apiClientProvider).refillFamilyMedication(
              medication.id,
              RefillFamilyMedicationRequest(stripsAdded: 1),
            );
        onChanged?.call();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(e))));
        }
      } finally {
        submitting.value = false;
      }
    }

    void reorder() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة الدواء إلى سلة الطلب الفوري')),
      );
      final name = medication.medicationName;
      try {
      context.go(
        '/home?q=${Uri.encodeComponent(name)}',
        extra: name,
      );
      } catch (_) {}
    }

    return Card(
      color: AppColors.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    medication.strength == null
                        ? medication.medicationName
                        : '${medication.medicationName} ${medication.strength}',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  medication.daysRemaining > 999
                      ? '—'
                      : '${medication.daysRemaining} يوم',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: barColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Countdown to depletion ticker ──────────────────────────
            Text(
              isDepleted
                  ? 'دواك خلص! باقي 0 يوم ⏳'
                  : 'باقي ${medication.daysRemaining} أيام على النفاذ ⏳',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDepleted ? AppColors.dangerIcon : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            // ── Expiry alerts badge ────────────────────────────────────
            if (isExpired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: NawaqsColors.coralSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'منتهي الصلاحية ⛔',
                      style: TextStyle(
                        color: NawaqsColors.coral,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'لا تتناول الدواء. اسأل الصيدلي عن الطريقة الآمنة للتخلص منه.',
                      style: TextStyle(
                        color: NawaqsColors.coral,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            else if (isExpiringToday)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ينتهي اليوم! يرجى التخلص منه وإعادة الطلب ⚠️',
                  style: TextStyle(
                    color: AppColors.warningText,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Text(
                  medication.expiryDate != null
                      ? 'صالح حتى ${DateFormat('yyyy/MM/dd').format(medication.expiryDate!)} 🛡️'
                      : 'صالح حتى 2027/12/31 🛡️',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF14532D),
                  ),
                ),
              ),
            if (isDepleted) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const NuqousMascot(mood: NuqousMood.worried, height: 48),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'نافذ الآن ⚠️ يرجى إعادة الطلب فوراً لتجنب انقطاع الجرعة.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.dangerIcon,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (medication.daysRemaining / (medication.alertThresholdDays * 3)).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.hairline,
                color: barColor,
              ),
            ),
            const SizedBox(height: 12),
            // ── 1-tap re-order button ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: reorder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: const Text(
                  'إعادة طلب الدواء ⚡',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: submitting.value ? null : refill,
                    icon: submitting.value
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add),
                    label: const Text('إضافة شريط'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final name = medication.medicationName;
                      try {
                      context.go(
                        '/home?q=${Uri.encodeComponent(name)}',
                        extra: name,
                      );
                      } catch (_) {}
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accentBlue),
                    icon: const Icon(Icons.search),
                    label: const Text('ابحث عن صيدلية'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
