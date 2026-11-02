import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/reservations/presentation/passes_screen.dart'
    show passesControllerProvider;
import 'package:url_launcher/url_launcher.dart';

/// Representation of a medication item assigned to a specific pharmacy in the basket.
class BasketMedicationAssignment {
  final String medication;
  final int requestedQuantity;
  final double price;
  final bool inStock;
  final int availableQuantity;
  final String? inventoryItemId;

  BasketMedicationAssignment({
    required this.medication,
    required this.requestedQuantity,
    required this.price,
    this.inStock = true,
    this.availableQuantity = 1,
    this.inventoryItemId,
  });
}

/// A grouped pharmacy result in the smart greedy distribution.
class PharmacyBasketGroup {
  final String pharmacyId;
  final String pharmacyName;
  final String addressLine;
  final String phone;
  final double distanceKm;
  final double trustScore;
  final List<BasketMedicationAssignment> items;
  bool isBooked;

  PharmacyBasketGroup({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.addressLine,
    required this.phone,
    required this.distanceKm,
    required this.trustScore,
    required this.items,
    this.isBooked = false,
  });

  double get totalPrice =>
      items.fold(0.0, (sum, it) => sum + (it.price * it.requestedQuantity));
}

/// Result of the greedy pharmacy grouping algorithm.
class GreedyGroupingResult {
  final List<PharmacyBasketGroup> groups;
  final List<BatchSearchItemDto> unfulfillableItems;
  final bool isSinglePharmacyAllFound;

  GreedyGroupingResult({
    required this.groups,
    required this.unfulfillableItems,
    required this.isSinglePharmacyAllFound,
  });
}

/// Greedy grouping algorithm:
/// 1. Prioritizes finding a single nearest pharmacy that has ALL requested medications.
/// 2. If no single pharmacy has all medications, greedily selects the nearest pharmacy
///    for medication #1, bundles any other remaining requested medications it has in stock,
///    and repeats for remaining unassigned medications.
GreedyGroupingResult computeGreedyGrouping(
  List<BatchSearchItemDto> requestedItems,
  BatchSearchResponse response,
) {
  if (requestedItems.isEmpty) {
    return GreedyGroupingResult(
      groups: [],
      unfulfillableItems: [],
      isSinglePharmacyAllFound: false,
    );
  }

  // 1. Gather all candidate pharmacies (complete + partial) sorted by distance
  final allPharmacies = [
    ...response.completePharmacies,
    ...response.partialPharmacies,
  ];
  allPharmacies.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

  // Check if ANY single pharmacy has ALL requested items in stock
  for (final bestPharmacy in allPharmacies) {
    final allPresent = requestedItems.every((req) => bestPharmacy.items.any(
          (it) =>
              it.medication.trim().toLowerCase() == req.medication.trim().toLowerCase() &&
              it.inStock,
        ));
    if (allPresent) {
      final assignments = requestedItems.map((req) {
        final detail = bestPharmacy.items.firstWhere(
          (it) =>
              it.medication.trim().toLowerCase() == req.medication.trim().toLowerCase() &&
              it.inStock,
        );
        return BasketMedicationAssignment(
          medication: req.medication,
          requestedQuantity: req.quantity,
          price: detail.price,
          inStock: detail.inStock,
          availableQuantity: detail.availableQuantity,
          inventoryItemId: detail.inventoryItemId,
        );
      }).toList();

      return GreedyGroupingResult(
        groups: [
          PharmacyBasketGroup(
            pharmacyId: bestPharmacy.pharmacyId,
            pharmacyName: bestPharmacy.pharmacyName,
            addressLine: bestPharmacy.addressLine,
            phone: bestPharmacy.phone,
            distanceKm: bestPharmacy.distanceKm,
            trustScore: bestPharmacy.trustScore,
            items: assignments,
          ),
        ],
        unfulfillableItems: [],
        isSinglePharmacyAllFound: true,
      );
    }
  }

  final unassigned = List<BatchSearchItemDto>.from(requestedItems);
  final unfulfillable = <BatchSearchItemDto>[];
  final groups = <PharmacyBasketGroup>[];

  while (unassigned.isNotEmpty) {
    final nextTarget = unassigned.first;

    // Find nearest pharmacy that has nextTarget in stock
    BatchPharmacyResult? chosenPharmacy;
    for (final p in allPharmacies) {
      final hasMed = p.items.any((it) =>
          it.medication.trim().toLowerCase() == nextTarget.medication.trim().toLowerCase() &&
          it.inStock);
      if (hasMed) {
        chosenPharmacy = p;
        break;
      }
    }

    if (chosenPharmacy == null) {
      unfulfillable.add(nextTarget);
      unassigned.removeAt(0);
      continue;
    }

    // Bundle any other unassigned medications also in stock at chosenPharmacy
    final assignedHere = <BasketMedicationAssignment>[];
    final toRemove = <BatchSearchItemDto>[];

    for (final req in unassigned) {
      final match = chosenPharmacy.items.firstWhere(
        (it) =>
            it.medication.trim().toLowerCase() == req.medication.trim().toLowerCase() &&
            it.inStock,
        orElse: () => BatchMedicationDetail(
          medication: '',
          requestedQuantity: 0,
          inStock: false,
          price: 0,
          availableQuantity: 0,
        ),
      );
      if (match.inStock && match.medication.isNotEmpty) {
        assignedHere.add(BasketMedicationAssignment(
          medication: req.medication,
          requestedQuantity: req.quantity,
          price: match.price,
          inStock: true,
          availableQuantity: match.availableQuantity,
          inventoryItemId: match.inventoryItemId,
        ));
        toRemove.add(req);
      }
    }

    for (final r in toRemove) {
      unassigned.remove(r);
    }

    allPharmacies.remove(chosenPharmacy);

    groups.add(PharmacyBasketGroup(
      pharmacyId: chosenPharmacy.pharmacyId,
      pharmacyName: chosenPharmacy.pharmacyName,
      addressLine: chosenPharmacy.addressLine,
      phone: chosenPharmacy.phone,
      distanceKm: chosenPharmacy.distanceKm,
      trustScore: chosenPharmacy.trustScore,
      items: assignedHere,
    ));
  }

  return GreedyGroupingResult(
    groups: groups,
    unfulfillableItems: unfulfillable,
    isSinglePharmacyAllFound: groups.length == 1 && unfulfillable.isEmpty,
  );
}

class BatchSearchResultsScreen extends HookConsumerWidget {
  const BatchSearchResultsScreen({
    super.key,
    required this.items,
    this.sanitizedCropBase64,
  });

  final List<BatchSearchItemDto> items;
  final String? sanitizedCropBase64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentItems = useState<List<BatchSearchItemDto>>(List.from(items));
    final isLoading = useState(true);
    final error = useState<String?>(null);
    final rawSearchData = useState<BatchSearchResponse?>(null);
    final bookedPharmacyIds = useState<Set<String>>({});

    Future<void> executeBatchSearch({List<BatchSearchItemDto>? overrideItems}) async {
      final itemsToSearch = overrideItems ?? currentItems.value;
      if (itemsToSearch.isEmpty) {
        isLoading.value = false;
        rawSearchData.value = null;
        return;
      }

      isLoading.value = true;
      error.value = null;

      try {
        double lat = 30.0444;
        double lng = 31.2357;

        try {
          final pos = await ref.read(locationServiceProvider).getCurrentLocation();
          if (pos != null) {
            lat = pos.latitude;
            lng = pos.longitude;
          }
        } catch (_) {}

        final response = await ref.read(apiClientProvider).batchSearch(
              BatchSearchRequest(
                items: itemsToSearch,
                lat: lat,
                lng: lng,
                radiusKm: 35.0,
              ),
            );
        rawSearchData.value = response;
      } catch (e) {
        error.value = 'تعذر الاتصال بالسيرفر. تأكد من اتصال الإنترنت.';
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      executeBatchSearch();
      return null;
    }, const []);

    void removeItem(String medicationName) {
      final updated = currentItems.value
          .where((i) => i.medication.trim().toLowerCase() != medicationName.trim().toLowerCase())
          .toList();
      currentItems.value = updated;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف «$medicationName» من السلة وإعادة التوزيع'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    void showAddMedicationDialog() {
      final nameCtrl = TextEditingController();
      final qtyCtrl = TextEditingController(text: '1');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'إضافة دواء للبحث الجماعي',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'اسم الدواء (مثلاً Brufen)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.medication_rounded, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'الكمية المطلوبة',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.numbers_rounded, color: AppColors.accentBlue),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                if (name.isNotEmpty) {
                  final updated = List<BatchSearchItemDto>.from(currentItems.value)
                    ..add(BatchSearchItemDto(medication: name, quantity: qty));
                  currentItems.value = updated;
                  Navigator.of(ctx).pop();
                  executeBatchSearch(overrideItems: updated);
                }
              },
              child: const Text('إضافة وبحث',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    Future<void> bookSinglePharmacy(PharmacyBasketGroup group) async {
      final updated = Set<String>.from(bookedPharmacyIds.value)..add(group.pharmacyId);
      bookedPharmacyIds.value = updated;

      for (final it in group.items) {
        if (it.inventoryItemId != null && it.inventoryItemId!.isNotEmpty) {
          try {
            await ref.read(apiClientProvider).createReservation(
                  CreateReservationRequest(
                    inventoryItemId: it.inventoryItemId!,
                    prescriptionCropBase64: sanitizedCropBase64,
                  ),
                );
          } catch (_) {}
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حجز أدوية ${group.pharmacyName} بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      final currentGreedy = rawSearchData.value != null
          ? computeGreedyGrouping(currentItems.value, rawSearchData.value!)
          : null;
      final isAllDone = currentGreedy != null &&
          (currentGreedy.isSinglePharmacyAllFound ||
              updated.length >= currentGreedy.groups.length);

      if (isAllDone && context.mounted) {
        ref.invalidate(passesControllerProvider);
        Navigator.of(context).popUntil((route) => route.isFirst);
        try {
          context.go('/home');
        } catch (_) {}
      }
    }

    Future<void> bookAllPharmacies(List<PharmacyBasketGroup> groups) async {
      final allIds = groups.map((g) => g.pharmacyId).toSet();
      bookedPharmacyIds.value = allIds;

      for (final group in groups) {
        for (final it in group.items) {
          if (it.inventoryItemId != null && it.inventoryItemId!.isNotEmpty) {
            try {
              await ref.read(apiClientProvider).createReservation(
                    CreateReservationRequest(
                      inventoryItemId: it.inventoryItemId!,
                      prescriptionCropBase64: sanitizedCropBase64,
                    ),
                  );
            } catch (_) {}
          }
        }
      }

      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('تم الحجز بالكامل!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تم إرسال طلبات الحجز إلى ${groups.length} صيدليات بنجاح. مدة صلاحية الحجز ساعتان.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
              ...groups.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.local_pharmacy_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${g.pharmacyName} (${g.items.length} أدوية)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('حسنًا',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (context.mounted) {
        ref.invalidate(passesControllerProvider);
        Navigator.of(context).popUntil((route) => route.isFirst);
        try {
          context.go('/home');
        } catch (_) {}
      }
    }

    final greedyResult = rawSearchData.value != null
        ? computeGreedyGrouping(currentItems.value, rawSearchData.value!)
        : null;

    final totalEstimatedPrice = greedyResult?.groups.fold<double>(
            0.0, (sum, g) => sum + g.totalPrice) ??
        0.0;
    final totalAssignedMeds = greedyResult?.groups.fold<int>(
            0, (sum, g) => sum + g.items.length) ??
        0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'نتائج البحث الذكي عن الروشتة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 26),
            tooltip: 'إضافة دواء',
            onPressed: showAddMedicationDialog,
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: isLoading.value
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'جاري مسح مخزون الصيدليات وتوزيع الأدوية الذكي...',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'نبحث أولاً عن صيدلية تجمع كل الأدوية، ثم نوزع الأقرب فالأقرب',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              )
            : error.value != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 54, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(
                            error.value!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: () => executeBatchSearch(),
                            child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                : currentItems.value.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('السلة فارغة حالياً',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: showAddMedicationDialog,
                              icon: const Icon(Icons.add_rounded, color: Colors.white),
                              label: const Text('إضافة دواء', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            ),
                          ],
                        ),
                      )
                    : _buildGreedyResultsView(
                        context,
                        greedyResult!,
                        bookedPharmacyIds.value,
                        onRemoveItem: removeItem,
                        onBookSingle: bookSinglePharmacy,
                      ),
      ),
      bottomNavigationBar: (greedyResult != null && greedyResult.groups.isNotEmpty)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Price summary
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الإجمالي: ${totalEstimatedPrice.toStringAsFixed(0)} ج.م',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            '$totalAssignedMeds أدوية عبر ${greedyResult.groups.length} صيدليات',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Bulk Reserve Button
                    ElevatedButton.icon(
                      key: const ValueKey('batch_reserve_all_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand900,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.done_all_rounded, size: 20),
                      label: Text(
                        'احجز الكل (${greedyResult.groups.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () => bookAllPharmacies(greedyResult.groups),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildGreedyResultsView(
    BuildContext context,
    GreedyGroupingResult result,
    Set<String> bookedIds, {
    required Function(String) onRemoveItem,
    required Function(PharmacyBasketGroup) onBookSingle,
  }) {
    final groups = result.groups;
    final unfulfillable = result.unfulfillableItems;
    final isSingle = result.isSinglePharmacyAllFound;

    if (groups.isEmpty && unfulfillable.isEmpty) {
      return const Center(
        child: Text('لم يتم العثور على أدوية مطابقة'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (sanitizedCropBase64 != null)
          Container(
            key: const ValueKey('batch_sanitized_rx_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🔒 يتم إرفاق صورة الروشتة المقتطعة الخالية من أي بيانات شخصية أو أسماء أطباء لكل صيدلية للتحقق من سلامة وصرف الدواء.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF14532D),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Status banner
        if (isSingle)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.teal.shade800],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🌟 وجدنا كل الأدوية في صيدلية واحدة!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'أقرب صيدلية يتوفر بها كامل طلبك مع إمكانية الحجز المباشر.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.brand900, AppColors.accentBlue],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'توزيع ذكي على ${groups.length} صيدليات قريبة',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'تم تجميع الأدوية حسب الأقرب لك لتقليل عدد المشاوير وتوفير الوقت.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Unfulfillable warning
        if (unfulfillable.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'غير متوفر حالياً (${unfulfillable.length} أدوية):',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unfulfillable.map((u) => u.medication).join('، '),
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Pharmacy Cards
        ...groups.map((group) {
          final isBooked = bookedIds.contains(group.pharmacyId);
          return _GreedyPharmacyGroupCard(
            group: group,
            isBooked: isBooked,
            isSinglePharmacy: isSingle,
            onRemoveMedication: onRemoveItem,
            onBookThisPharmacy: () => onBookSingle(group),
          );
        }),

        const SizedBox(height: 30),
      ],
    );
  }
}

class _GreedyPharmacyGroupCard extends StatelessWidget {
  const _GreedyPharmacyGroupCard({
    required this.group,
    required this.isBooked,
    required this.isSinglePharmacy,
    required this.onRemoveMedication,
    required this.onBookThisPharmacy,
  });

  final PharmacyBasketGroup group;
  final bool isBooked;
  final bool isSinglePharmacy;
  final Function(String) onRemoveMedication;
  final VoidCallback onBookThisPharmacy;

  Future<void> _callPharmacy(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBooked
              ? Colors.green.shade400
              : isSinglePharmacy
                  ? Colors.green.shade300
                  : AppColors.hairline,
          width: (isBooked || isSinglePharmacy) ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name + Badge + Distance
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isBooked
                  ? Colors.green.shade50
                  : isSinglePharmacy
                      ? Colors.green.shade50.withValues(alpha: 0.5)
                      : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isBooked
                        ? Colors.green.shade600
                        : isSinglePharmacy
                            ? Colors.green.shade700
                            : AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.pharmacyName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.near_me_rounded, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${group.distanceKm.toStringAsFixed(1)} كم',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          if (group.addressLine.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text('•', style: TextStyle(color: Colors.grey.shade400)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                group.addressLine,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isBooked
                        ? Colors.green.shade700
                        : isSinglePharmacy
                            ? Colors.green.shade700
                            : AppColors.brand900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isBooked
                        ? '✅ تم الحجز'
                        : isSinglePharmacy
                            ? 'كل السلة (${group.items.length})'
                            : '${group.items.length} أدوية هنا',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items assigned to this pharmacy
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...group.items.map((it) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            it.medication,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        Text(
                          '×${it.requestedQuantity}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                        if (it.price > 0) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${(it.price * it.requestedQuantity).toStringAsFixed(0)} ج.م',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        // Remove medication button (user can remove item from basket)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.redAccent),
                          tooltip: 'حذف من السلة',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => onRemoveMedication(it.medication),
                        ),
                      ],
                    ),
                  );
                }),

                if (group.totalPrice > 0) ...[
                  const Divider(height: 18, color: AppColors.hairline),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إجمالي الصيدلية:',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        '${group.totalPrice.toStringAsFixed(0)} جنيه مصري',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Action buttons: Call + Reserve
                Row(
                  children: [
                    if (group.phone.isNotEmpty)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.phone_rounded, size: 18, color: AppColors.primary),
                        label: const Text('اتصال',
                            style:
                                TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        onPressed: () => _callPharmacy(group.phone),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBooked ? Colors.green.shade600 : AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: isBooked ? null : onBookThisPharmacy,
                        child: Text(
                          isBooked
                              ? 'تم حجز هذه الصيدلية ✓'
                              : isSinglePharmacy
                                  ? 'احجز كل الروشتة الآن ⚡'
                                  : 'احجز أدوية هذه الصيدلية ⚡',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
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
}
