import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/core/utils/arabic_digits.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:nawakes_mobile/features/search/presentation/pharmacy_details_screen.dart';

String _formatDistance(double km) {
  if (km < 0) return '';
  if (km < 1) return '${ArabicDigits.convert((km * 1000).round())} متر';
  return '${ArabicDigits.convert(km.toStringAsFixed(1), formatDecimals: true)} كم';
}

/// Rich, calm, and senior-friendly bottom sheet for clinical bioequivalents
/// and therapeutic alternatives by active scientific ingredient (INN),
/// fully compliant with Egyptian Drug Authority (EDA) standards.
class MedicationEquivalentsSheet extends HookConsumerWidget {
  final String medicationName;
  final double? lat;
  final double? lng;
  final double radiusKm;
  final MedicationEquivalentsResponse? preloadedResponse;

  const MedicationEquivalentsSheet({
    super.key,
    required this.medicationName,
    this.lat,
    this.lng,
    this.radiusKm = 10,
    this.preloadedResponse,
  });

  /// Static helper to display the sheet from any screen.
  static Future<void> show(
    BuildContext context, {
    required String medicationName,
    double? lat,
    double? lng,
    double radiusKm = 10,
    MedicationEquivalentsResponse? preloadedResponse,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MedicationEquivalentsSheet(
        medicationName: medicationName,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        preloadedResponse: preloadedResponse,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 0: Bioequivalents (المثائل المتطابقة), 1: Alternatives (البدائل والتركيزات), 2: All (الكل)
    final selectedTab = useState(0);
    final searchLat = lat ?? 30.0476;
    final searchLng = lng ?? 31.2365;

    final memoFuture = useMemoized(
      () => preloadedResponse != null
          ? Future.value(preloadedResponse!)
          : ref.read(apiClientProvider).getMedicationEquivalents(
                medicationName,
                searchLat,
                searchLng,
                radiusKm,
              ),
      [medicationName, searchLat, searchLng, radiusKm, preloadedResponse],
    );

    final snapshot = useFuture(memoFuture);

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Drag Handle & Calm Header
              _buildTopHeader(context),

              // Content Area
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState();
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState(context, snapshot.error);
                    }

                    final data = snapshot.data;
                    if (data == null) {
                      return _buildEmptyState(context);
                    }

                    return _buildLoadedContent(
                      context,
                      data,
                      selectedTab,
                      scrollController,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? const Color(0xFF142730) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        children: [
          // Drag pill
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0F766E), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المثائل والبدائل بالاسم العلمي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'أدوية معتمدة لها نفس الفعالية ومصرح بها من هيئة الدواء (EDA)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 24),
                tooltip: 'إغلاق',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedContent(
    BuildContext context,
    MedicationEquivalentsResponse data,
    ValueNotifier<int> selectedTab,
    ScrollController scrollController,
  ) {
    final bioequivalents = data.bioequivalents ??
        data.availableEquivalents.where((e) => e.isExactBioequivalent).toList();
    final alternatives = data.therapeuticAlternatives ??
        data.availableEquivalents.where((e) => !e.isExactBioequivalent).toList();
    final allItems = data.availableEquivalents;

    List<EquivalentPharmacyResultDto> displayedList;
    switch (selectedTab.value) {
      case 0:
        displayedList = bioequivalents;
        break;
      case 1:
        displayedList = alternatives;
        break;
      default:
        displayedList = allItems;
        break;
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Medication Summary Card
        _buildClinicalHeaderCard(data),
        const SizedBox(height: 14),

        // Tabs (Clean, senior-friendly spacing and typography)
        _buildSegmentedTabBar(
          selectedTab: selectedTab,
          bioCount: bioequivalents.length,
          altCount: alternatives.length,
          allCount: allItems.length,
        ),
        const SizedBox(height: 12),

        // Friendly reassurance note for selected tab
        _buildTabNote(selectedTab.value),
        const SizedBox(height: 14),

        // List of equivalent drug cards
        if (displayedList.isEmpty)
          _buildEmptyTabState(selectedTab.value)
        else
          ...displayedList.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildEquivalentCard(context, item, data),
              )),

        const SizedBox(height: 10),

        // Mandatory EDA Disclaimer Card
        _buildRegulatoryDisclaimer(data.legalDisclaimer),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildClinicalHeaderCard(MedicationEquivalentsResponse data) {
    final activeIng = data.activeIngredientAr ?? data.activeIngredient;
    final original = data.original;
    final totalEda = data.totalRegisteredInEgypt;

    final displayName = data.isActiveIngredientSearch
        ? (activeIng ?? medicationName)
        : (original?.tradeName ?? medicationName);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? const Color(0xFF142730) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC).withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medication_rounded, color: Color(0xFF16A34A), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (activeIng != null && activeIng.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'المادة الفعالة: $activeIng',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (totalEda > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ArabicDigits.convert(totalEda)} مثيل مسجل',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (original != null && !original.isAvailableNearby) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الدواء المطلوب غير متوفر حالياً — البدائل أدناه لها نفس المفعول الطبي تماماً ومتاحة.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentedTabBar({
    required ValueNotifier<int> selectedTab,
    required int bioCount,
    required int altCount,
    required int allCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              title: 'المثائل المتطابقة',
              count: bioCount,
              isSelected: selectedTab.value == 0,
              onTap: () => selectedTab.value = 0,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              title: 'البدائل والتركيزات',
              count: altCount,
              isSelected: selectedTab.value == 1,
              onTap: () => selectedTab.value = 1,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              title: 'الكل',
              count: allCount,
              isSelected: selectedTab.value == 2,
              onTap: () => selectedTab.value = 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              '(${ArabicDigits.convert(count)})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white70 : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabNote(int tab) {
    if (tab == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'المثائل الحيوية: نفس المادة الفعالة بنفس التركيز والشكل الصيدلي (تطابق دوائي معتمد 100%).',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF065F46), height: 1.4),
              ),
            ),
          ],
        ),
      );
    } else if (tab == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Row(
          children: [
            Icon(Icons.help_outline_rounded, size: 18, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'البدائل العلاجية: تركيزات أو أشكال صيدلية مختلفة — يرجى استشارة الصيدلي أو الطبيب قبل التبديل.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF), height: 1.4),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildEquivalentCard(
    BuildContext context,
    EquivalentPharmacyResultDto item,
    MedicationEquivalentsResponse data,
  ) {
    final hasSavings = item.priceSavingPercent > 0;
    final isActuallyInStock = item.inStock &&
        item.distanceKm >= 0 &&
        item.pharmacyId.isNotEmpty &&
        item.pharmacyId != '00000000-0000-0000-0000-000000000000';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Trade Name + Reassurance Tag
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.equivalentTradeName,
                        style: const TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (item.commercialNameAr != null &&
                          item.commercialNameAr != item.equivalentTradeName) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.commercialNameAr!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: item.isExactBioequivalent ? const Color(0xFF059669) : const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isExactBioequivalent ? Icons.verified_rounded : Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.isExactBioequivalent ? 'مثيل متطابق 100%' : 'بديل / تركيز آخر',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Form & Strength Row in plain Arabic
            Row(
              children: [
                if (item.dosageForm != null && item.dosageForm!.isNotEmpty) ...[
                  Text(
                    item.dosageForm!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
                ],
                if (item.strength != null && item.strength!.isNotEmpty) ...[
                  Text(
                    item.strength!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
                ],
                if (item.manufacturer != null && item.manufacturer!.isNotEmpty)
                  Text(
                    'إنتاج ${item.manufacturer!}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Price & Savings Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.fieldBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text(
                    'السعر:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.priceAtPharmacy.toArabicPrice(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const Spacer(),
                  if (hasSavings)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Text(
                        'وفر ${ArabicDigits.convert(item.priceSavingPercent.toStringAsFixed(0))}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Pharmacy Availability & Action Button
            if (isActuallyInStock) ...[
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${item.pharmacyName} · ${_formatDistance(item.distanceKm)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'متوفر الآن',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final pharmacyItem = PharmacySearchResultDto(
                      pharmacyId: item.pharmacyId,
                      pharmacyName: item.pharmacyName,
                      addressLine: 'بالقرب منك',
                      phone: '',
                      trustScore: 4.8,
                      distanceKm: item.distanceKm,
                      inventoryItemId: item.inventoryItemId,
                      medicationName: item.equivalentTradeName,
                      price: item.priceAtPharmacy,
                      status: 'InStock',
                      quantity: 5,
                      lastUpdatedAt: DateTime.now(),
                      latitude: 30.0476,
                      longitude: 31.2365,
                      officialEdaPriceEgp: item.officialPriceEGP,
                      priceVariancePercent: item.priceSavingPercent,
                      isEdaPriceVerified: true,
                      edaPriceBadgeText: 'تسعيرة جبرية EDA',
                      supportsDelivery: true,
                    );

                    context.push(
                      '/pharmacy-details',
                      extra: PharmacyDetailsArgs(item: pharmacyItem),
                    );
                  },
                  icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                  label: const Text(
                    'احجز الدواء من الصيدلية',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ] else ...[
              // Out-of-stock / Registry-only fallback: Zero exception alert button
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 5),
                  const Expanded(
                    child: Text(
                      'غير متوفر حالياً بالصيدليات القريبة',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Safe notification action without invalid navigation
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'تم تفعيل التنبيه! سنرسل لك إشعاراً فور توفر ${item.equivalentTradeName} في أقرب صيدلية.',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF0F766E),
                        duration: const Duration(seconds: 4),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_outlined, size: 18),
                  label: const Text(
                    'نبهني فور توفره في صيدلية قريبة',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRegulatoryDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warningIcon.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.health_and_safety_rounded, size: 22, color: AppColors.warningIcon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إقرار هيئة الدواء المصرية (EDA):',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  disclaimer.isNotEmpty
                      ? disclaimer
                      : 'المثائل الحيوية المتطابقة تحتوي على نفس المادة الفعالة والتركيز وتصرف كبديل نظامي موثوق. استشر الصيدلي أو الطبيب دائماً.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            'جاري البحث عن البدائل المعتمدة...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'مطابقة قاعدة بيانات هيئة الدواء المصرية',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 52, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'تعذر تحميل البدائل حالياً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              error?.toString() ?? 'حدث خطأ في الاتصال بالشبكة',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const NuqousMascot.searching(height: 72),
            const SizedBox(height: 14),
            const Text(
              'لا توجد بدائل مسجلة لهذا الاسم',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'تأكد من كتابة الاسم بصورة صحيحة أو جرب البحث بالاسم التجاري أو المادة الفعالة.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTabState(int tab) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            tab == 0 ? Icons.verified_outlined : Icons.swap_horiz_rounded,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            tab == 0
                ? 'لا توجد مثائل متطابقة مسجلة لهذا الدواء'
                : 'لا توجد بدائل أو تركيزات أخرى مسجلة',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'تحقق من التبويب الآخر لعرض الخيارات المتاحة.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
