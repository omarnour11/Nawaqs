import 'package:flutter/material.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

/// Animated recording overlay shown while voice search is active (isListening == true).
/// Provides clear visual feedback: pulsing rings, waveform activity bars,
/// live transcript text, and explicit action buttons (Cancel / Done).
class VoiceRecordingOverlay extends StatefulWidget {
  const VoiceRecordingOverlay({
    super.key,
    required this.onCancel,
    required this.onDone,
    this.currentTranscript = '',
  });

  final VoidCallback onCancel;
  final VoidCallback onDone;
  final String currentTranscript;

  @override
  State<VoiceRecordingOverlay> createState() => _VoiceRecordingOverlayState();
}

class _VoiceRecordingOverlayState extends State<VoiceRecordingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.currentTranscript.trim().isNotEmpty;

    return Positioned.fill(
      key: const ValueKey('voice_recording_overlay'),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Pulsing Mic Circle
                  SizedBox(
                    height: 110,
                    width: 110,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulsing wave
                            Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accentBlue
                                      .withValues(alpha: _opacityAnimation.value * 0.3),
                                ),
                              ),
                            ),
                            // Inner pulse
                            Transform.scale(
                              scale: 1.0 + (_scaleAnimation.value - 1.0) * 0.5,
                              child: Container(
                                width: 75,
                                height: 75,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary
                                      .withValues(alpha: _opacityAnimation.value * 0.4),
                                ),
                              ),
                            ),
                            // Center mic icon container
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [AppColors.brand900, AppColors.primary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.mic_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Waveform Activity Simulation
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final val = _pulseController.value;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildWaveBar(10 + val * 12),
                          const SizedBox(width: 4),
                          _buildWaveBar(16 + (1 - val) * 16),
                          const SizedBox(width: 4),
                          _buildWaveBar(8 + val * 22),
                          const SizedBox(width: 4),
                          _buildWaveBar(18 + val * 10),
                          const SizedBox(width: 4),
                          _buildWaveBar(12 + (1 - val) * 14),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'جارٍ الاستماع إليك الآن...',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'تحدث باسم الدواء (مثال: بانادول، أو بانادول و كونكور)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),

                  if (hasText) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        '«${widget.currentTranscript.trim()}»',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand900,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      // Cancel Button
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('voice_overlay_cancel_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text(
                            'إلغاء',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: widget.onCancel,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Done / Search Now Button
                      Expanded(
                        child: ElevatedButton.icon(
                          key: const ValueKey('voice_overlay_done_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand900,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            elevation: 1,
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text(
                            'تم الاستماع',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: widget.onDone,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildWaveBar(double height) {
    return Container(
      width: 4,
      height: height.clamp(6.0, 32.0),
      decoration: BoxDecoration(
        color: AppColors.accentBlue,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
