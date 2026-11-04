import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';

/// Barcode → stock upsert: scans the medicine package barcode (EAN-13 /
/// GS1 DataMatrix with GTIN-14 + expiry), posts it to the scan-barcode
/// endpoint which matches by Barcode/POS SKU/name, pulls the official EDA
/// price, and applies the quantity delta (upserting the item when it exists
/// in the EDA registry but not yet in the pharmacy's stock).
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
    final scanError = useState<String?>(null);
    final lastResult = useState<BarcodeScanResult?>(null);
    final searchCtrl = useTextEditingController();

    Future<void> onCodeDetected(String code, {int quantityDelta = 1}) async {
      final clean = code.trim();
      if (clean.isEmpty || isProcessing.value) return;
      // Same code rescanned → treat as another +1 receipt only after a pause
      if (clean == lastScannedCode.value && quantityDelta == 1 && lastResult.value != null) {
        return;
      }

      lastScannedCode.value = clean;
      isProcessing.value = true;
      scanError.value = null;

      try {
        final result = await ref.read(apiClientProvider).scanBarcode(
              ScanBarcodeRequest(
                rawBarcode: clean,
                quantityDelta: quantityDelta,
              ),
            );
        lastResult.value = result;
        ref.invalidate(pharmacyInventoryControllerProvider);
      } on DioException catch (err) {
        lastResult.value = null;
        if (err.response?.statusCode == 404) {
          scanError.value =
              'الباركود $clean غير معروف — مش موجود في دليل هيئة الدواء ولا مخزونك. ضيف الدواء يدوياً.';
        } else {
          scanError.value = describeApiError(err);
        }
      } catch (err) {
        lastResult.value = null;
        scanError.value = describeApiError(err);
      } finally {
        isProcessing.value = false;
      }
    }

    Future<void> adjustDelta(int delta) async {
      final result = lastResult.value;
      if (result == null) return;
      await onCodeDetected(
        result.extractedGtin.isNotEmpty ? result.extractedGtin : result.item.id,
        quantityDelta: delta,
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مسح باركود الدواء',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'صوّر باركود العلبة — الكمية والسعر والصلاحية تتخزن تلقائياً',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
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

          const SizedBox(height: 8),

          // Scan result card (or error) sits above the viewfinder
          if (lastResult.value != null)
            _ScanResultCard(
              result: lastResult.value!,
              onPlus: () => adjustDelta(1),
              onMinus: () => adjustDelta(-1),
            )
          else if (scanError.value != null)
            _ScanErrorCard(
              message: scanError.value!,
              onManualAdd: () => Navigator.of(context).pop(),
            ),

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

                Container(
                  width: 280,
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

          // Manual entry fallback (also supports typing an unknown barcode)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'أو اكتب الباركود يدوياً (GTIN/EAN)...',
                      prefixIcon: const Icon(Icons.qr_code),
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
                  child: const Text('تخزين', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scan result card ────────────────────────────────────────────────────────

class _ScanResultCard extends StatelessWidget {
  final BarcodeScanResult result;
  final VoidCallback onPlus;
  final VoidCallback onMinus;

  const _ScanResultCard({
    required this.result,
    required this.onPlus,
    required this.onMinus,
  });

  @override
  Widget build(BuildContext context) {
    final item = result.item;
    final expiry = result.extractedExpiryDate ?? item.expiryDate;
    final expiryText = expiry == null
        ? null
        : DateFormat('MM/yyyy').format(expiry);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.successIcon.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded, color: AppColors.successText, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.medicationName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'الكمية: ${item.quantity}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.successText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _metaChip(
                icon: Icons.payments_outlined,
                label: '${item.price.toStringAsFixed(2)} ج.م',
              ),
              if (result.officialEdaPriceEgp != null)
                _metaChip(
                  icon: Icons.verified_outlined,
                  label: 'رسمي: ${result.officialEdaPriceEgp!.toStringAsFixed(2)} ج.م',
                ),
              if (expiryText != null)
                _metaChip(icon: Icons.event_available, label: 'الصلاحية: $expiryText'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: result.matchedFromEdaRegistry
                      ? AppColors.accentBlue.withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.matchedFromEdaRegistry
                      ? 'صنف جديد من دليل هيئة الدواء'
                      : 'صنف موجود — اتحدث',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: result.matchedFromEdaRegistry
                        ? AppColors.accentBlue
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMinus,
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('صرف 1'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerText,
                    side: const BorderSide(color: AppColors.dangerText),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPlus,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('استلام 1'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successText,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Unknown barcode / error card ────────────────────────────────────────────

class _ScanErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onManualAdd;

  const _ScanErrorCard({required this.message, required this.onManualAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warningIcon.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.warningText, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onManualAdd,
            child: const Text(
              'إضافة يدوية',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
