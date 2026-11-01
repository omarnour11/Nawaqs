import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _laserCtrl;
  late final Animation<double> _laserAnim;

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

  @override
  void initState() {
    super.initState();
    _laserCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnim = CurvedAnimation(parent: _laserCtrl, curve: Curves.easeInOut);

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
    _stageTimer?.cancel();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    final apiClient = ref.read(apiClientProvider);

    try {
      ParsedMedicationResponse? response;

      if (widget.imageBytes != null && widget.imageBytes!.isNotEmpty) {
        response = await apiClient.parsePrescriptionImageBytes(
          widget.imageBytes!,
          ocrHintText: widget.ocrHintText,
        );
      } else if (widget.imageFile != null) {
        response = await apiClient.parsePrescriptionImageFilePath(
          widget.imageFile!.path,
          ocrHintText: widget.ocrHintText,
        );
      }

      if (!mounted) return;

      if (response != null && response.isSuccess) {
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
          ));
        }

        if (basketItems.isNotEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          // Replace HUD with Basket screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  PrescriptionBasketScreen(initialItems: basketItems),
            ),
          );
          return;
        }
      }

      // If no medication recognized
      setState(() {
        _errorMessage = response?.errorMessage ??
            'تعذر قراءة أدوية الروشتة بدقة. تأكد من إضاءة الصورة ووضوح خط الطبيب.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'حصل خطأ في الاتصال بالخدمة. حاول مرة أخرى.';
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
                    (_laserAnim.value * (size.height * 0.55));
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

          // 4. Scanner Viewfinder Reticle Corners
          Positioned(
            top: size.height * 0.15,
            left: 24,
            right: 24,
            height: size.height * 0.55,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF00E676).withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Google Gemini 1.5 Flash • تحليل متعدد الأدوية',
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
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
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
                                child: const Text('إلغاء'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('إعادة المحاولة'),
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
