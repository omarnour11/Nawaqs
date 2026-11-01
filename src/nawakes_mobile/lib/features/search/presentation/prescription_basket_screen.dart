import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/search/presentation/batch_search_results_screen.dart';

class PrescriptionBasketItem {
  String tradeName;
  String? strength;
  String? dosageForm;
  int quantity;
  double confidence;
  String? activeIngredient;

  PrescriptionBasketItem({
    required this.tradeName,
    this.strength,
    this.dosageForm,
    this.quantity = 1,
    this.confidence = 0.90,
    this.activeIngredient,
  });
}

class PrescriptionBasketScreen extends HookConsumerWidget {
  const PrescriptionBasketScreen({
    super.key,
    required this.initialItems,
  });

  final List<PrescriptionBasketItem> initialItems;

  static Future<void> show(
    BuildContext context, {
    required List<PrescriptionBasketItem> items,
  }) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PrescriptionBasketScreen(initialItems: items),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = useState<List<PrescriptionBasketItem>>(
      initialItems.isNotEmpty
          ? List.from(initialItems)
          : [PrescriptionBasketItem(tradeName: 'Concor', strength: '5mg', quantity: 1)],
    );

    void removeItem(int index) {
      final updated = List<PrescriptionBasketItem>.from(items.value);
      updated.removeAt(index);
      items.value = updated;
    }

    void updateQuantity(int index, int delta) {
      final updated = List<PrescriptionBasketItem>.from(items.value);
      final current = updated[index];
      final newQty = (current.quantity + delta).clamp(1, 99);
      current.quantity = newQty;
      items.value = updated;
    }

    void showAddDialog() {
      final nameCtrl = TextEditingController();
      final strengthCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'إضافة دواء للروشتة',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'اسم الدواء (مثلاً Panadol)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.medication_rounded, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: strengthCtrl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'التركيز إن وجد (مثلاً 500mg)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.science_rounded, color: AppColors.accentBlue),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  final str = strengthCtrl.text.trim();
                  final updated = List<PrescriptionBasketItem>.from(items.value);
                  updated.add(PrescriptionBasketItem(
                    tradeName: name,
                    strength: str.isNotEmpty ? str : null,
                    quantity: 1,
                  ));
                  items.value = updated;
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('إضافة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'أدوية الروشتة المفروزة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 26),
            tooltip: 'إضافة دواء يدوي',
            onPressed: showAddDialog,
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // Info Header Banner
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.accentBlue.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تم استخراج ${items.value.length} أدوية من الروشتة',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'تأكد من الأدوية والكميات، ثم اضغط بحث جماعي للبحث في الصيدليات القريبة.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Medication List
            Expanded(
              child: items.value.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medication_liquid_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'تمت إزالة جميع الأدوية',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: showAddDialog,
                            icon: const Icon(Icons.add_rounded, color: Colors.white),
                            label: const Text('إضافة دواء جديد', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: items.value.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (ctx, index) {
                        final item = items.value[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.hairline),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top row: Name + Strength + Delete
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.medication_rounded,
                                        color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.tradeName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textDark,
                                                ),
                                              ),
                                            ),
                                            if (item.confidence > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: item.confidence >= 0.85
                                                      ? Colors.green.withValues(alpha: 0.1)
                                                      : Colors.amber.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      item.confidence >= 0.85
                                                          ? Icons.verified_rounded
                                                          : Icons.help_outline_rounded,
                                                      size: 12,
                                                      color: item.confidence >= 0.85
                                                          ? Colors.green.shade700
                                                          : Colors.amber.shade900,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'دقة ${(item.confidence * 100).toInt()}%',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: item.confidence >= 0.85
                                                            ? Colors.green.shade700
                                                            : Colors.amber.shade900,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (item.activeIngredient != null && item.activeIngredient!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.activeIngredient!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                        if (item.strength != null || item.dosageForm != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              if (item.strength != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.accentBlue.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    item.strength!,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.accentBlue,
                                                    ),
                                                  ),
                                                ),
                                              if (item.strength != null && item.dosageForm != null)
                                                const SizedBox(width: 6),
                                              if (item.dosageForm != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    item.dosageForm!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Remove item button
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded,
                                        color: Colors.redAccent, size: 22),
                                    tooltip: 'إزالة من السلة',
                                    onPressed: () => removeItem(index),
                                  ),
                                ],
                              ),

                              const Divider(height: 20, color: AppColors.hairline),

                              // Bottom row: Quantity counter
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'الكمية المطلوبة:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_rounded, size: 18),
                                          onPressed: () => updateQuantity(index, -1),
                                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                          padding: EdgeInsets.zero,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                                          onPressed: () => updateQuantity(index, 1),
                                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              key: const ValueKey('prescription_basket_batch_search_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              onPressed: items.value.isEmpty
                  ? null
                  : () {
                      final batchItems = items.value
                          .map((e) => BatchSearchItemDto(
                                medication: e.tradeName,
                                quantity: e.quantity,
                              ))
                          .toList();

                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => BatchSearchResultsScreen(items: batchItems),
                      ));
                    },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.saved_search_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'بحث جماعي (${items.value.length} أدوية)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
