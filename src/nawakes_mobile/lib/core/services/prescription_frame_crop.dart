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
