import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/medication_image_view.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/features/search/presentation/nearby_products_provider.dart';
import 'package:nawakes_mobile/features/search/presentation/widgets/nearby_pharmacy_options_sheet.dart';
import 'package:nawakes_mobile/features/search/presentation/widgets/mandatory_location_prompt_dialog.dart';
import 'package:nawakes_mobile/core/utils/arabic_digits.dart';

/// The El-Ezaby-styled Home Catalog View for Nawakes.
/// Displays delivery mode toggle, address bar, promotional banners, quick services,
/// categories, and the real-time aggregated nearby products feed (within 15km)
/// without revealing pharmacy names until the patient reserves or checks details.
class HomeCatalogView extends ConsumerStatefulWidget {
  final VoidCallback onOpenScanner;
  final ValueChanged<String> onSearchKeyword;

  const HomeCatalogView({
    super.key,
    required this.onOpenScanner,
    required this.onSearchKeyword,
  });

  @override
  ConsumerState<HomeCatalogView> createState() => _HomeCatalogViewState();
}

class _HomeCatalogViewState extends ConsumerState<HomeCatalogView> {
  int _deliveryModeIndex = 0; // 0 = Home Delivery, 1 = Pharmacy Pickup
  int _currentBannerIndex = 0;
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;

  final List<({String name, IconData icon})> _categories = [
    (name: 'الكل', icon: Icons.grid_view_rounded),
    (name: 'أدوية عامة', icon: Icons.medication_rounded),
    (name: 'مسكنات', icon: Icons.healing_rounded),
    (name: 'أدوية مزمنة', icon: Icons.monitor_heart_rounded),
    (name: 'أم وطفل', icon: Icons.child_care_rounded),
    (name: 'فيتامينات', icon: Icons.spa_rounded),
    (name: 'عناية وبشرة', icon: Icons.face_retouching_natural_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_bannerController.hasClients) {
        final next = (_currentBannerIndex + 1) % 3;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final currentLoc = ref.read(deliveryLocationProvider);
          if (currentLoc.label == 'الحي المتميز، 6 أكتوبر') {
            final locService = ref.read(locationServiceProvider);
            final pos = await locService.getCurrentPosition();
            if (pos != null && mounted) {
              final addr = await locService.getDetailedEgyptianAddress(pos.latitude, pos.longitude);
              final gov = LocationService.detectGovernorate(pos.latitude, pos.longitude);
              ref.read(deliveryLocationProvider.notifier).setLocation(
                DeliveryLocation(
                  label: addr ?? 'موقعي الحالي',
                  latitude: pos.latitude,
                  longitude: pos.longitude,
                  governorate: gov,
                ),
              );
            }
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(nearbyProductsProvider);
    final selectedCategory = ref.watch(nearbyProductsCategoryProvider);
    final deliveryLoc = ref.watch(deliveryLocationProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Delivery Mode Selector Toggle ─────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildToggleItem(
                  title: 'توصيل منزلي',
                  icon: Icons.delivery_dining_rounded,
                  isSelected: _deliveryModeIndex == 0,
                  onTap: () async {
                    final allowed = await ensureLocationPermission(context, ref);
                    if (allowed && mounted) {
                      setState(() => _deliveryModeIndex = 0);
                    }
                  },
                ),
              ),
              Expanded(
                child: _buildToggleItem(
                  title: 'استلام من الصيدلية',
                  icon: Icons.storefront_rounded,
                  isSelected: _deliveryModeIndex == 1,
                  onTap: () => setState(() => _deliveryModeIndex = 1),
                ),
              ),
            ],
          ),
        ),

        // ── 2. Delivery Address Bar ──────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textDark),
                    children: [
                      const TextSpan(
                        text: 'التوصيل إلى: ',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      TextSpan(
                        text: deliveryLoc.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _openLocationPicker(context),
                child: const Text(
                  'تغيير',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 3. Promotional Banners Slider ────────────────────────────────────
        SizedBox(
          height: 130,
          child: PageView(
            controller: _bannerController,
            onPageChanged: (i) => setState(() => _currentBannerIndex = i),
            children: [
              _buildBannerCard(
                title: 'وفر حتى 20% على منتجات العناية',
                subtitle: 'خصومات حصرية على مستلزمات الأم والطفل',
                gradientColors: [const Color(0xFF0D7A5F), const Color(0xFF059669)],
                icon: Icons.child_care_rounded,
                mascot: const NuqousMascot.welcome(height: 68),
              ),
              _buildBannerCard(
                title: 'اطلب بالروشتة الذكية بالذكاء الاصطناعي',
                subtitle: 'فك خط يد الطبيب وحجز الأدوية فوراً',
                gradientColors: [const Color(0xFF1E293B), const Color(0xFF334155)],
                icon: Icons.document_scanner_rounded,
                mascot: const NuqousMascot.searching(height: 68),
                onTap: widget.onOpenScanner,
              ),
              _buildBannerCard(
                title: 'نواقص أدويتك؟ وفرناها ببدائل معتمدة',
                subtitle: 'فحص فوري للبدائل الحيوية بنفس المادة الفعالة',
                gradientColors: [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
                icon: Icons.health_and_safety_rounded,
                mascot: const NuqousMascot.celebrating(height: 68),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final isActive = index == _currentBannerIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),

        const SizedBox(height: 18),

        // ── 4. Quick Services (العزبي pattern) ────────────────────────────────
        const Text(
          'الخدمات السريعة',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildServiceItem(
                title: 'طلب بالروشتة',
                icon: Icons.camera_alt_rounded,
                color: AppColors.primary,
                onTap: widget.onOpenScanner,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildServiceItem(
                title: 'التأمين الطبي',
                icon: Icons.verified_user_rounded,
                color: const Color(0xFF0284C7),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('خدمة حجز التأمين الطبي تدعم أكثر من 18 شركة تأمين.'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildServiceItem(
                title: 'نواقص SOS',
                icon: Icons.emergency_rounded,
                color: const Color(0xFFE11D48),
                onTap: () {
                  context.push('/alerts');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildServiceItem(
                title: 'خزانة العائلة',
                icon: Icons.family_restroom_rounded,
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  context.push('/family-cabinet');
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // ── 5. Shop by Category ("تسوق حسب الفئة") ───────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'تسوق حسب الفئة',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            if (selectedCategory != null)
              GestureDetector(
                onTap: () => ref
                    .read(nearbyProductsCategoryProvider.notifier)
                    .setCategory(null),
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final catItem = _categories[index];
              final isAll = index == 0 && selectedCategory == null;
              final isSelected = isAll || selectedCategory == catItem.name;

              return ChoiceChip(
                avatar: Icon(
                  catItem.icon,
                  size: 16,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
                label: Text(catItem.name),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textDark,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.hairline,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) {
                  ref.read(nearbyProductsCategoryProvider.notifier).setCategory(
                      index == 0 ? null : catItem.name);
                },
              );
            },
          ),
        ),

        const SizedBox(height: 22),

        // ── 6. Products Grid (Nearby In-Stock Catalog) ───────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_rounded,
                    size: 18, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'منتجات متوفرة بالقرب منك ومحافظتك',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: AppColors.textMuted,
              onPressed: () => ref.invalidate(nearbyProductsProvider),
            ),
          ],
        ),
        const SizedBox(height: 10),

        productsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.hairline),
            ),
            child: const Center(
              child: Text(
                'تعذر تحميل قائمة المنتجات القريبة حالياً. تأكد من تفعيل خدمة الموقع.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (products) {
            if (products.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.store_mall_directory_outlined,
                        size: 40, color: AppColors.textMuted),
                    SizedBox(height: 8),
                    Text(
                      'لا توجد منتجات مسجلة في مخزون الصيدليات المحيطة بك حالياً.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                return _buildProductCard(p);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildToggleItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCard({
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required IconData icon,
    Widget? mascot,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            mascot ??
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(NearbyProduct p) {
    return GestureDetector(
      onTap: () => NearbyPharmacyOptionsSheet.show(context, p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            // Top Image with Badges
            Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: MedicationImageView(
                      imageUrl: p.imageUrl,
                      dosageForm: p.dosageForm,
                      tradeName: p.tradeName,
                      width: double.infinity,
                      height: 100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: p.availablePharmaciesCount > 0
                      ? NawaqssFoundSticker(
                          label: 'متوفر (${p.availablePharmaciesCount})',
                          fontSize: 9.5,
                          enableTilt: true,
                        )
                      : const NawaqssShortageSticker(
                          label: 'ناقص!',
                          fontSize: 9.5,
                          enableTilt: true,
                        ),
                ),
                if (p.minDistanceKm > 15.0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: NawaqssSingleMedSticker(
                      label: 'المحافظة (${ArabicDigits.convert(p.minDistanceKm.toStringAsFixed(0))} كم)',
                      fontSize: 9.0,
                      enableTilt: true,
                    ),
                  ),
              ],
            ),

            // Product Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.commercialNameAr ?? p.tradeName,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    p.tradeName,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.near_me_rounded,
                          size: 11, color: AppColors.primary),
                      const SizedBox(width: 2),
                      Text(
                        p.minDistanceKm < 1
                            ? '${ArabicDigits.convert((p.minDistanceKm * 1000).round())} م'
                            : '${ArabicDigits.convert(p.minDistanceKm.toStringAsFixed(1), formatDecimals: true)} كم',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        p.price.toArabicPrice(),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Reserve Button (NO pharmacy name upfront!)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: SizedBox(
                width: double.infinity,
                height: 32,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () =>
                      NearbyPharmacyOptionsSheet.show(context, p),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'احجز الآن',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLocationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return _LocationPickerBottomSheet(
          onSelected: (loc) {
            ref.read(deliveryLocationProvider.notifier).setLocation(loc);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم تحديث موقع التوصيل إلى: ${loc.label}'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }
}

class _LocationPickerBottomSheet extends ConsumerStatefulWidget {
  final ValueChanged<DeliveryLocation> onSelected;

  const _LocationPickerBottomSheet({required this.onSelected});

  @override
  ConsumerState<_LocationPickerBottomSheet> createState() =>
      _LocationPickerBottomSheetState();
}

class _LocationPickerBottomSheetState
    extends ConsumerState<_LocationPickerBottomSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  bool _isLoadingGps = false;
  bool _isSearching = false;
  List<LocationSuggestion> _suggestions = [];
  bool _hasSearched = false;
  String? _resolvedGpsAddress;
  Position? _cachedGpsPosition;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _silentResolveCurrentGps();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _silentResolveCurrentGps() async {
    try {
      final locService = ref.read(locationServiceProvider);
      final pos = await locService.getCurrentLocation();
      if (pos != null && mounted) {
        _cachedGpsPosition = pos;
        final address = await locService.reverseGeocode(pos.latitude, pos.longitude);
        if (address != null && address.trim().isNotEmpty && mounted) {
          setState(() {
            _resolvedGpsAddress = address.trim();
          });
        }
      }
    } catch (_) {}
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _suggestions = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final locService = ref.read(locationServiceProvider);
      final currentLoc = ref.read(deliveryLocationProvider);
      final results = await locService.searchPlaces(
        query,
        centerLat: currentLoc.latitude,
        centerLng: currentLoc.longitude,
      );
      if (mounted && _searchCtrl.text.trim() == query) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    });
  }

  Future<void> _pickCurrentGps() async {
    if (_isLoadingGps) return;
    setState(() => _isLoadingGps = true);
    try {
      if (_cachedGpsPosition == null) {
        final allowed = await ensureLocationPermission(context, ref);
        if (!allowed) {
          if (mounted) setState(() => _isLoadingGps = false);
          return;
        }
      }
      final locService = ref.read(locationServiceProvider);
      final pos = _cachedGpsPosition ?? await locService.getCurrentLocation();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر تحديد موقعك الحالي — يرجى تفعيل الـ GPS ومنح الإذن'),
            ),
          );
        }
        return;
      }

      // Reverse geocode to resolve human-readable neighborhood/city
      final addressLabel = _resolvedGpsAddress ??
          await locService.reverseGeocode(pos.latitude, pos.longitude);

      if (!mounted) return;

      final formattedLabel = (addressLabel != null && addressLabel.trim().isNotEmpty)
          ? 'موقعي الحالي ($addressLabel)'
          : 'موقعي الحالي (GPS)';

      widget.onSelected(DeliveryLocation(
        label: formattedLabel,
        latitude: pos.latitude,
        longitude: pos.longitude,
      ));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء تحديد الموقع الحالي')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  void _selectSuggestion(LocationSuggestion suggestion) {
    final label = suggestion.subtitle.isNotEmpty
        ? '${suggestion.title}، ${suggestion.subtitle}'
        : suggestion.title;
    widget.onSelected(DeliveryLocation(
      label: label,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
      governorate: suggestion.governorate,
    ));
    Navigator.of(context).pop();
  }

  void _selectCustomQuery(String query) {
    final currentLoc = ref.read(deliveryLocationProvider);
    widget.onSelected(DeliveryLocation(
      label: query,
      latitude: currentLoc.latitude,
      longitude: currentLoc.longitude,
      governorate: currentLoc.governorate,
    ));
    Navigator.of(context).pop();
  }

  String _getDisplayAddress(DeliveryLocation currentLoc) {
    if (_resolvedGpsAddress != null && _resolvedGpsAddress!.trim().isNotEmpty) {
      return _resolvedGpsAddress!.trim();
    }
    final label = currentLoc.label.trim();
    if (label.startsWith('موقعي الحالي (') && label.endsWith(')')) {
      return label.substring('موقعي الحالي ('.length, label.length - 1).trim();
    }
    if (label.startsWith('موقعك الحالي (') && label.endsWith(')')) {
      return label.substring('موقعك الحالي ('.length, label.length - 1).trim();
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final currentLoc = ref.watch(deliveryLocationProvider);
    final isQueryEmpty = _searchCtrl.text.trim().isEmpty;
    final displayAddress = _getDisplayAddress(currentLoc);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'تحديد موقع التوصيل',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 8),

          // Search Field (Uber/Talabat style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onSubmitted: (val) {
                final trimmed = val.trim();
                if (trimmed.isEmpty) return;
                if (_suggestions.isNotEmpty) {
                  _selectSuggestion(_suggestions.first);
                } else {
                  _selectCustomQuery(trimmed);
                }
              },
              decoration: InputDecoration(
                hintText: 'ابحث عن اسم الشارع، الحي، أو المنطقة...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // 1. Current GPS Location tile (Styled like Uber/Talabat "Use Current Location")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _isLoadingGps ? null : _pickCurrentGps,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    color: AppColors.primary.withValues(alpha: 0.04),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: _isLoadingGps
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: AppColors.primary,
                                size: 19,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'استخدام موقعي الحالي (GPS)',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (displayAddress.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '($displayAddress)',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _isLoadingGps
                                  ? 'جاري تحديد موقعك وقراءة اسم الحي...'
                                  : (displayAddress.isNotEmpty
                                      ? 'الموقع التلقائي — اضغط للاختيار، أو ابحث بالأسفل إذا كان غير دقيق'
                                      : 'تحديد موقعك تلقائياً والتأكد من العنوان عبر الخرائط'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Header label above list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Icon(
                  isQueryEmpty ? Icons.local_fire_department_rounded : Icons.search_rounded,
                  size: 15,
                  color: isQueryEmpty ? Colors.amber.shade800 : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  isQueryEmpty ? 'المناطق المقترحة والأكثر طلباً:' : 'نتائج البحث:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Suggestions / Results ListView
          Flexible(
            child: _buildListContent(isQueryEmpty),
          ),
        ],
      ),
    );
  }

  Widget _buildListContent(bool isQueryEmpty) {
    if (isQueryEmpty) {
      final currentLoc = ref.watch(deliveryLocationProvider);
      final detectedGov = (currentLoc.governorate != null && currentLoc.governorate!.isNotEmpty)
          ? currentLoc.governorate!
          : LocationService.detectGovernorate(currentLoc.latitude, currentLoc.longitude);

      final matchingPlaces = curatedEgyptianPlaces
          .where((p) => p.governorate.contains(detectedGov) || detectedGov.contains(p.governorate))
          .toList();
      final otherPlaces = curatedEgyptianPlaces
          .where((p) => !p.governorate.contains(detectedGov) && !detectedGov.contains(p.governorate))
          .toList();
      final places = matchingPlaces.isNotEmpty
          ? [...matchingPlaces, ...otherPlaces]
          : curatedEgyptianPlaces;

      return ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: places.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final place = places[index];
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            title: Text(
              place.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            subtitle: Text(
              place.subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AppColors.textMuted,
            ),
            onTap: () => _selectSuggestion(place),
          );
        },
      );
    }

    if (_isSearching && _suggestions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 12),
              Text(
                'جاري البحث عن العناوين والأحياء...',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    if (_suggestions.isEmpty && _hasSearched) {
      final query = _searchCtrl.text.trim();
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 8),
              Text(
                'لم نجد نتائج مطابقة لـ "$query"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'يمكنك تحديد هذا النص مباشرة كعنوان للتوصيل:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _selectCustomQuery(query),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text('استخدام "$query" كعنوان'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _suggestions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          title: Text(
            suggestion.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          subtitle: suggestion.subtitle.isNotEmpty
              ? Text(
                  suggestion.subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                )
              : null,
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: AppColors.textMuted,
          ),
          onTap: () => _selectSuggestion(suggestion),
        );
      },
    );
  }
}
