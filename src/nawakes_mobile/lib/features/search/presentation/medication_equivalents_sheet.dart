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
  if (km < 1) return '${ArabicDigits.convert((km * 1000).round())} متر';
  return '${ArabicDigits.convert(km.toStringAsFixed(1), formatDecimals: true)} كم';
}

/// Rich interactive bottom sheet for clinical bioequivalents and therapeutic alternatives
/// by active scientific ingredient (INN), compliant with Egyptian Drug Authority (EDA) rules.
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
    final selectedTab = useState(0); // 0: Bioequivalents, 1: Alternatives, 2: All
    final searchLat = lat ?? 30.0444; // Cairo default or injected coordinate
    final searchLng = lng ?? 31.2357;

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
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Drag Handle & Header Bar
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
              width: 44,
              height: 4.5,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المثائل والبدائل بالاسم العلمي',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'بحث مطابق لقاعدة بيانات هيئة الدواء المصرية (EDA)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 22),
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
    // Partition items
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Medication Clinical Header Card
        _buildClinicalHeaderCard(data),
        const SizedBox(height: 12),

        // Tabs
        _buildSegmentedTabBar(
          selectedTab: selectedTab,
          bioCount: bioequivalents.length,
          altCount: alternatives.length,
          allCount: allItems.length,
        ),
        const SizedBox(height: 14),

        // Tab explanation note
        _buildTabNote(selectedTab.value),
        const SizedBox(height: 12),

        // List of equivalent results
        if (displayedList.isEmpty)
          _buildEmptyTabState(selectedTab.value)
        else
          ...displayedList.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? const Color(0xFF142730) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.biotech_rounded, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.isActiveIngredientSearch
                      ? 'البحث بالمادة الفعالة: ${data.activeIngredient ?? medicationName}'
                      : (original?.tradeName ?? medicationName),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (totalEda > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ArabicDigits.convert(totalEda)} مثيل مسجل',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (activeIng != null && activeIng.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'المادة الفعالة (INN): $activeIng',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (original != null && !original.isAvailableNearby) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFD97706)),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    'الدواء المطلوب غير متوفر حالياً في الصيدليات القريبة — البدائل أدناه متوفرة للاستلام الفوري.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB45309),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
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
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              '(${ArabicDigits.convert(count)})',
              style: TextStyle(
                fontSize: 10.5,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF059669)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'المثائل الحيوية: نفس المادة الفعالة بنفس التركيز والشكل الصيدلي (تطابق دوائي معتمد 100%).',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF065F46), height: 1.4),
              ),
            ),
          ],
        ),
      );
    } else if (tab == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Row(
          children: [
            Icon(Icons.swap_horizontal_circle_outlined, size: 16, color: Color(0xFF2563EB)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'البدائل العلاجية: تركيزات أو أشكال صيدلية مختلفة — يرجى استشارة الصيدلي أو الطبيب قبل التبديل.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.4),
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: item.isExactBioequivalent
                  ? const Color(0xFF059669).withValues(alpha: 0.06)
                  : const Color(0xFF2563EB).withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.equivalentTradeName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (item.commercialNameAr != null &&
                          item.commercialNameAr != item.equivalentTradeName) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.commercialNameAr!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Category Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isExactBioequivalent ? const Color(0xFF059669) : const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isExactBioequivalent ? Icons.verified_rounded : Icons.sync_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.isExactBioequivalent ? 'مثيل متطابق 100%' : 'بديل / تركيز آخر',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Strength & Dosage Form
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (item.strength != null && item.strength!.isNotEmpty)
                      _buildPill(item.strength!, Icons.fitness_center_rounded),
                    if (item.dosageForm != null && item.dosageForm!.isNotEmpty)
                      _buildPill(item.dosageForm!, Icons.medication_liquid_rounded),
                    if (item.manufacturer != null && item.manufacturer!.isNotEmpty)
                      _buildPill('إنتاج: ${item.manufacturer!}', Icons.apartment_rounded),
                  ],
                ),
                const SizedBox(height: 12),

                // Price & Savings Row
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.fieldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'سعر الصيدلية (تسعيرة جبرية EDA):',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.priceAtPharmacy.toArabicPrice(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasSavings)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'وفر ${ArabicDigits.convert(item.priceSavingPercent.toStringAsFixed(0))}%',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                              if (item.priceDifferenceEGP > 0)
                                Text(
                                  'أوفر بـ ${ArabicDigits.convert(item.priceDifferenceEGP.toStringAsFixed(1))} ج.م',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Pharmacy & Direct Action Button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_pharmacy_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.pharmacyName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.near_me_rounded, size: 12, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                _formatDistance(item.distanceKm),
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'متوفر حالياً',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Open pharmacy details or reserve screen
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
                          latitude: 30.0444,
                          longitude: 31.2357,
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_add_rounded, size: 16),
                          SizedBox(width: 4),
                          Text('حجز / تفاصيل', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildRegulatoryDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningIcon.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.security_rounded, size: 20, color: AppColors.warningIcon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إقرار هيئة الدواء المصرية (EDA):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  disclaimer.isNotEmpty
                      ? disclaimer
                      : 'المثائل الحيوية تحتوي على نفس المادة الفعالة وتُصرف كبدائل نظامية متطابقة، بينما البدائل العلاجية تتطلب استشارة الطبيب أو الصيدلي لاختلاف التركيز أو الشكل الصيدلي وفقاً لضوابط هيئة الدواء المصرية.',
                  style: const TextStyle(
                    fontSize: 11,
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
            'جاري استرجاع المثائل والبدائل بالاسم العلمي...',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'مطابقة قواعد بيانات هيئة الدواء المصرية والصيدليات القريبة',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              'لا توجد مثائل مسجلة لهذا الاسم',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'تأكد من كتابة الاسم بصورة صحيحة أو جرب البحث بالاسم التجاري الإنجليزي أو العربي.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
            tab == 0 ? Icons.science_outlined : Icons.swap_horiz_rounded,
            size: 44,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            tab == 0
                ? 'لا توجد مثائل متطابقة متاحة حالياً في الصيدليات القريبة'
                : 'لا توجد بدائل علاجية مسجلة لهذه الفئة',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'تحقق من التبويبات الأخرى لعرض الخيارات المتوفرة.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
