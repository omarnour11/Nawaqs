import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/services/on_device_ocr_service.dart';
import 'package:nawakes_mobile/core/services/prescription_frame_crop.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_basket_screen.dart';

/// Full-screen high-tech Scanner HUD that animates a live laser sweep and radar
/// over the patient's captured prescription image while Gemini Vision AI parses
/// all medications in the background.
class PrescriptionScannerHudScreen extends ConsumerStatefulWidget {
  final File? imageFile;
  final Uint8List? imageBytes;
  final String? ocrHintText;

  const PrescriptionScannerHudScreen({
    super.key,
    this.imageFile,
    this.imageBytes,
    this.ocrHintText,
  });

  static Future<void> start(
    BuildContext context, {
    File? imageFile,
    Uint8List? imageBytes,
    String? ocrHintText,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrescriptionScannerHudScreen(
          imageFile: imageFile,
          imageBytes: imageBytes,
          ocrHintText: ocrHintText,
        ),
      ),
    );
  }

  @override
  ConsumerState<PrescriptionScannerHudScreen> createState() =>
      _PrescriptionScannerHudScreenState();
}

class _PrescriptionScannerHudScreenState
    extends ConsumerState<PrescriptionScannerHudScreen>
    with TickerProviderStateMixin {
  late final AnimationController _laserCtrl;
  late final Animation<double> _laserAnim;
  late final AnimationController _radarCtrl;

  int _currentStage = 0;
  Timer? _stageTimer;
  bool _isFinished = false;
  String? _errorMessage;

  final List<String> _stages = [
    'جاري فحص وضوح صورة الروشتة...',
    'فك خط يد الطبيب والأرقام الطبية...',
    'استخراج كافة الأدوية ومطابقة الدليل الدوائي...',
    'تجهيز سلة الروشتة الذكية...',
  ];

  final List<String> _hudMicrocopy = [
    'جاري تثبيت زوايا الروشتة...',
    'المستشعر الذكي يقرأ خط الطبيب...',
    'تحليل مكونات الروشتة ومطابقة الدليل الدوائي...',
    'تم رصد الأدوية بنجاح ✓',
  ];

  @override
  void initState() {
    super.initState();
    _laserCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnim = CurvedAnimation(parent: _laserCtrl, curve: Curves.easeInOut);

    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _stageTimer = Timer.periodic(const Duration(milliseconds: 950), (timer) {
      if (!mounted) return;
      if (_currentStage < _stages.length - 1) {
        setState(() => _currentStage++);
      }
    });

    _startAnalysis();
  }

  @override
  void dispose() {
    _laserCtrl.dispose();
    _radarCtrl.dispose();
    _stageTimer?.cancel();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    final apiClient = ref.read(apiClientProvider);

    try {
      Uint8List? rawBytes = widget.imageBytes;
      if ((rawBytes == null || rawBytes.isEmpty) && widget.imageFile != null) {
        try {
          rawBytes = await widget.imageFile!.readAsBytes();
        } catch (_) {}
      }

      if (rawBytes == null || rawBytes.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'صورة الروشتة غير صالحة أو فارغة.';
        });
        return;
      }

      // 1. Prepare full prescription image without premature cropping
      final fullFrameBytes = PrescriptionFrameCrop.prepareFullPrescriptionImage(
        bytes: rawBytes,
        maxDimension: 1600,
        quality: 82,
      );
      final compressedBytes = fullFrameBytes;

      // 2. Parallel on-device ML Kit OCR hint extraction (non-blocking with timeout)
      String? effectiveOcrHint = widget.ocrHintText;
      if (effectiveOcrHint == null || effectiveOcrHint.isEmpty) {
        try {
          final ocrTask = () async {
            final ocr = OnDeviceOcrService();
            try {
              final lines = await ocr.extractFromJpegBytes(compressedBytes);
              return lines.isNotEmpty ? lines.join('\n') : null;
            } finally {
              await ocr.dispose();
            }
          }();

          effectiveOcrHint = await ocrTask.timeout(
            const Duration(milliseconds: 1200),
            onTimeout: () => null,
          );
        } catch (_) {}
      }

      final response = await apiClient.parsePrescriptionImageBytes(
        compressedBytes,
        ocrHintText: effectiveOcrHint,
      );

      if (!mounted) return;

      if (response.isSuccess) {
        setState(() {
          _isFinished = true;
          _currentStage = 3;
        });

        // Collect all extracted medications
        final List<PrescriptionBasketItem> basketItems = [];

        if (response.candidates.isNotEmpty) {
          for (final c in response.candidates) {
            basketItems.add(PrescriptionBasketItem(
              tradeName: c.tradeName,
              strength: c.strength,
              dosageForm: c.dosageForm,
              quantity: c.quantity > 0 ? c.quantity : 1,
              confidence: c.confidence,
              activeIngredient: c.activeIngredient,
              rawSig: c.rawSig ?? response.rawSig,
              arabicSig: c.arabicSig ?? response.arabicSig,
              priceEgp: c.priceEgp ?? response.priceEgp,
            ));
          }
        } else if (response.resolvedName.isNotEmpty) {
          basketItems.add(PrescriptionBasketItem(
            tradeName: response.resolvedName,
            strength: response.strength,
            dosageForm: response.dosageForm,
            quantity: 1,
            confidence: response.confidence,
            activeIngredient: response.activeIngredient,
            rawSig: response.rawSig,
            arabicSig: response.arabicSig,
            priceEgp: response.priceEgp,
          ));
        }

        if (basketItems.isNotEmpty) {
          // Egyptian Law No. 151: Post-scan privacy crop specifically for pharmacist verification
          final sanitizedCrop = PrescriptionFrameCrop.cropPrescriptionMedicationBody(
            bytes: fullFrameBytes,
            headerRatio: 0.20,
            footerRatio: 0.18,
          ) ?? fullFrameBytes;
          final sanitizedBase64 = base64Encode(sanitizedCrop);

          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          // Replace HUD with Basket screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PrescriptionBasketScreen(
                initialItems: basketItems,
                safetyAlerts: response.safetyAlerts,
                sanitizedCropBytes: sanitizedCrop,
                sanitizedCropBase64: sanitizedBase64,
              ),
            ),
          );
          return;
        }
      }

      // If no medication recognized
      setState(() {
        _errorMessage = response.errorMessage ??
            'تعذر قراءة أدوية الروشتة بدقة. تأكد من إضاءة الصورة ووضوح خط الطبيب.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر الاتصال بالسيرفر. تأكد من تشغيل السيرفر أو الاتصال بنفس الشبكة وإعادة المحاولة.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate
      body: Stack(
        children: [
          // 1. Prescription photo preview
          Positioned.fill(
            child: Opacity(
              opacity: 0.85,
              child: widget.imageBytes != null
                  ? Image.memory(widget.imageBytes!, fit: BoxFit.contain)
                  : (widget.imageFile != null
                      ? Image.file(widget.imageFile!, fit: BoxFit.contain)
                      : Container(color: Colors.black)),
            ),
          ),

          // 2. High-tech gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // 3. Animated Laser Beam Sweep
          if (!_isFinished && _errorMessage == null)
            AnimatedBuilder(
              animation: _laserAnim,
              builder: (context, _) {
                final topPos = (size.height * 0.15) +
                    (_laserAnim.value * (size.height * 0.45));
                return Positioned(
                  top: topPos,
                  left: 20,
                  right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Laser glow beam
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withValues(alpha: 0.9),
                              blurRadius: 14,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              blurRadius: 24,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      // Soft gradient sweep trail
                      Container(
                        height: 25,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF00E676).withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // 4. Futuristic CustomPainter Radar Sweep HUD (concentric radar rings, animated sweep angle, targeting reticles, pulse waves)
          AnimatedBuilder(
            animation: _radarCtrl,
            builder: (context, _) {
              final targetRect = Rect.fromLTWH(
                24,
                size.height * 0.15,
                size.width - 48,
                size.height * 0.45,
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: FuturisticRadarSweepHudPainter(
                          sweepAngle: _radarCtrl.value * 2 * math.pi,
                          pulseValue: (_radarCtrl.value * 2) % 1.0,
                          targetRect: targetRect,
                          statusText: _hudMicrocopy[_currentStage],
                          isFinished: _isFinished,
                        ),
                      ),
                    ),
                  ),
                  // Dynamic Arabic Microcopy Status Badge
                  Positioned(
                    top: (size.height * 0.15) - 34,
                    left: 28,
                    right: 28,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF00E676).withValues(alpha: 0.65),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withValues(alpha: 0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isFinished
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFF00E676).withValues(
                                        alpha: 0.8 +
                                            0.2 *
                                                math.sin(
                                                    _radarCtrl.value * 2 * math.pi),
                                      ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFF00E676),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _hudMicrocopy[_currentStage],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 5. Header Bar (Radar + Title + Close)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Pulsing Radar indicator
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFF00E676).withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.radar_rounded,
                        color: Color(0xFF00E676),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'مسح الروشتة الذكي',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Google Gemini Vision AI • تحليل متعدد الأدوية',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),

          // 6. Bottom Glassmorphic Progress HUD Panel
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: size.width < 380 ? 14.0 : 18.0,
                vertical: size.height < 700 ? 12.0 : 16.0,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _errorMessage != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.danger, size: 36),
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'إلغاء',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text(
                                  'إعادة المحاولة',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _errorMessage = null;
                                    _currentStage = 0;
                                  });
                                  _startAnalysis();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF00E676),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  _stages[_currentStage],
                                  key: ValueKey(_currentStage),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: size.height < 700 ? 13 : 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: size.height < 700 ? 10 : 16),
                        // Linear multi-stage progress track
                        Row(
                          children: List.generate(_stages.length, (index) {
                            final isActive = index <= _currentStage;
                            return Expanded(
                              child: Container(
                                height: 4,
                                margin: EdgeInsets.only(
                                    right: index < _stages.length - 1 ? 6 : 0),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF00E676)
                                      : Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter rendering futuristic HUD:
/// - Concentric radar rings
/// - Animated glowing sweep angle with gradient bloom
/// - Targeting corner reticles
/// - Radial pulse wave ripples
class FuturisticRadarSweepHudPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseValue;
  final Rect targetRect;
  final String statusText;
  final bool isFinished;

  FuturisticRadarSweepHudPainter({
    required this.sweepAngle,
    required this.pulseValue,
    required this.targetRect,
    required this.statusText,
    this.isFinished = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Sleek, clean document framing border
    final framePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(16)),
      framePaint,
    );

    // 2. High-precision medical corner reticles around targetRect
    final reticlePaint = Paint()
      ..color = isFinished
          ? const Color(0xFF00E676)
          : const Color(0xFF00E676).withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLen = 32.0;

    // Top-Left corner
    canvas.drawLine(targetRect.topLeft,
        targetRect.topLeft + const Offset(cornerLen, 0), reticlePaint);
    canvas.drawLine(targetRect.topLeft,
        targetRect.topLeft + const Offset(0, cornerLen), reticlePaint);

    // Top-Right corner
    canvas.drawLine(targetRect.topRight,
        targetRect.topRight + const Offset(-cornerLen, 0), reticlePaint);
    canvas.drawLine(targetRect.topRight,
        targetRect.topRight + const Offset(0, cornerLen), reticlePaint);

    // Bottom-Left corner
    canvas.drawLine(targetRect.bottomLeft,
        targetRect.bottomLeft + const Offset(cornerLen, 0), reticlePaint);
    canvas.drawLine(targetRect.bottomLeft,
        targetRect.bottomLeft + const Offset(0, -cornerLen), reticlePaint);

    // Bottom-Right corner
    canvas.drawLine(targetRect.bottomRight,
        targetRect.bottomRight + const Offset(-cornerLen, 0), reticlePaint);
    canvas.drawLine(targetRect.bottomRight,
        targetRect.bottomRight + const Offset(0, -cornerLen), reticlePaint);
  }

  @override
  bool shouldRepaint(covariant FuturisticRadarSweepHudPainter oldDelegate) => true;
}
