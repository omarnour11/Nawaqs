import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/services/on_device_ocr_service.dart';

/// Result of a camera scan: noisy medication lines ready for backend matching.
class CameraScanResult {
  const CameraScanResult({required this.lines});
  final List<String> lines;
}

/// Full-screen camera sheet with rectangular framing guide for medicine boxes
/// and prescriptions. OCR runs entirely on-device; the photo is deleted the
/// moment extraction finishes.
class CameraScanSheet extends HookConsumerWidget {
  const CameraScanSheet({super.key, required this.onScanned});

  final ValueChanged<CameraScanResult> onScanned;

  static Future<void> show(BuildContext context,
      {required ValueChanged<CameraScanResult> onScanned}) {
    return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CameraScanSheet(onScanned: onScanned),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useState<CameraController?>(null);
    final busy = useState(false);
    final error = useState<String?>(null);

    useEffect(() {
      var disposed = false;
      Future<void> init() async {
        try {
          final cameras = await availableCameras();
          if (cameras.isEmpty || disposed) return;
          final back = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );
          final cam = CameraController(back, ResolutionPreset.high,
              enableAudio: false);
          await cam.initialize();
          if (!disposed) {
            controller.value = cam;
          } else {
            await cam.dispose();
          }
        } catch (_) {
          if (!disposed) error.value = 'تعذر تشغيل الكاميرا — تأكد من إعطاء إذن الكاميرا.';
        }
      }

      init();
      return () {
        disposed = true;
        controller.value?.dispose();
      };
    }, const []);

    Future<void> capture() async {
      final cam = controller.value;
      if (cam == null || busy.value) return;
      busy.value = true;
      error.value = null;
      try {
        final image = await cam.takePicture();
        final ocr = OnDeviceOcrService();
        final lines = await ocr.extractMedicationNames(File(image.path));
        if (context.mounted) {
          Navigator.of(context).pop();
          onScanned(CameraScanResult(lines: lines));
        }
      } catch (_) {
        error.value = 'حصل خطأ أثناء قراءة الصورة. حاول تاني.';
      } finally {
        busy.value = false;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            Positioned.fill(
              child: controller.value != null && controller.value!.value.isInitialized
                  ? CameraPreview(controller.value!)
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
            ),

            // Framing guide
            Center(
              child: IgnorePointer(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.82,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            // Top bar: close + title
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text('صوّر العلبة أو الروشتة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // Privacy note
            Positioned(
              left: 16,
              right: 16,
              bottom: 130,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '🔒 الصورة لا تُرفع على أي سيرفر — المعالجة على جهازك فقط',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
                ),
              ),
            ),

            // Error banner
            if (error.value != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 190,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(error.value!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                ),
              ),

            // Capture button
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Center(
                child: GestureDetector(
                  onTap: busy.value ? null : capture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: busy.value ? 0.4 : 0.95),
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: busy.value
                        ? const Padding(
                            padding: EdgeInsets.all(22),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt_rounded,
                            color: Colors.black87, size: 30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
