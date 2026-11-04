import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nawakes_mobile/core/services/on_device_ocr_service.dart';
import 'package:nawakes_mobile/features/search/presentation/camera_scan_sheet.dart';

/// Provider for [ImagePickerService] to support dependency injection and test mocking.
final imagePickerServiceProvider = Provider<ImagePickerService>((ref) {
  return ImagePickerService();
});

/// Service responsible for picking images from the device gallery or camera,
/// and converting them to [CameraScanResult] via on-device OCR.
class ImagePickerService {
  final ImagePicker _picker;

  ImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Pick an image file from the device gallery.
  Future<File?> pickFromGallery({
    double? maxWidth = 2048,
    double? maxHeight = 2048,
    int? imageQuality = 88,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (_) {
      return null;
    }
  }

  /// Pick an image file from the camera directly.
  Future<File?> pickFromCamera({
    double? maxWidth = 2048,
    double? maxHeight = 2048,
    int? imageQuality = 88,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (_) {
      return null;
    }
  }

  /// Runs on-device OCR on the given image file and packages the result into
  /// a [CameraScanResult] ready for multimodal parsing.
  Future<CameraScanResult?> processImage(
    File imageFile, {
    OnDeviceOcrService? ocrService,
  }) async {
    if (!await imageFile.exists()) return null;
    final ocr = ocrService ?? OnDeviceOcrService();
    try {
      final lines = await ocr.extractMedicationNames(imageFile);
      final bytes = await imageFile.readAsBytes();
      return CameraScanResult(
        lines: lines,
        croppedImageBase64: base64Encode(bytes),
        // HUD screen needs the raw image to send to the parser — without
        // these the gallery upload path fails with "invalid/empty image".
        imageFile: imageFile,
        imageBytes: bytes,
      );
    } finally {
      if (ocrService == null) {
        await ocr.dispose();
      }
    }
  }
}
