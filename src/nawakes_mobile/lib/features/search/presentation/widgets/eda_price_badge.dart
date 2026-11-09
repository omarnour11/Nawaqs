import 'package:flutter/material.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/utils/arabic_digits.dart';

/// Official EDA ceiling-price badge for pharmacy search results.
///
/// - Green check when the pharmacy price matches the official ceiling
///   (with the official price shown).
/// - Orange warning when the price is above the ceiling, with the variance %.
/// - Hidden when the backend had no EDA registry match
///   ([officialEdaPriceEgp] == null → unverified drug).
class EdaPriceBadge extends StatelessWidget {
  final double? officialEdaPriceEgp;
  final double? priceVariancePercent;
  final bool isEdaPriceVerified;
  final String? edaPriceBadgeText;

  const EdaPriceBadge({
    super.key,
    required this.officialEdaPriceEgp,
    this.priceVariancePercent,
    this.isEdaPriceVerified = true,
    this.edaPriceBadgeText,
  });

  @override
  Widget build(BuildContext context) {
    if (officialEdaPriceEgp == null || officialEdaPriceEgp! <= 0) {
      return const SizedBox.shrink();
    }

    final verified = isEdaPriceVerified;
    final bg = verified ? AppColors.successBg : AppColors.warningBg;
    final fg = verified ? AppColors.successText : AppColors.warningText;
    final icon = verified ? Icons.verified_outlined : Icons.trending_up;

    final variance = priceVariancePercent != null && priceVariancePercent! > 0
        ? ' (+${ArabicDigits.convert(priceVariancePercent!.toStringAsFixed(0))}%)'
        : '';

    final text = edaPriceBadgeText != null && edaPriceBadgeText!.isNotEmpty
        ? edaPriceBadgeText!
        : verified
            ? 'مطابق لتسعيرة هيئة الدواء (${officialEdaPriceEgp!.toArabicPrice()})'
            : 'أعلى من تسعيرة الهيئة (${officialEdaPriceEgp!.toArabicPrice()})$variance';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
