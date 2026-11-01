import 'package:flutter/material.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

/// Renders a medication or pharmacy product image with graceful fallback to
/// elegant branded vector medical illustrations tailored to the dosage form.
class MedicationImageView extends StatelessWidget {
  final String? imageUrl;
  final String? dosageForm;
  final String tradeName;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const MedicationImageView({
    super.key,
    this.imageUrl,
    this.dosageForm,
    required this.tradeName,
    this.width = 110,
    this.height = 110,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(16);

    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: br,
        child: Image.network(
          imageUrl!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackVector(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: width,
              height: height,
              color: AppColors.surfaceVariant,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            );
          },
        ),
      );
    }

    return _buildFallbackVector();
  }

  Widget _buildFallbackVector() {
    final form = (dosageForm ?? '').toLowerCase();
    IconData icon;
    String badgeLabel;

    if (form.contains('syrup') || form.contains('شراب') || form.contains('liquid') || form.contains('suspension')) {
      icon = Icons.medication_liquid_rounded;
      badgeLabel = 'شراب';
    } else if (form.contains('inject') || form.contains('حقن') || form.contains('ampoule') || form.contains('vial')) {
      icon = Icons.vaccines_rounded;
      badgeLabel = 'حقن';
    } else if (form.contains('cream') || form.contains('مرهم') || form.contains('ointment') || form.contains('gel')) {
      icon = Icons.sanitizer_rounded;
      badgeLabel = 'مرهم';
    } else if (form.contains('drop') || form.contains('قطرة') || form.contains('eye') || form.contains('ear')) {
      icon = Icons.water_drop_rounded;
      badgeLabel = 'قطرات';
    } else if (form.contains('inhal') || form.contains('بخاخ')) {
      icon = Icons.air_rounded;
      badgeLabel = 'بخاخ';
    } else {
      icon = Icons.medication_rounded;
      badgeLabel = 'أقراص';
    }

    final refDimension = (width.isFinite && width > 0)
        ? (height.isFinite && height > 0 ? (width < height ? width : height) : width)
        : (height.isFinite && height > 0 ? height : 100.0);
    final ringSize = refDimension * 0.72;
    final iconSize = (refDimension * 0.42).clamp(20.0, 56.0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            const Color(0xFFE8F5E9).withValues(alpha: 0.5),
          ],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background concentric soft ring
          Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // Main Form Icon
          Icon(
            icon,
            size: iconSize,
            color: AppColors.primary,
          ),
          // Subtle form label badge
          Positioned(
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                badgeLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
