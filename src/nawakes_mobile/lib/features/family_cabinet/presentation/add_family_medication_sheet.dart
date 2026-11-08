import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart' show apiClientProvider;
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart' show describeApiError;
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';

/// Bottom sheet to add a tracked medication to a family member profile.
/// Returns true when a medication was added.
Future<bool> showAddFamilyMedicationSheet(
  BuildContext context, {
  required String profileId,
  required String profileNickname,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddFamilyMedicationSheet(
      profileId: profileId,
      profileNickname: profileNickname,
    ),
  );
  return result ?? false;
}

class _AddFamilyMedicationSheet extends HookConsumerWidget {
  final String profileId;
  final String profileNickname;

  const _AddFamilyMedicationSheet({
    required this.profileId,
    required this.profileNickname,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medNameCtrl = useTextEditingController();
    final strengthCtrl = useTextEditingController();
    final stripsCtrl = useTextEditingController(text: '2');
    final unitsPerStripCtrl = useTextEditingController(text: '10');
    final dailyDoseCtrl = useTextEditingController(text: '1');
    final thresholdCtrl = useTextEditingController(text: '5');
    final submitting = useState(false);

    Future<void> submit() async {
      final name = medNameCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال اسم الدواء')),
        );
        return;
      }
      if (submitting.value) return;
      submitting.value = true;

      try {
        final strips = int.tryParse(stripsCtrl.text.trim()) ?? 1;
        final units = int.tryParse(unitsPerStripCtrl.text.trim()) ?? 10;
        final dailyDose = num.tryParse(dailyDoseCtrl.text.trim()) ?? 1;
        final alertDays = int.tryParse(thresholdCtrl.text.trim()) ?? 5;

        await ref.read(apiClientProvider).addFamilyMedication(
              profileId,
              FamilyMedicationRequest(
                medicationName: name,
                strength: strengthCtrl.text.trim().isEmpty ? null : strengthCtrl.text.trim(),
                stripsCount: strips,
                unitsPerStrip: units,
                dailyDoseUnits: dailyDose,
                alertThresholdDays: alertDays,
              ),
            );

        if (context.mounted) Navigator.of(context).pop(true);
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.medication_rounded, color: NawaqsColors.teal, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'إضافة دواء لـ $profileNickname',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: NawaqsColors.tealDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'أدخل بيانات الجرعة لمتابعة موعد نفاذ الدواء وحجزه تلقائياً قبل أن ينتهي.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: medNameCtrl,
              decoration: InputDecoration(
                labelText: 'اسم الدواء *',
                hintText: 'مثال: Panadol Extra أو كونكور',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.healing_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: strengthCtrl,
              decoration: InputDecoration(
                labelText: 'التركيز (اختياري)',
                hintText: 'مثال: 500mg أو 5mg',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.science_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: stripsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'عدد الشرائط',
                      hintText: '2',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: unitsPerStripCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'أقراص بالشريط',
                      hintText: '10',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: dailyDoseCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'الجرعة اليومية (قرص)',
                      hintText: '1',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: thresholdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'تنبيه قبل النفاذ بـ (أيام)',
                      hintText: '5',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: submit,
              icon: submitting.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                submitting.value ? 'جاري الحفظ...' : 'حفظ الدواء في الخزانة',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: NawaqsColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

