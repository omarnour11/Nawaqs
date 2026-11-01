import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart'
    show describeApiError;
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';

class AddInventoryScreen extends HookConsumerWidget {
  const AddInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameCtrl = useTextEditingController();
    final strengthCtrl = useTextEditingController();
    final priceCtrl = useTextEditingController();
    final quantityCtrl = useTextEditingController(text: '10');
    final selectedDosageForm = useState<String?>(null);
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final isSubmitting = useState(false);

    final suggestions = useState<List<String>>([]);
    final isSuggesting = useState(false);
    final debounceTimer = useRef<Timer?>(null);

    double? parseArabicDouble(String? raw) {
      if (raw == null) return null;
      var s = raw.trim();
      if (s.isEmpty) return null;
      const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      for (int i = 0; i < arabicDigits.length; i++) {
        s = s.replaceAll(arabicDigits[i], '$i');
      }
      s = s.replaceAll('،', '.').replaceAll(',', '.');
      return double.tryParse(s);
    }

    void onNameChanged(String val) {
      debounceTimer.value?.cancel();
      final q = val.trim();
      if (q.length < 2) {
        suggestions.value = [];
        isSuggesting.value = false;
        return;
      }
      isSuggesting.value = true;
      debounceTimer.value = Timer(const Duration(milliseconds: 300), () async {
        try {
          final res = await ref.read(apiClientProvider).suggestMedications(q);
          suggestions.value = res;
        } catch (_) {
          suggestions.value = [];
        } finally {
          isSuggesting.value = false;
        }
      });
    }

    void applySuggestion(String suggested) {
      nameCtrl.text = suggested;
      suggestions.value = [];
    }

    Future<void> submit() async {
      if (!formKey.currentState!.validate()) return;
      isSubmitting.value = true;
      try {
        final price = parseArabicDouble(priceCtrl.text) ?? 0.0;
        final qty = int.tryParse(quantityCtrl.text.trim()) ?? 10;
        final str = strengthCtrl.text.trim();
        await ref
            .read(pharmacyInventoryControllerProvider.notifier)
            .addItem(
              nameCtrl.text.trim(),
              price,
              quantity: qty,
              dosageForm: selectedDosageForm.value,
              strength: str.isNotEmpty ? str : null,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('الدواء اتضاف للمخزون.'),
              ]),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(describeApiError(e)),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة دواء'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.medication_rounded, color: Colors.white, size: 36),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('دواء جديد',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          SizedBox(height: 4),
                          Text('هيتضاف كمتاح بشكل افتراضي',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Medication name
              _FieldLabel(label: 'اسم الدواء', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                onChanged: onNameChanged,
                decoration: InputDecoration(
                  hintText: 'مثلاً: باراسيتامول 500 مجم',
                  prefixIcon: const Icon(Icons.medication_outlined),
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
                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),

              if (suggestions.value.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlueBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accentBlue),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'هل تقصد من قاعدة بيانات الأدوية الرسمية؟',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: suggestions.value.take(5).map((s) {
                          return ActionChip(
                            avatar: const Icon(Icons.check_circle_outline, size: 14, color: AppColors.brand700),
                            label: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            onPressed: () => applySuggestion(s),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Dosage form (الشكل الدوائي) - Optional
              const _FieldLabel(label: 'الشكل الدوائي (اختياري)', required: false),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'حبوب / أقراص',
                  'كبسولات',
                  'شراب / زجاجة',
                  'مرهم / كريم',
                  'حقن / أمبولات',
                  'قطرة',
                  'بخاخ',
                  'جل / دهان',
                  'فوار',
                ].map((form) {
                  final isSel = selectedDosageForm.value == form;
                  return ChoiceChip(
                    label: Text(form),
                    selected: isSel,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSel ? Colors.white : AppColors.textDark,
                    ),
                    side: BorderSide(
                      color: isSel ? AppColors.primary : AppColors.hairline,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (val) {
                      selectedDosageForm.value = val ? form : null;
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Strength (تركيز الدواء) - Optional
              const _FieldLabel(label: 'التركيز (اختياري)', required: false),
              const SizedBox(height: 8),
              TextFormField(
                controller: strengthCtrl,
                decoration: const InputDecoration(
                  hintText: 'مثلاً: 500 مجم أو 1 جم أو 10%',
                  prefixIcon: Icon(Icons.science_outlined),
                ),
              ),

              const SizedBox(height: 24),

              // Quantity
              _FieldLabel(label: 'الكمية المتوفرة بالمخزون', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'مثلاً: 10',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  suffixText: 'علبة / وحدة  ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'مطلوب';
                  final parsed = int.tryParse(v.trim());
                  if (parsed == null || parsed < 0) return 'كمية غير صحيحة';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Price
              _FieldLabel(label: 'السعر (ج.م)', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  prefixText: 'ج.م  ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final parsed = parseArabicDouble(v);
                  if (parsed == null || parsed < 0) return 'سعر غير صحيح';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Info note
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.accentDark, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'الدواء هيتسجل كمتاح. إذا كان مسجلاً مسبقاً بنفس الاسم والنوع والسعر سيتم دمج الكمية تلقائياً بالمخزون.',
                        style: TextStyle(fontSize: 12, color: AppColors.accentDark, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Submit button
              ElevatedButton.icon(
                onPressed: isSubmitting.value ? null : submit,
                icon: isSubmitting.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_circle_outline_rounded),
                label: Text(isSubmitting.value ? 'جارٍ الإضافة…' : 'حفظ في المخزون'),
              ),

              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
        ),
        if (required)
          const Text(' *', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
