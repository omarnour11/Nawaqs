import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart' show apiClientProvider, describeApiError;
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';

class MedicationDepletionCard extends HookConsumerWidget {
  const MedicationDepletionCard({super.key, required this.medication, required this.onChanged});

  final FamilyMedicationModel medication;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitting = useState(false);

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
        await ref.read(apiClientProvider).refillFamilyMedication(\n              medication.id,\n              RefillFamilyMedicationRequest(stripsAdded: 1),\n            );
        onChanged();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(e))));
        }
      } finally {
        submitting.value = false;
      }
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
                      // Handled by parent routing to pharmacy search for this medication.
                      onChanged();
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
