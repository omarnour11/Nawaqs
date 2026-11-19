import 'package:flutter/material.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/core/utils/arabic_digits.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:nawakes_mobile/features/search/presentation/medication_equivalents_sheet.dart';

String _formatDistance(double km) {
  if (km < 0) return '';
  if (km < 1) return '${ArabicDigits.convert((km * 1000).round())} متر';
  return '${ArabicDigits.convert(km.toStringAsFixed(1), formatDecimals: true)} كم';
}

/// Bioequivalent substitutes card. Rendered below empty search
/// results or on out-of-stock items. Shows active scientific ingredient,
/// bioequivalent comparisons, savings badge, and direct button to open the full interactive sheet.
class MedicationEquivalentsCard extends StatelessWidget {
  const MedicationEquivalentsCard({
    super.key,
    required this.response,
    this.medicationName,
  });

  final MedicationEquivalentsResponse response;
  final String? medicationName;

  @override
  Widget build(BuildContext context) {
    if (response.availableEquivalents.isEmpty) return const SizedBox.shrink();

    final targetMedName = medicationName ??
        response.original?.tradeName ??
        response.activeIngredient ??
        'الدواء المطلوب';
    final activeIng = response.activeIngredientAr ?? response.activeIngredient;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warningIcon.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                Icons.swap_horiz_rounded,
                bg: Color(0xFFE6F4EA),
                color: Color(0xFF137333),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بدائل ومثائل معتمدة بالاسم العلمي',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (activeIng != null && activeIng.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        'المادة الفعالة: $activeIng',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (response.totalRegisteredInEgypt > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${ArabicDigits.convert(response.totalRegisteredInEgypt)} مثيل',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF137333),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            response.original != null
                ? '${response.original!.tradeName} غير متوفر حالياً — دي أقرب مثائل مطابقة بالصيدليات القريبة:'
                : 'أقرب بدائل ومثائل متطابقة متاحة للاستلام الفوري:',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          ...response.availableEquivalents.take(3).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: InkWell(
                  onTap: () {
                    MedicationEquivalentsSheet.show(
                      context,
                      medicationName: targetMedName,
                      preloadedResponse: response,
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: _EquivalentRow(e),
                ),
              )),
          const SizedBox(height: 6),
          // Button to open full Equivalents Sheet
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                MedicationEquivalentsSheet.show(
                  context,
                  medicationName: targetMedName,
                  preloadedResponse: response,
                );
              },
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: Text(
                'عرض جميع المثائل والبدائل (${ArabicDigits.convert(response.availableEquivalents.length)})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              response.legalDisclaimer,
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquivalentRow extends StatelessWidget {
  const _EquivalentRow(this.e);
  final EquivalentPharmacyResultDto e;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          IconTile(
            e.isExactBioequivalent ? Icons.verified_rounded : Icons.swap_horiz_rounded,
            bg: e.isExactBioequivalent ? AppColors.successBg : const Color(0xFFEFF6FF),
            color: e.isExactBioequivalent ? AppColors.successIcon : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.equivalentTradeName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (e.isExactBioequivalent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4EA),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'مطابق 100%',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF137333),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  e.inStock && e.distanceKm >= 0
                      ? '${e.pharmacyName} · ${_formatDistance(e.distanceKm)}'
                      : 'غير متوفر بالصيدليات القريبة حالياً',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                e.priceAtPharmacy.toArabicPrice(),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentBlue,
                ),
              ),
              const SizedBox(height: 4),
              if (e.priceSavingPercent > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'وفر ${ArabicDigits.convert(e.priceSavingPercent.toStringAsFixed(0))}%',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.successIcon,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
