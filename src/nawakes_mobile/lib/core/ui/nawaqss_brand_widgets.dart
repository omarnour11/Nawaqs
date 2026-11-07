import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

/// Official Nawaqss Brand Logo rendered in pure vector graphics.
/// Displays the capsule with magnifying glass lens and coral medicine dot.
class NawaqssLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isHorizontal;
  final Color? textColor;

  const NawaqssLogo({
    super.key,
    this.size = 48,
    this.showText = false,
    this.isHorizontal = true,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size * 1.5,
      height: size,
      child: CustomPaint(
        painter: _NawaqssMarkPainter(),
      ),
    );

    if (!showText) return mark;

    final title = Text(
      'نواقص',
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: size * 0.42,
        fontWeight: FontWeight.w900,
        color: textColor ?? NawaqsColors.ink,
        height: 1.1,
      ),
    );

    final subtitle = Text(
      'Nawaqss',
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: size * 0.22,
        fontWeight: FontWeight.w600,
        color: textColor?.withValues(alpha: 0.7) ??
            NawaqsColors.ink.withValues(alpha: 0.6),
        letterSpacing: 0.8,
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

    // Left half: Teal (#0E7C6B)
    final leftRect = Rect.fromLTWH(capLeft, capTop, capW / 2 + 1, capH);
    final leftPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        leftRect,
        topLeft: Radius.circular(capR),
        bottomLeft: Radius.circular(capR),
      ));
    final tealPaint = Paint()..color = NawaqsColors.teal;
    canvas.drawPath(leftPath, tealPaint);

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

    // White capsule outline for crisp contrast
    final capOutline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, h * 0.05);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(capLeft, capTop, capW, capH), Radius.circular(capR)),
      capOutline,
    );

    // Magnifying glass lens centered in the capsule
    final lensCenterX = capLeft + capW / 2;
    final lensCenterY = capTop + capH / 2;
    final lensRadius = capH * 0.44;

    // Lens circle fill (translucent white)
    final lensFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lensCenterX, lensCenterY), lensRadius, lensFill);

    // Lens rim
    final lensRim = Paint()
      ..color = NawaqsColors.tealDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.2, h * 0.07);
    canvas.drawCircle(Offset(lensCenterX, lensCenterY), lensRadius, lensRim);

    // Found medicine dot in lens center: Coral (#FF5A4E)
    final dotPaint = Paint()..color = NawaqsColors.coral;
    canvas.drawCircle(
        Offset(lensCenterX, lensCenterY), lensRadius * 0.42, dotPaint);

    // Handle angling down-right
    final handlePaint = Paint()
      ..color = NawaqsColors.tealDark
      ..strokeWidth = math.max(2.5, h * 0.08)
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Nuqous Mascot ("نقوص") states
enum NuqousMood {
  welcome,
  searching,
  celebrating,
}

/// Official Nuqous Mascot ("نقوص") Vector Widget
class NuqousMascot extends StatelessWidget {
  final double height;
  final NuqousMood mood;

  const NuqousMascot({
    super.key,
    this.height = 100,
    this.mood = NuqousMood.welcome,
  });

  @override
  Widget build(BuildContext context) {
    final width = height * 0.8;
    return SizedBox(
      width: width,
      height: height,
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
    } else {
      // Normal belly: White with Coral dot or light ring
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

    // Pupils (Ink)
    final pupilPaint = Paint()..color = NawaqsColors.ink;
    final pupilOffset = mood == NuqousMood.searching ? 2.0 : 0.0;
    canvas.drawCircle(Offset(eye1X + pupilOffset, eyeY), eyeRadius * 0.45, pupilPaint);
    canvas.drawCircle(Offset(eye2X + pupilOffset, eyeY), eyeRadius * 0.45, pupilPaint);

    // Smile
    final smilePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final smilePath = Path()
      ..moveTo(eye1X + 2, eyeY + eyeRadius + 3)
      ..quadraticBezierTo(
        bellyCenterX,
        eyeY + eyeRadius + 7,
        eye2X - 2,
        eyeY + eyeRadius + 3,
      );
    canvas.drawPath(smilePath, smilePaint);

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

