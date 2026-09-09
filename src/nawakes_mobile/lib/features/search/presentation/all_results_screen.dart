import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:nawakes_mobile/features/search/presentation/pharmacy_details_screen.dart';
import 'package:go_router/go_router.dart';

String _timeAgo(DateTime utc) {
  final diff = DateTime.now().toUtc().difference(utc);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'تحديث من ${diff.inMinutes} دقايق';
  return 'تحديث من ${diff.inHours} ساعة';
}

String _formatDistance(double km) {
  if (km <= 0) return 'قريب جدًا';
  if (km < 1) return '${(km * 1000).round()} متر';
  return '${km.toStringAsFixed(1)} كم';
}

(ChipTone, String) _availabilityOf(PharmacySearchResultDto r) {
  if (r.status != 'InStock') return (ChipTone.danger, 'غير متاح');
  final q = r.quantity;
  if (q <= 4) return (ChipTone.warning, 'محدود · $q وحدة');
  return (ChipTone.success, 'متاح');
}

/// كل النتايج — كامل قائمة نتائج دواء واحد بنفس ستايل الراو.


/// وسائط النقل لشاشة كل النتايج عبر go_router (extra).
class AllResultsArgs {
  final List<PharmacySearchResultDto> results;
  final String medicationName;
  AllResultsArgs({required this.results, required this.medicationName});
}

class AllResultsScreen extends HookConsumerWidget {
  final List<PharmacySearchResultDto> results;
  final String medicationName;

  const AllResultsScreen({
    super.key,
    required this.results,
    required this.medicationName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NawaqsTopBar(eyebrow: 'نواقص', title: 'كل النتايج', back: true),
            ScreenSubtitle('$medicationName · ${results.length} صيدلية متوفرة'),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, i) => _ResultRow(item: results[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final PharmacySearchResultDto item;
  const _ResultRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final (tone, label) = _availabilityOf(item);
    final (bg, fg) = switch (tone) {
      ChipTone.success => (AppColors.successBg, AppColors.successIcon),
      ChipTone.warning => (AppColors.warningBg, AppColors.warningIcon),
      ChipTone.danger => (AppColors.dangerBg, AppColors.dangerIcon),
      ChipTone.neutral => (AppColors.accentBlueBg, AppColors.accentBlue),
    };

    final inStock = item.status == 'InStock';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(Icons.storefront_outlined, bg: bg, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.pharmacyName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                        '${item.addressLine} · ${_timeAgo(item.lastUpdatedAt)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: fg, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(label,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: fg)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatDistance(item.distanceKm),
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('EGP ${item.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentBlue)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: inStock
                  ? () => context.push('/pharmacy-details',
                      extra: PharmacyDetailsArgs(item: item))
                  : null,
              icon: const Icon(Icons.bookmark_add_outlined, size: 17),
              label: Text(inStock ? 'احجز من هنا' : 'غير متاح الآن'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                disabledBackgroundColor: const Color(0xFFE5E7EA),
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
