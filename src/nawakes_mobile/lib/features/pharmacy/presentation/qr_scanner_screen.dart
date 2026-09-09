import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';

/// Check-in — الصيدلي يمسح QR التصريح بتاع المريض للتحقق وإتمام الاستلام.
/// Works on mobile (camera). Falls back to manual code entry everywhere.
class QrScannerScreen extends HookConsumerWidget {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useMemoized(
        () => MobileScannerController(detectionSpeed: DetectionSpeed.normal));
    final processedCode = useState<String?>(null);
    final manualCtrl = useTextEditingController();
    final manualBusy = useState(false);
    final torchOn = useState(false);

    Future<void> handleCode(String code) async {
      final clean = code.trim().toUpperCase();
      if (processedCode.value == clean) return; // debounce same scan
      processedCode.value = clean;

      // Look up the reservation in the pharmacy's active list by code
      final orders = ref.read(pharmacyReservationsControllerProvider).value ?? [];
      final match = orders.where((r) => r.reservationCode.toUpperCase() == clean).toList();

      if (!context.mounted) return;

      if (match.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('مفيش حجز بكود "$clean" في الطلبات النشطة بتاعتك.'),
              backgroundColor: AppColors.dangerText),
        );
        return;
      }

      final r = match.first;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ScanResultSheet(reservationId: r.id, code: r.reservationCode),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code != null && processedCode.value == null) {
                handleCode(code);
              }
            },
          ),

          // Top bar
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    await controller.toggleTorch();
                    torchOn.value = !torchOn.value;
                  },
                  icon: Icon(torchOn.value ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: Colors.white),
                ),
              ],
            ),
          ),

          // Scan window overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),

          // Hint + manual entry
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('وجّه الكاميرا على QR التصريح',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('أو ادخل الكود يدويًا لو الكاميرا مش شغالة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: manualCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'NWQ-XXXXXX',
                      ),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) handleCode(v);
                      },
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: manualBusy.value
                          ? null
                          : () {
                              if (manualCtrl.text.trim().isNotEmpty) {
                                handleCode(manualCtrl.text);
                              }
                            },
                      style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13))),
                      child: const Text('تحقق من الكود'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet shown after a successful scan — offers Ready / Complete.
class _ScanResultSheet extends HookConsumerWidget {
  final String reservationId;
  final String code;

  const _ScanResultSheet({required this.reservationId, required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState<String?>(null); // 'ready' | 'complete' | null

    Future<void> act(String action) async {
      busy.value = action;
      try {
        final client = ref.read(apiClientProvider);
        if (action == 'ready') {
          await client.markReservationReady(reservationId);
        } else {
          await client.completePharmacyReservation(reservationId);
        }
        ref.invalidate(pharmacyReservationsControllerProvider);
        ref.invalidate(pharmacyInventoryControllerProvider);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(action == 'ready'
                    ? 'الحجز اتعلّم "جاهز للاستلام".'
                    : 'الاستلام اتم بنجاح.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      } finally {
        busy.value = null;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20, right: 20, top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('تم التحقق'),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppColors.brand900)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy.value != null
                      ? null
                      : () => act('ready'),
                  icon: busy.value == 'ready'
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.task_outlined, size: 17),
                  label: const Text('جاهز'),
                  style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      busy.value == null ? () => act('complete') : null,
                  icon: busy.value == 'complete'
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 17),
                  label: const Text('اتسلم'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.successText,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
