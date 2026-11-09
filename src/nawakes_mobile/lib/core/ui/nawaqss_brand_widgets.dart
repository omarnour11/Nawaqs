import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

enum NawaqssLogoVariant {
  onLight,
  onTeal,
  auto,
}

/// Official Nawaqss Brand Logo rendered in pure vector graphics (Brand Kit Pages 1, 3, 4, 14).
/// Displays the capsule with magnifying glass lens and coral medicine dot.
class NawaqssLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isHorizontal;
  final Color? textColor;
  final NawaqssLogoVariant variant;
  final bool? onDark;

  const NawaqssLogo({
    super.key,
    this.size = 48,
    this.showText = false,
    this.isHorizontal = true,
    this.textColor,
    this.variant = NawaqssLogoVariant.auto,
    this.onDark,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkBg = onDark ??
        (variant == NawaqssLogoVariant.onTeal ||
            (variant == NawaqssLogoVariant.auto &&
                Theme.of(context).brightness == Brightness.dark));

    final mark = SizedBox(
      width: size * 1.5,
      height: size,
      child: CustomPaint(
        painter: _NawaqssMarkPainter(onDark: isDarkBg),
      ),
    );

    if (!showText) return mark;

    final title = Text(
      'نواقص',
      style: TextStyle(
        fontFamily: 'Lalezar',
        fontSize: size * 0.46,
        fontWeight: FontWeight.w400,
        color: textColor ?? (isDarkBg ? Colors.white : AppColors.textPrimary),
        height: 1.05,
      ),
    );

    final subtitle = Text(
      'Nawaqss',
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: size * 0.20,
        fontWeight: FontWeight.w700,
        color: textColor?.withValues(alpha: 0.85) ??
            (isDarkBg ? NawaqsColors.mint : NawaqsColors.teal),
        letterSpacing: 1.2,
      ),
    );

    if (isHorizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          mark,
          SizedBox(width: size * 0.2),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, subtitle],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        SizedBox(height: size * 0.15),
        title,
        subtitle,
      ],
    );
  }
}

class _NawaqssMarkPainter extends CustomPainter {
  final bool onDark;

  const _NawaqssMarkPainter({this.onDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Capsule dimensions
    final capH = h * 0.65;
    final capW = w * 0.82;
    final capLeft = (w - capW) / 2;
    final capTop = (h - capH) / 2;
    final capR = capH / 2;

    // Left half: White on Teal/Dark, Teal (#0E7C6B) on Light
    final leftRect = Rect.fromLTWH(capLeft, capTop, capW / 2 + 1, capH);
    final leftPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        leftRect,
        topLeft: Radius.circular(capR),
        bottomLeft: Radius.circular(capR),
      ));
    final leftPaint = Paint()..color = onDark ? Colors.white : NawaqsColors.teal;
    canvas.drawPath(leftPath, leftPaint);

    // Right half: Coral (#FF5A4E)
    final rightRect = Rect.fromLTWH(capLeft + capW / 2 - 1, capTop, capW / 2 + 1, capH);
    final rightPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        rightRect,
        topRight: Radius.circular(capR),
        bottomRight: Radius.circular(capR),
      ));
    final coralPaint = Paint()..color = NawaqsColors.coral;
    canvas.drawPath(rightPath, coralPaint);

    // Subtle curved glare reflection line on left side
    final glarePen = Paint()
      ..color = Colors.white.withValues(alpha: onDark ? 0.6 : 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, h * 0.04)
      ..strokeCap = StrokeCap.round;

    final leftArcRect = Rect.fromLTWH(capLeft + 4, capTop + 4, capH - 8, capH - 8);
    canvas.drawArc(leftArcRect, math.pi * 0.85, math.pi * 0.40, false, glarePen);

    final rightArcRect = Rect.fromLTWH(capLeft + capW - capH + 4, capTop + 4, capH - 8, capH - 8);
    canvas.drawArc(rightArcRect, math.pi * 1.65, math.pi * 0.40, false, glarePen);

    // Magnifying glass lens centered in the capsule
    final lensCenterX = capLeft + capW / 2;
    final lensCenterY = capTop + capH / 2;
    final lensRadius = capH * 0.44;

    // Lens circle fill (translucent white or teal behind)
    final lensFill = Paint()
      ..color = onDark ? NawaqsColors.tealDark.withValues(alpha: 0.8) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lensCenterX, lensCenterY), lensRadius, lensFill);

    // Lens rim (White on Dark, Teal on Light)
    final lensRim = Paint()
      ..color = onDark ? Colors.white : NawaqsColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.4, h * 0.075);
    canvas.drawCircle(Offset(lensCenterX, lensCenterY), lensRadius, lensRim);

    // Found medicine dot in lens center: Coral (#FF5A4E)
    final dotPaint = Paint()..color = NawaqsColors.coral;
    canvas.drawCircle(
        Offset(lensCenterX, lensCenterY), lensRadius * 0.42, dotPaint);

    // Handle angling down-right at 45 degrees
    final handlePaint = Paint()
      ..color = onDark ? Colors.white : NawaqsColors.teal
      ..strokeWidth = math.max(2.6, h * 0.085)
      ..strokeCap = StrokeCap.round;

    final angle = math.pi / 4; // 45 degrees
    final p1 = Offset(
      lensCenterX + lensRadius * math.cos(angle),
      lensCenterY + lensRadius * math.sin(angle),
    );
    final p2 = Offset(
      lensCenterX + (lensRadius + h * 0.35) * math.cos(angle),
      lensCenterY + (lensRadius + h * 0.35) * math.sin(angle),
    );
    canvas.drawLine(p1, p2, handlePaint);
  }

  @override
  bool shouldRepaint(covariant _NawaqssMarkPainter oldDelegate) =>
      oldDelegate.onDark != onDark;
}

/// Nuqous Mascot ("نقوص") states
enum NuqousMood {
  welcome,
  searching,
  celebrating,
  worried,
}

/// Official Nuqous Mascot ("نقوص") Vector Widget
class NuqousMascot extends StatelessWidget {
  final double height;
  final NuqousMood mood;

  const NuqousMascot({
    super.key,
    this.height = 110,
    this.mood = NuqousMood.welcome,
  });

  const NuqousMascot.welcome({super.key, this.height = 110})
      : mood = NuqousMood.welcome;

  const NuqousMascot.searching({super.key, this.height = 110})
      : mood = NuqousMood.searching;

  const NuqousMascot.celebrating({super.key, this.height = 110})
      : mood = NuqousMood.celebrating;

  const NuqousMascot.worried({super.key, this.height = 110})
      : mood = NuqousMood.worried;

  @override
  Widget build(BuildContext context) {
    final safeHeight = (height < 16.0 || height.isNaN || height.isInfinite)
        ? 16.0
        : height;
    final width = safeHeight * 0.8;
    return SizedBox(
      width: width,
      height: safeHeight,
      child: CustomPaint(
        painter: _NuqousPainter(mood: mood),
      ),
    );
  }
}

class _NuqousPainter extends CustomPainter {
  final NuqousMood mood;

  _NuqousPainter({required this.mood});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (w < 12.0 || h < 16.0) return;

    // Body capsule
    final capH = h * 0.72;
    final capW = w * 0.68;
    final capLeft = (w - capW) / 2;
    final capTop = h * 0.12;
    final capR = capW / 2;

    // Top half: Teal (#0E7C6B)
    final topRect = Rect.fromLTWH(capLeft, capTop, capW, capH / 2);
    final topPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        topRect,
        topLeft: Radius.circular(capR),
        topRight: Radius.circular(capR),
      ));
    canvas.drawPath(topPath, Paint()..color = NawaqsColors.teal);

    // Bottom half: Coral (#FF5A4E)
    final botRect = Rect.fromLTWH(capLeft, capTop + capH / 2, capW, capH / 2);
    final botPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        botRect,
        bottomLeft: Radius.circular(capR),
        bottomRight: Radius.circular(capR),
      ));
    canvas.drawPath(botPath, Paint()..color = NawaqsColors.coral);

    // Mascot legs
    final legPaint = Paint()
      ..color = NawaqsColors.ink
      ..strokeWidth = math.max(3.0, w * 0.06)
      ..strokeCap = StrokeCap.round;

    final leg1X = capLeft + capW * 0.32;
    final leg2X = capLeft + capW * 0.68;
    final legStartY = capTop + capH;
    final legEndY = h * 0.94;

    canvas.drawLine(Offset(leg1X, legStartY - 2), Offset(leg1X, legEndY), legPaint);
    canvas.drawLine(Offset(leg2X, legStartY - 2), Offset(leg2X, legEndY), legPaint);

    // Feet
    final footPaint = Paint()
      ..color = NawaqsColors.ink
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(leg1X - w * 0.08, legEndY - 2, w * 0.12, h * 0.05),
        const Radius.circular(3),
      ),
      footPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(leg2X - w * 0.04, legEndY - 2, w * 0.12, h * 0.05),
        const Radius.circular(3),
      ),
      footPaint,
    );

    // Circular belly indicator
    final bellyCenterX = capLeft + capW / 2;
    final bellyCenterY = capTop + capH * 0.72;
    final bellyRadius = capW * 0.18;

    if (mood == NuqousMood.celebrating) {
      // Celebrating belly: Glowing Yellow (#FFD23F)
      canvas.drawCircle(
        Offset(bellyCenterX, bellyCenterY),
        bellyRadius * 1.25,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(bellyCenterX, bellyCenterY),
        bellyRadius,
        Paint()..color = NawaqsColors.stickerYellow,
      );
    } else if (mood == NuqousMood.worried) {
      // Worried belly: Empty tummy hole (Brand Kit page 7: "الفتحة فاضية")
      final holeStroke = math.max(2.0, w * 0.035);
      canvas.drawCircle(
        Offset(bellyCenterX, bellyCenterY),
        bellyRadius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = holeStroke,
      );
      canvas.drawCircle(
        Offset(bellyCenterX, bellyCenterY),
        bellyRadius * 0.85,
        Paint()
          ..color = NawaqsColors.ink.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
    } else {
      // Normal / Welcome belly: White with Coral dot or light ring
      canvas.drawCircle(
        Offset(bellyCenterX, bellyCenterY),
        bellyRadius,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(bellyCenterX, bellyCenterY),
        bellyRadius * 0.45,
        Paint()..color = NawaqsColors.coral,
      );
    }

    // Eyes / Glasses on Teal Head
    final eyeRadius = capW * 0.14;
    final eyeY = capTop + capH * 0.26;
    final eye1X = capLeft + capW * 0.35;
    final eye2X = capLeft + capW * 0.65;

    // Glasses rim (white)
    final eyeWhite = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(eye1X, eyeY), eyeRadius, eyeWhite);
    canvas.drawCircle(Offset(eye2X, eyeY), eyeRadius, eyeWhite);

    // Pupils (Ink) - in searching mood, look towards magnifying glass on the left (-X)
    final pupilPaint = Paint()..color = NawaqsColors.ink;
    final pupilOffset = mood == NuqousMood.searching ? -eyeRadius * 0.35 : 0.0;
    canvas.drawCircle(Offset(eye1X + pupilOffset, eyeY), eyeRadius * 0.45, pupilPaint);
    canvas.drawCircle(Offset(eye2X + pupilOffset, eyeY), eyeRadius * 0.45, pupilPaint);

    // Worried Eyebrows
    if (mood == NuqousMood.worried) {
      final browPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, w * 0.035)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(eye1X - eyeRadius * 0.7, eyeY - eyeRadius * 0.9),
        Offset(eye1X + eyeRadius * 0.6, eyeY - eyeRadius * 1.3),
        browPaint,
      );
      canvas.drawLine(
        Offset(eye2X + eyeRadius * 0.7, eyeY - eyeRadius * 0.9),
        Offset(eye2X - eyeRadius * 0.6, eyeY - eyeRadius * 1.3),
        browPaint,
      );
    }

    // Mouth / Expression
    final mouthPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, w * 0.03)
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path();
    final mouthInset = math.max(0.5, capW * 0.05);
    final mouthStartX = eye1X + mouthInset;
    final mouthEndX = eye2X - mouthInset;

    if (mood == NuqousMood.worried) {
      // Worried / sad expression (downturned)
      final mouthBaseY = eyeY + eyeRadius + math.max(1.5, capH * 0.06);
      final mouthCurveY = eyeY + eyeRadius + math.max(1.0, capH * 0.02);
      mouthPath
        ..moveTo(mouthStartX, mouthBaseY)
        ..quadraticBezierTo(
          bellyCenterX,
          mouthCurveY,
          mouthEndX,
          mouthBaseY,
        );
    } else {
      // Friendly smile
      final mouthBaseY = eyeY + eyeRadius + math.max(1.5, capH * 0.03);
      final mouthCurveY = eyeY + eyeRadius + math.max(2.0, capH * 0.08);
      mouthPath
        ..moveTo(mouthStartX, mouthBaseY)
        ..quadraticBezierTo(
          bellyCenterX,
          mouthCurveY,
          mouthEndX,
          mouthBaseY,
        );
    }
    canvas.drawPath(mouthPath, mouthPaint);

    // Arms
    final armPaint = Paint()
      ..color = NawaqsColors.ink
      ..strokeWidth = math.max(2.5, w * 0.05)
      ..strokeCap = StrokeCap.round;

    if (mood == NuqousMood.celebrating) {
      // Arms raised high in celebration
      canvas.drawLine(
        Offset(capLeft + 2, capTop + capH * 0.48),
        Offset(capLeft - w * 0.12, capTop + capH * 0.28),
        armPaint,
      );
      canvas.drawLine(
        Offset(capLeft + capW - 2, capTop + capH * 0.48),
        Offset(capLeft + capW + w * 0.12, capTop + capH * 0.28),
        armPaint,
      );
    } else if (mood == NuqousMood.searching) {
      // Left arm holds magnifying glass within [0..w] bounds
      final lensRadius = w * 0.07;
      final lensCenterX = math.max(lensRadius + 1.5, capLeft - w * 0.06);
      final lensCenterY = capTop + capH * 0.35;
      final lensCenter = Offset(lensCenterX, lensCenterY);

      canvas.drawLine(
        Offset(capLeft + 2, capTop + capH * 0.48),
        Offset(lensCenter.dx + lensRadius * 0.5, lensCenter.dy + lensRadius * 0.5),
        armPaint,
      );
      // Mini lens (strictly within canvas bounds)
      canvas.drawCircle(
        lensCenter,
        lensRadius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.8, w * 0.03),
      );
      // Right arm down
      canvas.drawLine(
        Offset(capLeft + capW - 2, capTop + capH * 0.48),
        Offset(capLeft + capW + w * 0.1, capTop + capH * 0.62),
        armPaint,
      );
    } else {
      // Arms down/forward
      canvas.drawLine(
        Offset(capLeft + 2, capTop + capH * 0.48),
        Offset(capLeft - w * 0.1, capTop + capH * 0.62),
        armPaint,
      );
      canvas.drawLine(
        Offset(capLeft + capW - 2, capTop + capH * 0.48),
        Offset(capLeft + capW + w * 0.1, capTop + capH * 0.62),
        armPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NuqousPainter oldDelegate) =>
      oldDelegate.mood != mood;
}

// ============================================================================
// BRAND KIT v3 STICKERS
// ============================================================================

/// Found Medicine Sticker ("لقيناه!")
class NawaqssFoundSticker extends StatelessWidget {
  final String label;
  final double? fontSize;
  final bool enableTilt;
  final VoidCallback? onTap;

  const NawaqssFoundSticker({
    super.key,
    this.label = 'لقيناه!',
    this.fontSize,
    this.enableTilt = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label.trim().isEmpty ? 'لقيناه!' : label.trim();
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NawaqsColors.mint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NawaqsColors.mintDeep, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: NawaqsColors.teal,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              effectiveLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: fontSize ?? 12,
                fontWeight: FontWeight.w800,
                color: NawaqsColors.tealDark,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );

    if (enableTilt) {
      content = Transform.rotate(angle: -0.04, child: content);
    }
    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

/// Shortage Alert Sticker ("ناقص!")
class NawaqssShortageSticker extends StatelessWidget {
  final String label;
  final double? fontSize;
  final bool enableTilt;
  final VoidCallback? onTap;

  const NawaqssShortageSticker({
    super.key,
    this.label = 'ناقص!',
    this.fontSize,
    this.enableTilt = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label.trim().isEmpty ? 'ناقص!' : label.trim();
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NawaqsColors.coralSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NawaqsColors.coral,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: NawaqsColors.coral,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              effectiveLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: fontSize ?? 12,
                fontWeight: FontWeight.w800,
                color: NawaqsColors.coral,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );

    if (enableTilt) {
      content = Transform.rotate(angle: 0.04, child: content);
    }
    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

/// Law 151 Data Privacy Sticker ("الاسم والرقم اتحجبوا 🔒")
class NawaqssPrivacySticker extends StatelessWidget {
  final String label;
  final double? fontSize;
  final bool enableTilt;
  final VoidCallback? onTap;

  const NawaqssPrivacySticker({
    super.key,
    this.label = 'الاسم والرقم اتحجبوا 🔒',
    this.fontSize,
    this.enableTilt = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabel =
        label.trim().isEmpty ? 'الاسم والرقم اتحجبوا 🔒' : label.trim();
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_rounded,
            size: 13,
            color: Color(0xFF14532D),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              effectiveLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: fontSize ?? 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF14532D),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );

    if (enableTilt) {
      content = Transform.rotate(angle: -0.03, child: content);
    }
    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

/// Single Medication Rapid Match Sticker ("دوا واحد بس")
class NawaqssSingleMedSticker extends StatelessWidget {
  final String label;
  final double? fontSize;
  final bool enableTilt;
  final VoidCallback? onTap;

  const NawaqssSingleMedSticker({
    super.key,
    this.label = 'دوا واحد بس',
    this.fontSize,
    this.enableTilt = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label.trim().isEmpty ? 'دوا واحد بس' : label.trim();
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NawaqsColors.stickerYellow.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NawaqsColors.stickerYellow, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.medication_outlined,
            size: 14,
            color: Color(0xFF8C6500),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              effectiveLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: fontSize ?? 11.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF8C6500),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );

    if (enableTilt) {
      content = Transform.rotate(angle: 0.03, child: content);
    }
    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

/// Dynamic Counter Sticker Badge (e.g. "3 صيدليات", "2")
class NawaqssCounterSticker extends StatelessWidget {
  final int count;
  final String? suffix;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final bool hideZero;

  const NawaqssCounterSticker({
    super.key,
    required this.count,
    this.suffix,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.hideZero = false,
  });

  @override
  Widget build(BuildContext context) {
    if (hideZero && count <= 0) {
      return const SizedBox.shrink();
    }

    final safeCount = count < 0 ? 0 : count;
    final countText = safeCount > 99 ? '99+' : safeCount.toString();
    final hasSuffix = suffix != null && suffix!.trim().isNotEmpty;
    final text = hasSuffix ? '$countText ${suffix!.trim()}' : countText;

    return Container(
      constraints: BoxConstraints(
        minWidth: hasSuffix ? 0 : 20,
        minHeight: 20,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: hasSuffix ? 8 : 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? NawaqsColors.teal,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: fontSize ?? 11,
          fontWeight: FontWeight.w900,
          color: textColor ?? Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Official Pill Status Badge (متاح / قريب / ناقص)
class NawaqssStatusPill extends StatelessWidget {
  final String status; // 'available' | 'nearby' | 'missing' or Arabic strings

  const NawaqssStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.trim().toLowerCase();
    final isAvailable = s == 'متاح' || s == 'available' || s == 'in_stock';
    final isNearby = s == 'قريب' || s == 'nearby' || s == 'limited';

    final Color bgColor;
    final Color textColor;
    final String label;

    if (isAvailable) {
      bgColor = NawaqsColors.mint;
      textColor = NawaqsColors.tealDark;
      label = 'متاح';
    } else if (isNearby) {
      bgColor = NawaqsColors.stickerYellow.withValues(alpha: 0.25);
      textColor = const Color(0xFF8C6500);
      label = 'قريب';
    } else {
      bgColor = NawaqsColors.coralSoft;
      textColor = NawaqsColors.coral;
      label = 'ناقص';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: textColor.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

/// Mandatory Clinical Disclaimer Banner (صفحة 15 & 16)
class NawaqssClinicalDisclaimer extends StatelessWidget {
  const NawaqssClinicalDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NawaqsColors.mint.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NawaqsColors.mintDeep.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 16,
            color: NawaqsColors.teal,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'القرار للدكتور والصيدلي. اسأل صيدلي قبل ما تبدّل.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: NawaqsColors.tealDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

