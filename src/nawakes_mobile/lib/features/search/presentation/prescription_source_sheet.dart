import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nawakes_mobile/core/services/image_picker_service.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/search/presentation/camera_scan_sheet.dart';

/// Bottom sheet offering the user the choice between live camera scanning
/// and uploading an existing prescription/medication image from device gallery.
class PrescriptionSourceSheet extends ConsumerStatefulWidget {
  const PrescriptionSourceSheet({
    super.key,
    required this.onScanned,
  });

  final ValueChanged<CameraScanResult> onScanned;

  /// Displays the source selection bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required ValueChanged<CameraScanResult> onScanned,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PrescriptionSourceSheet(onScanned: onScanned),
    );
  }

  @override
  ConsumerState<PrescriptionSourceSheet> createState() =>
      _PrescriptionSourceSheetState();
}

class _PrescriptionSourceSheetState
    extends ConsumerState<PrescriptionSourceSheet> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGalleryPick() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pickerService = ref.read(imagePickerServiceProvider);
      final file = await pickerService.pickFromGallery();
      if (!mounted) return;

      if (file == null) {
        // User cancelled photo selection
        setState(() => _isLoading = false);
        return;
      }

      final result = await pickerService.processImage(file);
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر قراءة ملف الصورة. تأكد من صلاحية الملف وحاول ثانية.';
        });
        return;
      }

      final hasImage = (result.imageBytes != null && result.imageBytes!.isNotEmpty) ||
          result.imageFile != null ||
          (result.croppedImageBase64 != null && result.croppedImageBase64!.isNotEmpty);

      if (result.lines.isEmpty && !hasImage) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'لم نتمكن من قراءة اسم الدواء من الصورة. تأكد من وضوح الصورة وحاول ثانية.';
        });
        return;
      }

      Navigator.of(context).pop();
      widget.onScanned(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ أثناء معالجة الصورة. يرجى المحاولة مرة أخرى.';
      });
    }
  }

  void _handleCameraPick() {
    Navigator.of(context).pop();
    CameraScanSheet.show(
      context,
      onScanned: widget.onScanned,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlueBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    color: AppColors.accentBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'البحث بصورة الروشتة أو الدواء',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'اختر طريقة إدخال صورة الروشتة أو علبة الدواء',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'إغلاق',
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.dangerIcon.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.dangerText, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.dangerText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_isLoading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'جاري قراءة الروشتة واستخراج أسماء الأدوية...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تتم المعالجة محلياً على جهازك بأعلى درجات الأمان',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Option 1: Live Camera Scan
              _SourceOptionCard(
                key: const ValueKey('source_camera_button'),
                icon: Icons.photo_camera_rounded,
                iconColor: AppColors.accentBlue,
                iconBgColor: AppColors.accentBlueBg,
                title: 'التقاط صورة بالكاميرا',
                subtitle: 'مسح فوري للروشتة أو علبة الدواء مع توجيه ذكي',
                onTap: _handleCameraPick,
              ),
              const SizedBox(height: 12),

              // Option 2: Gallery Upload
              _SourceOptionCard(
                key: const ValueKey('source_gallery_button'),
                icon: Icons.photo_library_rounded,
                iconColor: AppColors.brand700,
                iconBgColor: AppColors.brand700.withValues(alpha: 0.1),
                title: 'اختيار صورة من المعرض',
                subtitle: 'رفع صورة روشتة أو علبة دواء محفوظة في جهازك',
                onTap: _handleGalleryPick,
              ),
              const SizedBox(height: 20),

              // Privacy Notice
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.fieldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '🔒 تتم معالجة الصور وقراءتها بأمان لحماية خصوصيتك الطبية',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceOptionCard extends StatelessWidget {
  const _SourceOptionCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.fieldBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textMuted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
