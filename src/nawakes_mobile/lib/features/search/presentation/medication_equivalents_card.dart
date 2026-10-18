import 'package:flutter/material.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';

/// Bioequivalent substitutes card (Phase 4). Rendered below empty search
/// results or on an out-of-stock pharmacy screen. Shows side-by-side
/// comparison, savings badge, and the mandatory Arabic disclaimer.
class MedicationEquivalentsCard extends StatelessWidget {
  const MedicationEquivalentsCard({super.key, required this.response});

  final MedicationEquivalentsResponse response;

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} متر';
    return '${km.toStringAsFixed(1)} كم';
  }

  @override
  Widget build(BuildContext context) {
    if (response.availableEquivalents.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warningIcon.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('بدائل بنفس المادة الفعالة'),
          const SizedBox(height: 6),
          if (response.original != null)
            Text(
              '${response.original!.tradeName} غير متوفر حالياً — دي أقرب بدائل مطابقة:',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
            ),
          const SizedBox(height: 10),
          ...response.availableEquivalents.take(3).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _EquivalentRow(e),
              )),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              response.legalDisclaimer,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.6, color: AppColors.textPrimary),
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
          const IconTile(Icons.swap_horiz_rounded,
              bg: AppColors.successBg, color: AppColors.successIcon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.equivalentTradeName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${e.pharmacyName} · ${_formatDistance(e.distanceKm)}',
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
              Text('EGP ${e.priceAtPharmacy.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.accentBlue)),
              const SizedBox(height: 4),
              if (e.priceSavingPercent > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('يوفر ${e.priceSavingPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.successIcon)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
