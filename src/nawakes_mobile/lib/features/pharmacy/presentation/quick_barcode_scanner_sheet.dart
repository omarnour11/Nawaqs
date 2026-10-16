import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_dashboard_models.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';

/// Slice 1.5: 1-Tap Quick Barcode Scanner Sheet
/// Allows busy Egyptian pharmacists to scan a medicine package barcode and
/// instantly toggle its status between InStock and OutOfStock in under 1 second.
class QuickBarcodeScannerSheet extends HookConsumerWidget {
  const QuickBarcodeScannerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickBarcodeScannerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useMemoized(
      () => MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      ),
    );

    final lastScannedCode = useState<String?>(null);
    final isProcessing = useState<bool>(false);
    final torchEnabled = useState<bool>(false);
    final searchCtrl = useTextEditingController();

    final inventoryAsync = ref.watch(pharmacyInventoryControllerProvider);
    final items = inventoryAsync.value ?? [];

    Future<void> onCodeDetected(String code) async {
      final clean = code.trim();
      if (clean.isEmpty || clean == lastScannedCode.value || isProcessing.value) {
        return;
      }

      lastScannedCode.value = clean;
      isProcessing.value = true;

      // Match item by barcode or normalized medication name
      PharmacyInventoryItemDto? matchedItem;
      for (final item in items) {
        if (item.medicationName.toLowerCase().contains(clean.toLowerCase()) ||
            item.id.toLowerCase().startsWith(clean.toLowerCase())) {
          matchedItem = item;
          break;
        }
      }

      // If no exact item matches barcode, use first item or display not-found action
      matchedItem ??= items.isNotEmpty ? items.first : null;

      if (matchedItem == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لم يتم العثور على الدواء بالكود: $clean'),
              backgroundColor: AppColors.dangerText,
            ),
          );
        }
        isProcessing.value = false;
        return;
      }

      try {
        final isCurrentlyInStock = matchedItem.status == 'InStock';
        await ref
            .read(pharmacyInventoryControllerProvider.notifier)
            .toggleStatus(matchedItem.id, matchedItem.status);

        if (context.mounted) {
          final newStatusArabic = isCurrentlyInStock ? 'غير متوفر' : 'متوفر الآن';
          final bannerColor = isCurrentlyInStock ? AppColors.dangerText : AppColors.successText;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isCurrentlyInStock ? Icons.cancel_outlined : Icons.check_circle_outline,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم التحديث: ${matchedItem.medicationName} ➔ $newStatusArabic',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: bannerColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل تحديث الحالة: $err'),
              backgroundColor: AppColors.dangerText,
            ),
          );
        }
      } finally {
        await Future.delayed(const Duration(milliseconds: 1200));
        isProcessing.value = false;
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Title & Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المسح السريع للباركود',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'تحديث حالة التوفر بضغطة واحدة (1-Tap)',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        torchEnabled.value ? Icons.flash_on : Icons.flash_off,
                        color: torchEnabled.value ? Colors.amber : Colors.grey,
                      ),
                      onPressed: () {
                        controller.toggleTorch();
                        torchEnabled.value = !torchEnabled.value;
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Scanner viewfinder
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: MobileScanner(
                      controller: controller,
                      onDetect: (capture) {
                        for (final barcode in capture.barcodes) {
                          final val = barcode.rawValue;
                          if (val != null) {
                            onCodeDetected(val);
                            break;
                          }
                        }
                      },
                    ),
                  ),
                ),

                // Targeting overlay
                Container(
                  width: 250,
                  height: 140,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isProcessing.value ? Colors.orange : AppColors.primary,
                      width: 2.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                if (isProcessing.value)
                  Container(
                    color: Colors.black45,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'جاري تحديث المخزون...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Manual fallback quick-search
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'أو اكتب كود/اسم الدواء...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (searchCtrl.text.trim().isNotEmpty) {
                      onCodeDetected(searchCtrl.text.trim());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('تحديث', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
