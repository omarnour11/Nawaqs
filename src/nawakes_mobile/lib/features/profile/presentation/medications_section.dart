import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/profile/data/medication_models.dart';

part 'medications_section.g.dart';

@riverpod
Future<List<PatientMedicationDto>> myMedications(Ref ref) async {
  return ref.read(apiClientProvider).getMyMedications();
}

/// الأدوية الحالية — patient regimen CRUD (per mockup's medications list).
class MyMedicationsSection extends HookConsumerWidget {
  const MyMedicationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsState = ref.watch(myMedicationsProvider);

    Future<void> openForm({PatientMedicationDto? existing}) async {
      final nameCtrl =
          TextEditingController(text: existing?.medicationName ?? '');
      final strengthCtrl = TextEditingController(text: existing?.strength ?? '');
      final doseCtrl = TextEditingController(text: existing?.doseSchedule ?? '');
      final formCtrl = TextEditingController(text: existing?.form ?? '');

      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              left: 20,
              right: 20,
              top: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(existing == null ? 'إضافة دواء' : 'تعديل دواء'),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'اسم الدواء', hintText: 'مثلاً: إنسولين جلارجين'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: strengthCtrl,
                    decoration: const InputDecoration(
                        labelText: 'التركيز', hintText: '100 وحدة/مل'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: formCtrl,
                    decoration: const InputDecoration(
                        labelText: 'الشكل', hintText: 'قلم حقن'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: doseCtrl,
                decoration: const InputDecoration(
                    labelText: 'الجرعة', hintText: 'يوميًا · مرتين يوميًا'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  try {
                    final client = ProviderScope.containerOf(sheetContext)
                        .read(apiClientProvider);
                    final req = MedicationRequest(
                      id: existing?.id,
                      medicationName: nameCtrl.text.trim(),
                      strength: strengthCtrl.text.trim().isEmpty
                          ? null
                          : strengthCtrl.text.trim(),
                      form: formCtrl.text.trim().isEmpty
                          ? null
                          : formCtrl.text.trim(),
                      doseSchedule: doseCtrl.text.trim().isEmpty
                          ? null
                          : doseCtrl.text.trim(),
                      isActive: true,
                    );
                    if (existing == null) {
                      await client.addMyMedication(req);
                    } else {
                      await client.updateMyMedication(existing.id, req);
                    }
                    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                  } catch (e) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text(describeApiError(e))),
                      );
                    }
                  }
                },
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand900,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13))),
                child: Text(existing == null ? 'إضافة' : 'حفظ'),
              ),
            ],
          ),
        ),
      );
      if (saved == true) ref.invalidate(myMedicationsProvider);
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
          Row(
            children: [
              const Expanded(child: SectionLabel('الأدوية الحالية')),
              GestureDetector(
                onTap: () => openForm(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlueBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('+ إضافة',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentBlue)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          medsState.when(
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )),
            error: (e, _) => const Text('تعذر تحميل الأدوية',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            data: (meds) {
              if (meds.isEmpty) {
                return const Text(
                    'لسه مفيش أدوية — ضيف الأدوية اللي بتتناولها بانتظام.',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary));
              }
              return Column(
                children: [
                  for (final m in meds)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          IconTile(
                            Icons.medication_outlined,
                            bg: m.isActive
                                ? AppColors.successBg
                                : const Color(0xFFF1F2F4),
                            color: m.isActive
                                ? AppColors.successIcon
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.medicationName,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  _detailsLine(m),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          StatusChip(m.isActive ? 'نشط' : 'موقوف',
                              tone: m.isActive
                                  ? ChipTone.success
                                  : ChipTone.neutral),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 19, color: AppColors.textMuted),
                            onPressed: () async {
                              try {
                                await ProviderScope.containerOf(context)
                                    .read(apiClientProvider)
                                    .deleteMyMedication(m.id);
                                ref.invalidate(myMedicationsProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(describeApiError(e))),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _detailsLine(PatientMedicationDto m) {
    final parts = <String>[];
    if (m.strength != null && m.strength!.isNotEmpty) parts.add(m.strength!);
    if (m.form != null && m.form!.isNotEmpty) parts.add(m.form!);
    if (m.doseSchedule != null && m.doseSchedule!.isNotEmpty) {
      parts.add(m.doseSchedule!);
    }
    return parts.isEmpty ? 'بدون تفاصيل' : parts.join(' · ');
  }
}
