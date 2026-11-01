import 'dart:async';
import 'package:flutter_hooks/flutter_hooks.dart';
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
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => _MedicationEditSheet(existing: existing),
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
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تعذر تحميل الأدوية: ${describeApiError(e)}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(myMedicationsProvider),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
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


class _MedicationEditSheet extends HookConsumerWidget {
  final PatientMedicationDto? existing;
  const _MedicationEditSheet({this.existing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameCtrl = useTextEditingController(text: existing?.medicationName ?? '');
    final strengthCtrl = useTextEditingController(text: existing?.strength ?? '');
    final doseCtrl = useTextEditingController(text: existing?.doseSchedule ?? '');
    final formCtrl = useTextEditingController(text: existing?.form ?? '');

    final suggestions = useState<List<String>>([]);
    final isLoadingSuggestions = useState(false);
    final debounceTimer = useRef<Timer?>(null);

    void searchSuggestions(String q) {
      debounceTimer.value?.cancel();
      final query = q.trim();
      if (query.length < 2) {
        suggestions.value = [];
        isLoadingSuggestions.value = false;
        return;
      }

      isLoadingSuggestions.value = true;
      debounceTimer.value = Timer(const Duration(milliseconds: 300), () async {
        try {
          final results = await ref.read(apiClientProvider).suggestMedications(query);
          suggestions.value = results;
        } catch (_) {
          suggestions.value = [];
        } finally {
          isLoadingSuggestions.value = false;
        }
      });
    }

    void applySuggestion(String rawName) {
      // 1. Extract strength
      final strengthMatch = RegExp(r'(\d+(?:\.\d+)?\s*(?:mg|gm|mcg|ml|iu|%|مجم|مل))', caseSensitive: false)
          .firstMatch(rawName);
      if (strengthMatch != null) {
        strengthCtrl.text = strengthMatch.group(1)!.trim();
      }

      // 2. Extract form
      final formMatch = RegExp(
        r'(tablets?|capsules?|syrup|suspension|injections?|ampoules?|vials?|cream|ointment|gel|drops?|inhaler|spray|patch|أقراص|قرص|كبسول|كبسولات|شراب|حقن|أمبول|مرهم|كريم|جل|نقط|بخاخ|لبوس)',
        caseSensitive: false,
      ).firstMatch(rawName);
      if (formMatch != null) {
        final f = formMatch.group(1)!.toLowerCase();
        if (f.contains('tab') || f.contains('قرص') || f.contains('أقراص')) {
          formCtrl.text = 'أقراص';
        } else if (f.contains('cap') || f.contains('كبسول')) {
          formCtrl.text = 'كبسولات';
        } else if (f.contains('syr') || f.contains('susp') || f.contains('شراب')) {
          formCtrl.text = 'شراب';
        } else if (f.contains('inj') || f.contains('amp') || f.contains('vial') || f.contains('حقن')) {
          formCtrl.text = 'حقن';
        } else if (f.contains('cream') || f.contains('كريم')) {
          formCtrl.text = 'كريم';
        } else if (f.contains('oint') || f.contains('مرهم')) {
          formCtrl.text = 'مرهم';
        } else if (f.contains('drop') || f.contains('نقط')) {
          formCtrl.text = 'نقط';
        } else {
          formCtrl.text = formMatch.group(1)!;
        }
      }

      nameCtrl.text = rawName;
      suggestions.value = [];
    }

    final quickDoses = [
      'قرص يومياً',
      'قرص مرتين يومياً',
      'قرص 3 مرات يومياً',
      'عند اللزوم',
      'قبل الأكل',
      'بعد الأكل',
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SectionLabel(
                      existing == null ? 'إضافة دواء' : 'تعديل دواء'),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'اكتب اسم الدواء وسنقترح الاسم المعياري والتركيز والشكل الصيدلي تلقائياً.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: existing == null,
              onChanged: searchSuggestions,
              decoration: InputDecoration(
                labelText: 'اسم الدواء',
                hintText: 'مثلاً: Panadol Extra أو Cataflam أو Concor',
                prefixIcon: const Icon(Icons.medication_rounded, size: 20),
                suffixIcon: isLoadingSuggestions.value
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
            if (suggestions.value.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: AppColors.fieldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: suggestions.value.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = suggestions.value[i];
                    return InkWell(
                      onTap: () => applySuggestion(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                size: 16, color: AppColors.accentBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: strengthCtrl,
                  decoration: const InputDecoration(
                    labelText: 'التركيز',
                    hintText: '500 مجم · 100 وحدة/مل',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: formCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الشكل',
                    hintText: 'أقراص · كبسولات · شراب',
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: doseCtrl,
              decoration: const InputDecoration(
                labelText: 'الجرعة',
                hintText: 'يومياً · قرص كل 12 ساعة',
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: quickDoses.map((qDose) {
                return ActionChip(
                  label: Text(
                    qDose,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: AppColors.fieldBg,
                  side: const BorderSide(color: AppColors.hairline),
                  onPressed: () => doseCtrl.text = qDose,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                try {
                  final client = ref.read(apiClientProvider);
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
                    await client.updateMyMedication(existing!.id, req);
                  }
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(describeApiError(e))),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand900,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(existing == null ? 'إضافة' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
