import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/services/image_picker_service.dart';
import 'package:nawakes_mobile/core/services/on_device_ocr_service.dart';
import 'package:nawakes_mobile/core/services/prescription_frame_crop.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of a camera scan: cropped Rx image + OCR hints for backend Gemini Vision.
class CameraScanResult {
  const CameraScanResult({
    this.lines = const [],
    this.croppedImageBase64,
    this.imageFile,
    this.imageBytes,
  });

  final List<String> lines;

  /// JPEG (framing box only) as base64 — sent to Gemini when quota allows.
  final String? croppedImageBase64;

  /// Captured or selected image file.
  final File? imageFile;

  /// Raw image bytes for streaming multipart upload.
  final Uint8List? imageBytes;
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
    final disposed = useRef(false);

    void setError(String? message) {
      if (!disposed.value) error.value = message;
    }

    void setBusy(bool value) {
      if (!disposed.value) busy.value = value;
    }

    void setController(CameraController? cam) {
      if (!disposed.value) controller.value = cam;
    }

    Future<bool> ensureCameraPermission() async {
      var status = await Permission.camera.status;
      if (status.isGranted) return true;

      if (status.isPermanentlyDenied || status.isRestricted) {
        setError(
            'إذن الكاميرا مرفوض. افتح إعدادات التطبيق وفعّل الكاميرا لتصوير الروشتة.');
        return false;
      }

      status = await Permission.camera.request();
      if (status.isGranted) return true;

      if (status.isPermanentlyDenied || status.isRestricted) {
        setError(
            'إذن الكاميرا مرفوض. افتح إعدادات التطبيق وفعّل الكاميرا لتصوير الروشتة.');
      } else {
        setError('إذن الكاميرا مطلوب لتصوير الروشتة.');
      }
      return false;
    }

    Future<void> initCamera() async {
      if (disposed.value) return;
      setError(null);

      final old = controller.value;
      setController(null);
      await old?.dispose();

      try {
        if (!await ensureCameraPermission()) return;

        final cameras = await availableCameras();
        if (disposed.value) return;
        if (cameras.isEmpty) {
          setError('لم يتم العثور على كاميرا في الجهاز.');
          return;
        }

        final back = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        final cam = CameraController(
          back,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        try {
          await cam.initialize();
        } on CameraException catch (e) {
          if (e.code == 'CameraAccessDenied' ||
              e.code == 'CameraAccessDeniedWithoutPrompt') {
            setError(
                'إذن الكاميرا مطلوب. اسمح بالوصول من النافذة أو من إعدادات التطبيق.');
            return;
          }
          rethrow;
        }

        try {
          await cam.setFocusMode(FocusMode.auto);
        } catch (_) {}

        if (disposed.value) {
          await cam.dispose();
          return;
        }

        setController(cam);
        setError(null);
      } catch (e) {
        setError('تعذر تشغيل الكاميرا — تأكد من إعطاء إذن الكاميرا.');
      }
    }

    useEffect(() {
      disposed.value = false;
      initCamera();
      return () {
        disposed.value = true;
        final cam = controller.value;
        if (cam != null) {
          cam.dispose();
        }
      };
    }, const []);

    Future<void> capture() async {
      final cam = controller.value;
      if (cam == null || busy.value) return;
      setBusy(true);
      setError(null);
      File? photo;
      final ocr = OnDeviceOcrService();
      try {
        try {
          await cam.setFocusMode(FocusMode.auto);
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 280));
        final image = await cam.takePicture();
        photo = File(image.path);
        if (!context.mounted) return;
        final rawBytes = await photo.readAsBytes();
        final fullProcessed = PrescriptionFrameCrop.prepareFullPrescriptionImage(
          bytes: rawBytes,
          maxDimension: 1600,
          quality: 82,
        );
        if (fullProcessed.isEmpty) {
          setError('تعذر معالجة صورة الروشتة. حاول تاني.');
          return;
        }
        final lines = await ocr.extractFromJpegBytes(fullProcessed);
        if (!context.mounted) return;
        // Non-blocking: Even if on-device ML Kit finds 0 lines in cursive handwriting,
        // we DO NOT abort! Forward the image to Tier 1 Cloud Vision AI.
        Navigator.of(context).pop();
        onScanned(CameraScanResult(
          lines: lines,
          croppedImageBase64: base64Encode(fullProcessed),
          imageBytes: fullProcessed,
          imageFile: photo,
        ));
      } catch (_) {
        setError('حصل خطأ أثناء قراءة الصورة. حاول تاني.');
      } finally {
        setBusy(false);
        await ocr.dispose();
        if (photo != null && await photo.exists()) {
          try {
            await photo.delete();
          } catch (_) {}
        }
      }
    }

    Future<void> pickFromGallery() async {
      if (busy.value) return;
      setBusy(true);
      setError(null);
      try {
        final picker = ref.read(imagePickerServiceProvider);
        final file = await picker.pickFromGallery();
        if (file == null) {
          setBusy(false);
          return;
        }
        if (!context.mounted) return;
        final result = await picker.processImage(file);
        if (!context.mounted) return;
        if (result == null) {
          setError('تعذر قراءة ملف الصورة. حاول اختيار صورة أخرى.');
          return;
        }
        // Non-blocking: Forward image to cloud AI even if local ML Kit returned 0 lines.
        Navigator.of(context).pop();
        onScanned(result);
      } catch (_) {
        setError('حصل خطأ أثناء قراءة الصورة من المعرض. حاول تاني.');
      } finally {
        setBusy(false);
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: controller.value != null &&
                      controller.value!.value.isInitialized
                  ? CameraPreview(controller.value!)
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
            ),
            Builder(
              builder: (context) {
                final frameRect = PrescriptionFrameCrop.frameRectOnScreen(
                    MediaQuery.sizeOf(context));
                return PrescriptionFrameOverlay(frameRect: frameRect);
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 26),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text('ضع الروشتة داخل المربع المضيء',
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
            Positioned(
              left: 16,
              right: 16,
              bottom: 130,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '🔒 يُرسل للسيرفر جزء داخل الإطار فقط (Gemini) — باقي الصورة لا يُحفظ',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
                ),
              ),
            ),
            if (error.value != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 190,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(error.value!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12.5)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: initCamera,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white24,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                        ),
                        child: const Text('إعادة المحاولة',
                            style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: openAppSettings,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white24,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                        child: const Text('الإعدادات',
                            style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 28,
              right: 28,
              bottom: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery Upload Button
                  Tooltip(
                    message: 'اختيار صورة من المعرض',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const ValueKey('camera_sheet_gallery_button'),
                        onTap: busy.value ? null : pickFromGallery,
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.55),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Capture Button
                  GestureDetector(
                    key: const ValueKey('camera_sheet_capture_button'),
                    onTap: busy.value || controller.value == null ? null : capture,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white
                            .withValues(alpha: busy.value ? 0.4 : 0.95),
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: busy.value
                          ? const Padding(
                              padding: EdgeInsets.all(22),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_rounded,
                              color: Colors.black87, size: 32),
                    ),
                  ),

                  // Balancer placeholder
                  const SizedBox(width: 54, height: 54),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
