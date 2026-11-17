import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart' show apiClientProvider;
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart' show describeApiError;
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';

/// Bottom sheet to add or edit a tracked medication in a family member profile.
/// Returns true when a medication was added or updated.
Future<bool> showAddFamilyMedicationSheet(
  BuildContext context, {
  required String profileId,
  required String profileNickname,
  FamilyMedicationModel? medicationToEdit,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddFamilyMedicationSheet(
      profileId: profileId,
      profileNickname: profileNickname,
      medicationToEdit: medicationToEdit,
    ),
  );
  return result ?? false;
}

class _AddFamilyMedicationSheet extends HookConsumerWidget {
  final String profileId;
  final String profileNickname;
  final FamilyMedicationModel? medicationToEdit;

  const _AddFamilyMedicationSheet({
    required this.profileId,
    required this.profileNickname,
    this.medicationToEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medNameCtrl = useTextEditingController(text: medicationToEdit?.medicationName ?? '');
    final strengthCtrl = useTextEditingController(text: medicationToEdit?.strength ?? '');
    final stripsCtrl = useTextEditingController(text: medicationToEdit?.stripsCount.toString() ?? '2');
    final unitsPerStripCtrl = useTextEditingController(text: medicationToEdit?.unitsPerStrip.toString() ?? '10');
    final dailyDoseCtrl = useTextEditingController(text: medicationToEdit != null ? medicationToEdit!.dailyDoseUnits.toString() : '1');
    final thresholdCtrl = useTextEditingController(text: medicationToEdit?.alertThresholdDays.toString() ?? '5');
    final submitting = useState(false);

    // Predictive suggestions from official EDA catalog
    final suggestions = useState<List<MedicationCatalogItemDto>>([]);
    final isSuggesting = useState(false);
    final debounceTimer = useRef<Timer?>(null);

    void onMedNameChanged(String val) {
      final q = val.trim();
      if (q.length < 2) {
        suggestions.value = [];
        isSuggesting.value = false;
        return;
      }
      isSuggesting.value = true;
      debounceTimer.value?.cancel();
      debounceTimer.value = Timer(const Duration(milliseconds: 250), () async {
        try {
          final res = await ref.read(apiClientProvider).catalogLookup(q, 5);
          suggestions.value = res;
        } catch (_) {
          suggestions.value = [];
        } finally {
          isSuggesting.value = false;
        }
      });
    }

    void applySuggestion(MedicationCatalogItemDto item) {
      medNameCtrl.text = item.name;
      if (item.strength != null && item.strength!.isNotEmpty) {
        strengthCtrl.text = item.strength!;
      }
      suggestions.value = [];
    }

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

        final body = FamilyMedicationRequest(
          medicationName: name,
          strength: strengthCtrl.text.trim().isEmpty ? null : strengthCtrl.text.trim(),
          stripsCount: strips,
          unitsPerStrip: units,
          dailyDoseUnits: dailyDose,
          alertThresholdDays: alertDays,
        );

        if (medicationToEdit != null) {
          await ref.read(apiClientProvider).updateFamilyMedication(medicationToEdit!.id, body);
        } else {
          await ref.read(apiClientProvider).addFamilyMedication(profileId, body);
        }

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

    final isEdit = medicationToEdit != null;

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
                Icon(isEdit ? Icons.edit_note_rounded : Icons.medication_rounded,
                    color: NawaqsColors.teal, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEdit ? 'تعديل دواء ${medicationToEdit!.medicationName}' : 'إضافة دواء لـ $profileNickname',
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
              onChanged: onMedNameChanged,
              decoration: InputDecoration(
                labelText: 'اسم الدواء *',
                hintText: 'مثال: Panadol Extra أو كونكور',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.healing_rounded),
                suffixIcon: isSuggesting.value
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),

            // Predictive Suggestion Chips from EDA Database
            if (suggestions.value.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.medication_rounded, size: 16, color: Color(0xFF0F766E)),
                        SizedBox(width: 6),
                        Text(
                          'أدوية مطابقة:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...suggestions.value.map((s) {
                      final hasStrength = s.strength != null && s.strength!.isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () => applySuggestion(s),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.add_circle_rounded, size: 18, color: Color(0xFF0F766E)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (hasStrength) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      s.strength!,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

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
                  : Icon(isEdit ? Icons.save_rounded : Icons.check_circle_rounded),
              label: Text(
                submitting.value
                    ? 'جاري الحفظ...'
                    : (isEdit ? 'حفظ التعديلات' : 'حفظ الدواء في الخزانة'),
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
