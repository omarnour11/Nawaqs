import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Maps the on-screen framing guide to a crop on the captured photo.
class PrescriptionFrameCrop {
  PrescriptionFrameCrop._();

  /// Center guide shown in [CameraScanSheet] — only this region is OCR/AI processed.
  static Rect frameRectOnScreen(Size screenSize) {
    final width = screenSize.width * 0.92;
    final height = math.min(screenSize.height * 0.72, 600.0)
        .clamp(300.0, screenSize.height * 0.82);
    return Rect.fromLTWH(
      (screenSize.width - width) / 2,
      (screenSize.height - height) / 2,
      width,
      height,
    );
  }

  /// Crops [source] to the framing rectangle; returns JPEG bytes (quality 88).
  static Future<Uint8List?> cropCaptureToFrame({
    required File source,
    required CameraController controller,
    required Size screenSize,
    required Rect frameRect,
  }) async {
    final raw = await source.readAsBytes();
    final decoded = img.decodeImage(raw);
    if (decoded == null) return null;

    final oriented = _applyExifOrientation(decoded);
    final crop = _mapFrameToImage(
      frameRect: frameRect,
      screenSize: screenSize,
      previewSize: controller.value.previewSize,
      imageWidth: oriented.width,
      imageHeight: oriented.height,
    );

    final cropped = img.copyCrop(
      oriented,
      x: crop.left,
      y: crop.top,
      width: crop.width,
      height: crop.height,
    );

    final resized = cropped.width > 1280
        ? img.copyResize(cropped, width: 1280)
        : cropped;

    return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
  }

  /// Prepares the full captured prescription for high-accuracy OCR scanning:
  /// Applies EXIF orientation rotation and compresses/downsamples cleanly
  /// WITHOUT prematurely cropping out any medications, instructions, or headers.
  static Uint8List prepareFullPrescriptionImage({
    required Uint8List bytes,
    int maxDimension = 1600,
    int quality = 82,
  }) {
    return downsampleAndCompress(
      bytes: bytes,
      maxDimension: maxDimension,
      quality: quality,
    );
  }

  /// Downsamples and compresses image on-device (e.g. max 1600px, quality 80)
  /// to cut upload and processing latency drastically.
  static Uint8List downsampleAndCompress({
    required Uint8List bytes,
    int maxDimension = 1600,
    int quality = 80,
  }) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final oriented = _applyExifOrientation(decoded);
      img.Image resized = oriented;
      if (oriented.width > maxDimension || oriented.height > maxDimension) {
        if (oriented.width >= oriented.height) {
          resized = img.copyResize(oriented, width: maxDimension);
        } else {
          resized = img.copyResize(oriented, height: maxDimension);
        }
      }
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    } catch (_) {
      return bytes;
    }
  }

  /// Single-pass image processing for minimum latency and zero memory thrashing:
  /// Decodes image once and returns both:
  /// - [compressedBytes]: Downsampled full prescription (max 1600px, quality 80)
  /// - [sanitizedCropBytes]: Law No. 151 medication-only crop (omitting doctor header and patient footer)
  static ({Uint8List compressedBytes, Uint8List sanitizedCropBytes}) processPrescriptionAndSanitize({
    required Uint8List bytes,
    int maxDimension = 1600,
    int quality = 80,
    double headerRatio = 0.20,
    double footerRatio = 0.18,
  }) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return (compressedBytes: bytes, sanitizedCropBytes: bytes);
      }
      final oriented = _applyExifOrientation(decoded);

      // 1. Resized full image
      img.Image resized = oriented;
      if (oriented.width > maxDimension || oriented.height > maxDimension) {
        if (oriented.width >= oriented.height) {
          resized = img.copyResize(oriented, width: maxDimension);
        } else {
          resized = img.copyResize(oriented, height: maxDimension);
        }
      }
      final compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));

      // 2. Crop medication body from resized image
      final clampedHeader = headerRatio.clamp(0.10, 0.35);
      final clampedFooter = footerRatio.clamp(0.10, 0.35);

      final cropTop = (resized.height * clampedHeader).round().clamp(0, resized.height - 1);
      final cropBottom = (resized.height * (1.0 - clampedFooter)).round().clamp(cropTop + 1, resized.height);
      final cropHeight = cropBottom - cropTop;

      final cropped = img.copyCrop(
        resized,
        x: 0,
        y: cropTop,
        width: resized.width,
        height: cropHeight,
      );

      final cropBytes = Uint8List.fromList(img.encodeJpg(cropped, quality: quality));
      return (compressedBytes: compressed, sanitizedCropBytes: cropBytes);
    } catch (_) {
      return (compressedBytes: bytes, sanitizedCropBytes: bytes);
    }
  }

  /// Crops out clinic/doctor header (top ~20%) and patient footer (bottom ~18%)
  /// under Egyptian Personal Data Protection Law No. 151 of 2020.
  /// Preserves only the middle medication body for safe pharmacy verification.
  static Uint8List? cropPrescriptionMedicationBody({
    required Uint8List bytes,
    double headerRatio = 0.20,
    double footerRatio = 0.18,
    int maxDimension = 1600,
    int quality = 80,
  }) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final oriented = _applyExifOrientation(decoded);

      final clampedHeader = headerRatio.clamp(0.10, 0.35);
      final clampedFooter = footerRatio.clamp(0.10, 0.35);

      final cropTop = (oriented.height * clampedHeader).round().clamp(0, oriented.height - 1);
      final cropBottom = (oriented.height * (1.0 - clampedFooter)).round().clamp(cropTop + 1, oriented.height);
      final cropHeight = cropBottom - cropTop;

      final cropped = img.copyCrop(
        oriented,
        x: 0,
        y: cropTop,
        width: oriented.width,
        height: cropHeight,
      );

      img.Image resized = cropped;
      if (cropped.width > maxDimension || cropped.height > maxDimension) {
        if (cropped.width >= cropped.height) {
          resized = img.copyResize(cropped, width: maxDimension);
        } else {
          resized = img.copyResize(cropped, height: maxDimension);
        }
      }

      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    } catch (_) {
      return null;
    }
  }

  static img.Image _applyExifOrientation(img.Image image) {
    try {
      switch (image.exif.imageIfd.orientation) {
        case 3:
          return img.copyRotate(image, angle: 180);
        case 6:
          return img.copyRotate(image, angle: 90);
        case 8:
          return img.copyRotate(image, angle: -90);
        default:
          return image;
      }
    } catch (_) {
      return image;
    }
  }

  static ({int left, int top, int width, int height}) _mapFrameToImage({
    required Rect frameRect,
    required Size screenSize,
    required Size? previewSize,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (previewSize != null &&
        previewSize.width > 0 &&
        previewSize.height > 0) {
      final previewW = previewSize.width;
      final previewH = previewSize.height;
      final previewAspect = previewW / previewH;
      final screenAspect = screenSize.width / screenSize.height;

      double scale;
      double offsetX = 0;
      double offsetY = 0;

      if (previewAspect > screenAspect) {
        scale = screenSize.height / previewH;
        offsetX = (previewW * scale - screenSize.width) / 2;
      } else {
        scale = screenSize.width / previewW;
        offsetY = (previewH * scale - screenSize.height) / 2;
      }

      final pxLeft = (frameRect.left + offsetX) / scale;
      final pxTop = (frameRect.top + offsetY) / scale;
      final pxW = frameRect.width / scale;
      final pxH = frameRect.height / scale;

      final imageScaleX = imageWidth / previewW;
      final imageScaleY = imageHeight / previewH;

      var left = (pxLeft * imageScaleX).round();
      var top = (pxTop * imageScaleY).round();
      var width = (pxW * imageScaleX).round();
      var height = (pxH * imageScaleY).round();

      left = left.clamp(0, imageWidth - 1);
      top = top.clamp(0, imageHeight - 1);
      width = width.clamp(1, imageWidth - left);
      height = height.clamp(1, imageHeight - top);

      return (left: left, top: top, width: width, height: height);
    }

    var left = (frameRect.left / screenSize.width * imageWidth).round();
    var top = (frameRect.top / screenSize.height * imageHeight).round();
    var width = (frameRect.width / screenSize.width * imageWidth).round();
    var height = (frameRect.height / screenSize.height * imageHeight).round();

    left = left.clamp(0, imageWidth - 1);
    top = top.clamp(0, imageHeight - 1);
    width = width.clamp(1, imageWidth - left);
    height = height.clamp(1, imageHeight - top);

    return (left: left, top: top, width: width, height: height);
  }
}

/// Dims everything outside [frameRect] so the user aligns the Rx inside the box.
class PrescriptionFrameOverlay extends StatelessWidget {
  const PrescriptionFrameOverlay({super.key, required this.frameRect});

  final Rect frameRect;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _FrameOverlayPainter(frameRect),
        size: Size.infinite,
      ),
    );
  }
}

class _FrameOverlayPainter extends CustomPainter {
  _FrameOverlayPainter(this.frameRect);

  final Rect frameRect;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(frameRect, const Radius.circular(14)),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      dim,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(14)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _FrameOverlayPainter oldDelegate) =>
      oldDelegate.frameRect != frameRect;
}
