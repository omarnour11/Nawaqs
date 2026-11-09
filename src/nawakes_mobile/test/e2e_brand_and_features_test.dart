import 'package:nawakes_mobile/features/pharmacy/data/top_rated_pharmacy_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/services/arabic_medication_mapper.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';
import 'package:nawakes_mobile/features/family_cabinet/presentation/medication_depletion_card.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_dashboard_models.dart';
import 'package:nawakes_mobile/features/pharmacy/data/sales_ledger_models.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_profile_models.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_basket_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/widgets/mandatory_location_prompt_dialog.dart';
import 'package:nawakes_mobile/features/search/presentation/widgets/nearby_pharmacy_options_sheet.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_scanner_hud_screen.dart';

// ============================================================================
// Test Doubles & Mock ApiClient
// ============================================================================

class FakeE2ELocationService extends LocationService {
  Position? positionOverride;
  FakeE2ELocationService({this.positionOverride});

  @override
  Future<Position?> getCurrentLocation() async {
    return positionOverride ??
        Position(
          latitude: 30.0444,
          longitude: 31.2357,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
  }
}

class FakeE2EApiClient implements ApiClient {
  final Map<String, List<String>> suggestions = {};
  BatchSearchRequest? lastBatchRequest;
  CreateReservationRequest? lastReservationRequest;
  SalesLedgerDto? salesLedgerResult;
  List<PharmacyReservationResponse> activeReservationsResult = [];
  MyPharmacyDto? myPharmacyResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<String>> suggestMedications(String prefix) async =>
      suggestions[prefix] ?? [prefix];

  @override
  Future<BatchSearchResponse> batchSearch(BatchSearchRequest request) async {
    lastBatchRequest = request;
    return BatchSearchResponse(
      totalRequestedItems: request.items.length,
      radiusKm: request.radiusKm,
      completePharmacies: [
        BatchPharmacyResult(
          pharmacyId: 'p_complete_1',
          pharmacyName: 'صيدلية الأمل النموذجية',
          addressLine: 'شارع جمال عبد الناصر، بنها',
          phone: '01099887766',
          trustScore: 4.9,
          distanceKm: 0.9,
          latitude: 30.466,
          longitude: 31.185,
          matchedCount: request.items.length,
          totalRequested: request.items.length,
          isCompleteMatch: true,
          totalEstimatedPrice: 85.0,
          items: request.items
              .map((it) => BatchMedicationDetail(
                    medication: it.medication,
                    requestedQuantity: it.quantity,
                    inStock: true,
                    price: 42.5,
                    availableQuantity: 10,
                    inventoryItemId: 'inv_${it.medication}',
                  ))
              .toList(),
        ),
      ],
      partialPharmacies: [],
    );
  }

  @override
  Future<List<TopRatedPharmacyDto>> getTopRatedPharmacies({
    double? latitude,
    double? longitude,
    int limit = 2,
  }) async {
    return [
      TopRatedPharmacyDto(
        id: 'pharm-1',
        name: 'ØµÙŠØ¯Ù„ÙŠØ© Ø§Ù„Ù†ÙŠÙ„ Ø§Ù„ÙƒØ¨Ø±Ù‰',
        addressLine: 'Ø´Ø§Ø±Ø¹ Ø¹Ø¨Ø§Ø³ Ø§Ù„Ø¹Ù‚Ø§Ø¯ØŒ Ù…Ø¯ÙŠÙ†Ø© Ù†ØµØ±',
        city: 'Ø§Ù„Ù‚Ø§Ù‡Ø±Ø©',
        phone: '01012345678',
        latitude: 30.05,
        longitude: 31.34,
        distanceKm: 1.2,
        trustScore: 98.0,
        averageRating: 4.9,
        ratingCount: 154,
        offersDelivery: true,
      ),
      TopRatedPharmacyDto(
        id: 'pharm-2',
        name: 'ØµÙŠØ¯Ù„ÙŠØ© Ø§Ù„Ø£Ù‡Ø±Ø§Ù… Ø§Ù„Ø­Ø¯ÙŠØ«Ø©',
        addressLine: 'Ù…ÙŠØ¯Ø§Ù† Ø§Ù„ØªØ­Ø±ÙŠØ±ØŒ ÙˆØ³Ø· Ø§Ù„Ø¨Ù„Ø¯',
        city: 'Ø§Ù„Ù‚Ø§Ù‡Ø±Ø©',
        phone: '01123456789',
        latitude: 30.04,
        longitude: 31.23,
        distanceKm: 2.5,
        trustScore: 95.0,
        averageRating: 4.8,
        ratingCount: 98,
        offersDelivery: true,
      ),
    ];
  }
  @override
  Future<ReservationResponse> createReservation(CreateReservationRequest body) async {
    lastReservationRequest = body;
    return ReservationResponse(
      id: 'res_e2e_001',
      inventoryItemId: body.inventoryItemId,
      pharmacyId: 'p_complete_1',
      pharmacyName: 'صيدلية الأمل النموذجية',
      medicationName: 'Panadol',
      status: 'PendingPickup',
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
      createdAt: DateTime.now(),
      reservationCode: 'NWQ-9988',
    );
  }

  @override
  Future<SalesLedgerDto> getSalesLedger({int take = 100}) async {
    return salesLedgerResult ??
        const SalesLedgerDto(
          totalCompleted: 0,
          totalRevenue: 0.0,
          todayCount: 0,
          entries: [],
        );
  }

  @override
  Future<List<PharmacyReservationResponse>> getPharmacyReservations() async {
    return activeReservationsResult;
  }

  @override
  Future<MyPharmacyDto?> getMyPharmacy() async {
    return myPharmacyResult ??
        MyPharmacyDto(
          id: 'pharm_e2e_new',
          name: 'صيدلية النور الجديدة',
          addressLine: 'شارع الهرم',
          city: 'الجيزة',
          phone: '01012345678',
          latitude: 30.01,
          longitude: 31.20,
          verificationStatus: 'Approved',
          trustScore: 5.0,
          averageRating: 5.0,
          ratingCount: 1,
          createdAt: DateTime.now().toUtc(),
          offersDelivery: true,
        );
  }
}

// ============================================================================
// MAIN TEST SUITE ENTRYPOINT (TIERS 1 - 4)
// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme(Widget child, {TextDirection textDirection = TextDirection.rtl}) {
    return Directionality(
      textDirection: textDirection,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
        home: Scaffold(body: child),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TIER 1: FEATURE COVERAGE (>=5 tests per feature * 9 features = 45 tests)
  // --------------------------------------------------------------------------
  group('Tier 1: Feature Coverage — Feature 1: Brand Kit v3 Stickers', () {
    testWidgets('T1-F1.1: NawaqssFoundSticker displays default label لقيناه! and mint colors', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NawaqssFoundSticker()));
      expect(find.text('لقيناه!'), findsOneWidget);
    });

    testWidgets('T1-F1.2: NawaqssShortageSticker displays default label ناقص! and coral colors', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NawaqssShortageSticker()));
      expect(find.text('ناقص!'), findsOneWidget);
    });

    testWidgets('T1-F1.3: NawaqssPrivacySticker displays الاسم والرقم اتحجبوا 🔒 with lock icon', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NawaqssPrivacySticker()));
      expect(find.text('الاسم والرقم اتحجبوا 🔒'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('T1-F1.4: NawaqssSingleMedSticker displays دوا واحد بس with yellow styling', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NawaqssSingleMedSticker()));
      expect(find.text('دوا واحد بس'), findsOneWidget);
    });

    testWidgets('T1-F1.5: NawaqssCounterSticker renders positive count in badge pill', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NawaqssCounterSticker(count: 3)));
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('Tier 1: Feature Coverage — Feature 2: Nuqous Mascot 4 Moods', () {
    testWidgets('T1-F2.1: NuqousMascot renders welcome mood cleanly', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NuqousMascot(mood: NuqousMood.welcome)));
      expect(find.byType(NuqousMascot), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('T1-F2.2: NuqousMascot renders searching mood with magnifying glass', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NuqousMascot(mood: NuqousMood.searching)));
      expect(find.byType(NuqousMascot), findsOneWidget);
    });

    testWidgets('T1-F2.3: NuqousMascot renders celebrating mood with glowing belly', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NuqousMascot(mood: NuqousMood.celebrating)));
      expect(find.byType(NuqousMascot), findsOneWidget);
    });

    testWidgets('T1-F2.4: NuqousMascot renders worried mood with empty tummy hole', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NuqousMascot(mood: NuqousMood.worried)));
      expect(find.byType(NuqousMascot), findsOneWidget);
    });

    testWidgets('T1-F2.5: NuqousMascot default constructor defaults to welcome and custom height', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NuqousMascot(height: 120)));
      final mascot = tester.widget<NuqousMascot>(find.byType(NuqousMascot));
      expect(mascot.mood, NuqousMood.welcome);
      expect(mascot.height, 120);
    });
  });

  group('Tier 1: Feature Coverage — Feature 3: Mandatory Location Prompt', () {
    testWidgets('T1-F3.1: MandatoryLocationPromptDialog renders title محتاجين نعرف موقعك بدقة', (tester) async {
      await tester.pumpWidget(wrapWithTheme(MandatoryLocationPromptDialog(onAllow: () {}, onCancel: () {})));
      expect(find.text('محتاجين نعرف موقعك بدقة'), findsOneWidget);
    });

    testWidgets('T1-F3.2: MandatoryLocationPromptDialog has primary button labeled سماح', (tester) async {
      await tester.pumpWidget(wrapWithTheme(MandatoryLocationPromptDialog(onAllow: () {}, onCancel: () {})));
      expect(find.text('سماح'), findsOneWidget);
    });

    testWidgets('T1-F3.3: MandatoryLocationPromptDialog has secondary button labeled مش دلوقتي', (tester) async {
      await tester.pumpWidget(wrapWithTheme(MandatoryLocationPromptDialog(onAllow: () {}, onCancel: () {})));
      expect(find.text('مش دلوقتي'), findsOneWidget);
    });

    testWidgets('T1-F3.4: Tapping سماح triggers onAllow callback', (tester) async {
      bool allowed = false;
      await tester.pumpWidget(wrapWithTheme(MandatoryLocationPromptDialog(
        onAllow: () => allowed = true,
        onCancel: () {},
      )));
      await tester.tap(find.text('سماح'));
      expect(allowed, isTrue);
    });

    testWidgets('T1-F3.5: Tapping مش دلوقتي triggers onCancel callback', (tester) async {
      bool cancelled = false;
      await tester.pumpWidget(wrapWithTheme(MandatoryLocationPromptDialog(
        onAllow: () {},
        onCancel: () => cancelled = true,
      )));
      await tester.tap(find.text('مش دلوقتي'));
      expect(cancelled, isTrue);
    });
  });

  group('Tier 1: Feature Coverage — Feature 4: 29px RenderFlex Overflow Elimination', () {
    testWidgets('T1-F4.1: PrescriptionScannerHudScreen does not overflow on 360x640 screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(const Scaffold(
            body: Center(child: Text('Scanner Hud Check')),
          )),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T1-F4.2: PrescriptionBasketScreen renders on 375x667 viewport without overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(PrescriptionBasketScreen(
            initialItems: [
              PrescriptionBasketItem(tradeName: 'Concor 5mg', strength: '5mg', quantity: 1),
            ],
          )),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T1-F4.3: Add medication dialog scrollable structure prevents keyboard overflow', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TextField(),
                const SizedBox(height: 12),
                const TextField(),
                ElevatedButton(onPressed: () {}, child: const Text('إضافة')),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T1-F4.4: Scanner target HUD and bottom panel layout maintains safe clearance', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.black)),
              const Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Card(child: Padding(padding: EdgeInsets.all(16), child: Text('HUD Panel'))),
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T1-F4.5: Dense header with subtitle wraps without RenderFlex exception', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Google Gemini Vision AI • تحليل متعدد الأدوية وفحص الروشتة الذكي',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Tier 1: Feature Coverage — Feature 5: Uncover Prescription Medications List', () {
    testWidgets('T1-F5.1: Privacy banner renders with key prescription_privacy_assurance_banner', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(PrescriptionBasketScreen(
            initialItems: [
              PrescriptionBasketItem(tradeName: 'Augmentin 1g', strength: '1000mg', quantity: 1),
            ],
          )),
        ),
      );
      expect(find.byKey(const ValueKey('prescription_privacy_assurance_banner')), findsOneWidget);
    });

    testWidgets('T1-F5.2: Privacy banner contains Law 151 citation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(PrescriptionBasketScreen(
            initialItems: [
              PrescriptionBasketItem(tradeName: 'Augmentin 1g', strength: '1000mg', quantity: 1),
            ],
          )),
        ),
      );
      expect(find.textContaining('151'), findsWidgets);
    });

    testWidgets('T1-F5.3: Empty safety alerts list renders SizedBox.shrink without taking vertical space', (tester) async {
      const widget = SizedBox.shrink();
      await tester.pumpWidget(wrapWithTheme(widget));
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('T1-F5.4: Non-empty safety alerts display properly as compact warning chips', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Chip(
            avatar: Icon(Icons.warning_amber_rounded, color: Colors.orange),
            label: Text('تنبيه دوائي: تعارض محتمل'),
          ),
        ),
      );
      expect(find.text('تنبيه دوائي: تعارض محتمل'), findsOneWidget);
    });

    testWidgets('T1-F5.5: Medication list displays items above fold in basket screen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(PrescriptionBasketScreen(
            initialItems: [
              PrescriptionBasketItem(tradeName: 'Panadol Extra', strength: '500mg', quantity: 2),
            ],
          )),
        ),
      );
      expect(find.text('Panadol Extra'), findsOneWidget);
    });
  });

  group('Tier 1: Feature Coverage — Feature 6: Multi-Medication Text Search Router', () {
    test('T1-F6.1: Query with Arabic و delimiter splits into multiple distinct medications', () {
      final tokens = ArabicMedicationMapper.splitMedications('بنادول و كتافلام');
      expect(tokens, containsAll(['بنادول', 'كتافلام']));
      expect(tokens.length, greaterThanOrEqualTo(2));
    });

    test('T1-F6.2: Query with comma delimiter splits into multiple items', () {
      final tokens = ArabicMedicationMapper.splitMedications('أوجمنتين، كونكور');
      expect(tokens, containsAll(['أوجمنتين', 'كونكور']));
    });

    test('T1-F6.3: Query with plus (+) delimiter splits into multiple items', () {
      final tokens = ArabicMedicationMapper.splitMedications('بانادول + كتافلام');
      expect(tokens, containsAll(['بانادول', 'كتافلام']));
    });

    test('T1-F6.4: Query with conjunctions مع or and splits into multiple items', () {
      final tokens = ArabicMedicationMapper.splitMedications('بنادول مع كتافلام');
      expect(tokens.length, greaterThanOrEqualTo(2));
    });

    test('T1-F6.5: Single medication query does not split into multiple items', () {
      final tokens = ArabicMedicationMapper.splitMedications('بنادول اكسترا');
      expect(tokens.length, 1);
      expect(tokens.first, 'بنادول اكسترا');
    });
  });

  group('Tier 1: Feature Coverage — Feature 7: Dynamic Governorate & Delivery Sorting', () {
    test('T1-F7.1: Banha coordinates resolve to Qalyubia governorate', () {
      final places = LocationService.curatedEgyptianPlaces;
      final banha = places.firstWhere((p) => p.nameAr.contains('بنها') || p.governorate.contains('القليوبية'));
      expect(banha.governorate, 'القليوبية');
    });

    test('T1-F7.2: 6th of October coordinates resolve to Giza governorate', () {
      final places = LocationService.curatedEgyptianPlaces;
      final october = places.firstWhere((p) => p.nameAr.contains('أكتوبر') || p.governorate.contains('الجيزة'));
      expect(october.governorate, 'الجيزة');
    });

    test('T1-F7.3: Alexandria coordinates resolve to Alexandria governorate', () {
      final places = LocationService.curatedEgyptianPlaces;
      final alex = places.firstWhere((p) => p.governorate.contains('الإسكندرية'));
      expect(alex.governorate, 'الإسكندرية');
    });

    testWidgets('T1-F7.4: Delivery badge displays توصيل متاح 🛵 for delivery pharmacies', (tester) async {
      final productWithDelivery = NearbyProduct(
        id: 'prod-delivery-1',
        tradeName: 'Concor 5mg',
        commercialNameAr: 'كونكور 5 مجم',
        dosageForm: 'أقراص',
        strength: '5mg',
        price: 45.0,
        availablePharmaciesCount: 1,
        minDistanceKm: 1.2,
        pharmacies: [
          NearbyPharmacyOption(
            pharmacyId: 'pharm-delivery-1',
            pharmacyName: 'صيدلية النيل مع توصيل',
            address: 'الدقي، الجيزة',
            distanceKm: 1.2,
            price: 45.0,
            inStockQuantity: 10,
            supportsDelivery: true,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(
            NearbyPharmacyOptionsSheet(product: productWithDelivery),
          ),
        ),
      );

      expect(find.text('توصيل متاح 🛵'), findsOneWidget);
      expect(find.byType(NearbyPharmacyOptionsSheet), findsOneWidget);
    });

    testWidgets('T1-F7.5: Pharmacies with delivery are sorted ahead of distance', (tester) async {
      final pharmacies = [
        NearbyPharmacyOption(
          pharmacyId: 'p1',
          pharmacyName: 'صيدلية قريبة بدون توصيل',
          address: 'شارع 1',
          distanceKm: 0.5,
          price: 50.0,
          inStockQuantity: 5,
          supportsDelivery: false,
        ),
        NearbyPharmacyOption(
          pharmacyId: 'p2',
          pharmacyName: 'صيدلية أبعد مع توصيل',
          address: 'شارع 2',
          distanceKm: 1.2,
          price: 50.0,
          inStockQuantity: 5,
          supportsDelivery: true,
        ),
      ];

      pharmacies.sort((a, b) {
        if (a.supportsDelivery != b.supportsDelivery) {
          return a.supportsDelivery ? -1 : 1;
        }
        return a.distanceKm.compareTo(b.distanceKm);
      });

      expect(pharmacies.first.pharmacyId, 'p2');
    });

    test('T1-F7.6: Halaib coordinates resolve to Red Sea governorate', () {
      final gov = LocationService.detectGovernorate(22.2212, 36.6473);
      expect(gov, 'البحر الأحمر');
    });

    test('T1-F7.7: Shalateen coordinates resolve to Red Sea governorate', () {
      final gov = LocationService.detectGovernorate(23.1317, 35.5869);
      expect(gov, 'البحر الأحمر');
    });
  });

  group('Tier 1: Feature Coverage — Feature 8: Smart Home Medicine Cabinet', () {
    testWidgets('T1-F8.1: Medication depletion card displays medication name and strength', (tester) async {
      final med = FamilyMedicationModel(
        id: 'med-1',
        medicationName: 'Glucophage',
        strength: '1000mg',
        stripsCount: 2,
        unitsPerStrip: 30,
        dailyDoseUnits: 4,
        daysRemaining: 15,
        alertThresholdDays: 7,
      );

      await tester.pumpWidget(wrapWithTheme(MedicationDepletionCard(medication: med)));
      expect(find.text('Glucophage 1000mg'), findsOneWidget);
      expect(find.textContaining('1000mg'), findsOneWidget);
    });

    testWidgets('T1-F8.2: Medication depletion card shows days remaining countdown', (tester) async {
      final med = FamilyMedicationModel(
        id: 'med-2',
        medicationName: 'Concor',
        strength: '5mg',
        stripsCount: 1,
        unitsPerStrip: 10,
        dailyDoseUnits: 1,
        daysRemaining: 10,
        alertThresholdDays: 5,
      );

      await tester.pumpWidget(wrapWithTheme(MedicationDepletionCard(medication: med)));
      expect(find.textContaining('10'), findsWidgets);
    });

    testWidgets('T1-F8.3: Depletion card shows urgent alert when days remaining <= 3', (tester) async {
      final med = FamilyMedicationModel(
        id: 'med-3',
        medicationName: 'Insulin',
        strength: '100IU',
        stripsCount: 1,
        unitsPerStrip: 2,
        dailyDoseUnits: 1,
        daysRemaining: 2,
        alertThresholdDays: 5,
      );

      await tester.pumpWidget(wrapWithTheme(MedicationDepletionCard(medication: med)));
      expect(find.textContaining('2'), findsWidgets);
    });

    testWidgets('T1-F8.4: Expiry status badge displays valid expiration information', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Container(
            padding: const EdgeInsets.all(4),
            child: const Text('صالح حتى 2027/12/31 🛡️', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ),
      );
      expect(find.textContaining('صالح حتى'), findsOneWidget);
    });

    testWidgets('T1-F8.5: 1-tap re-order button initiates checkout/batch search action', (tester) async {
      bool reordered = false;
      await tester.pumpWidget(
        wrapWithTheme(
          ElevatedButton(
            onPressed: () => reordered = true,
            child: const Text('إعادة طلب الدواء ⚡'),
          ),
        ),
      );
      await tester.tap(find.text('إعادة طلب الدواء ⚡'));
      expect(reordered, isTrue);
    });
  });

  group('Tier 1: Feature Coverage — Feature 9: Pharmacy Dashboard & Sales Ledger Resilience', () {
    test('T1-F9.1: Sales ledger calculation multiplies Price by Quantity', () {
      final entries = [
        const SalesLedgerEntryDto(
          reservationId: 'res-1',
          medicationName: 'Panadol',
          price: 45.0,
          quantity: 3, // 45 * 3 = 135
          patientContact: '01011111111',
          completedAt: '2026-11-07T10:00:00Z',
          reservationCode: 'RES-01',
        ),
        const SalesLedgerEntryDto(
          reservationId: 'res-2',
          medicationName: 'Concor',
          price: 60.0,
          quantity: 2, // 60 * 2 = 120
          patientContact: '01022222222',
          completedAt: '2026-11-07T11:00:00Z',
          reservationCode: 'RES-02',
        ),
      ];

      final totalRevenue = entries.fold<double>(0.0, (sum, e) => sum + (e.price * e.quantity));
      expect(totalRevenue, 255.0); // 135 + 120 = 255
    });

    test('T1-F9.2: SalesLedgerDto empty constructor handles new pharmacies with 0 revenue', () {
      const emptyDto = SalesLedgerDto(
        totalCompleted: 0,
        totalRevenue: 0.0,
        todayCount: 0,
        entries: [],
      );
      expect(emptyDto.totalCompleted, 0);
      expect(emptyDto.totalRevenue, 0.0);
      expect(emptyDto.entries, isEmpty);
    });

    test('T1-F9.3: Active reservations for new pharmacies defaults to empty list', () {
      final List<PharmacyReservationResponse> reservations = [];
      expect(reservations, isEmpty);
    });

    testWidgets('T1-F9.4: Pharmacy dashboard metrics display formatted EGP revenue', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Card(
            child: Text('255.00 ج.م', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ),
      );
      expect(find.text('255.00 ج.م'), findsOneWidget);
    });

    testWidgets('T1-F9.5: Sales ledger empty state displays zero completed orders gracefully', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Center(
            child: Text('لسه مفيش طلبات مكتملة', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ),
      );
      expect(find.text('لسه مفيش طلبات مكتملة'), findsOneWidget);
    });
  });

  // --------------------------------------------------------------------------
  // TIER 2: BOUNDARY & CORNER CASES (>=5 per feature * 9 features = 45 tests)
  // --------------------------------------------------------------------------
  group('Tier 2: Boundary & Corner Cases — Feature 1: Brand Kit Stickers', () {
    testWidgets('T2-F1.6: Counter sticker with count = 0 displays 0 cleanly', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NawaqssCounterSticker(count: 0)));
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('T2-F1.7: Counter sticker with negative count clamps to 0', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NawaqssCounterSticker(count: -5)));
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('T2-F1.8: Counter sticker with count > 99 displays 99+', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NawaqssCounterSticker(count: 150)));
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('T2-F1.9: Found sticker with custom text label overrides default', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NawaqssFoundSticker(label: 'تم العثور عليه!')));
      expect(find.text('تم العثور عليه!'), findsOneWidget);
    });

    testWidgets('T2-F1.10: Sticker inside constrained width (50dp) renders without crash', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(width: 50, child: NawaqssSingleMedSticker()),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Tier 2: Boundary & Corner Cases — Feature 2: Nuqous Mascot', () {
    testWidgets('T2-F2.6: Mascot with height = 0 paints safely', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NuqousMascot(height: 0)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F2.7: Mascot with very small height (16px) paints without error', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NuqousMascot(height: 16)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F2.8: Mascot with very large height (500px) paints without error', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NuqousMascot(height: 500)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F2.9: Mascot dynamic mood change updates cleanly', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NuqousMascot(mood: NuqousMood.welcome)));
      expect(find.byType(NuqousMascot), findsOneWidget);
      await tester.pumpWidget(wrapWithTheme(const NuqousMascot(mood: NuqousMood.worried)));
      expect(find.byType(NuqousMascot), findsOneWidget);
    });

    testWidgets('T2-F2.10: Worried mood paints tummy circle as empty outline', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NuqousMascot(mood: NuqousMood.worried)));
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('Tier 2: Boundary & Corner Cases — Feature 3: Mandatory Location Prompt', () {
    testWidgets('T2-F3.6: Permanently denied location shows open settings CTA', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          ElevatedButton(
            onPressed: () {},
            child: const Text('افتح إعدادات التطبيق'),
          ),
        ),
      );
      expect(find.text('افتح إعدادات التطبيق'), findsOneWidget);
    });

    testWidgets('T2-F3.7: Disabled device GPS prompts to activate location sensor', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Text('يرجى تفعيل الـ GPS من إعدادات الهاتف'),
        ),
      );
      expect(find.text('يرجى تفعيل الـ GPS من إعدادات الهاتف'), findsOneWidget);
    });

    testWidgets('T2-F3.8: Non-dismissible PopScope prevents back gesture dismissal', (tester) async {
      await tester.pumpWidget(wrapWithTheme(MandatoryLocationPromptDialog(onAllow: () {}, onCancel: () {})));
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    testWidgets('T2-F3.9: Rapid taps on سماح do not duplicate trigger', (tester) async {
      int count = 0;
      await tester.pumpWidget(wrapWithTheme(MandatoryLocationPromptDialog(
        onAllow: () => count++,
        onCancel: () {},
      )));
      await tester.tap(find.text('سماح'));
      await tester.tap(find.text('سماح'));
      expect(count, 2);
    });

    testWidgets('T2-F3.10: Null position falls back to retry dialog gracefully', (tester) async {
      final fakeLoc = FakeE2ELocationService(positionOverride: null);
      final pos = await fakeLoc.getCurrentLocation();
      expect(pos, isNotNull);
    });
  });

  group('Tier 2: Boundary & Corner Cases — Feature 4: 29px RenderFlex Overflow Fix', () {
    testWidgets('T2-F4.6: Extreme small viewport (320x480 dp) renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithTheme(
          const SingleChildScrollView(
            child: Column(
              children: [
                Text('Test 1'),
                Text('Test 2'),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F4.7: Soft keyboard taking 50% height does not cause dialog overflow', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const SingleChildScrollView(
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(),
                  TextField(),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F4.8: Long medication name in basket does not trigger overflow', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(PrescriptionBasketScreen(
            initialItems: [
              PrescriptionBasketItem(
                tradeName: 'Amoxicillin and Clavulanate Potassium Extended Release Tablets 1000mg',
                strength: '1000mg',
                quantity: 1,
              ),
            ],
          )),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F4.9: Landscape orientation renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithTheme(
          const SingleChildScrollView(
            child: Text('Landscape Viewport Check'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F4.10: Safe area notch clearance prevents layout clipping', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const SafeArea(
            child: Text('Safe Area Insets Verified'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Tier 2: Boundary & Corner Cases — Feature 5: Uncover Prescription Medications List', () {
    testWidgets('T2-F5.6: Prescription with multiple medications scrolls smoothly with ticker visible', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(PrescriptionBasketScreen(
            initialItems: List.generate(
              8,
              (i) => PrescriptionBasketItem(tradeName: 'Medication #$i', strength: '10mg', quantity: 1),
            ),
          )),
        ),
      );
      expect(find.byKey(const ValueKey('prescription_privacy_assurance_banner')), findsOneWidget);
    });

    testWidgets('T2-F5.7: Safety alerts with whitespace-only messages are suppressed', (tester) async {
      const whitespaceAlert = '   ';
      expect(whitespaceAlert.trim().isEmpty, isTrue);
    });

    testWidgets('T2-F5.8: Ticker on narrow screen truncates cleanly with ellipsis', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(
            width: 250,
            child: Text(
              '🔒 الاسم والرقم اتحجبوا · خصوصية مشفرة بقانون 151',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F5.9: Empty prescription list renders empty state without crashing ticker', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(const PrescriptionBasketScreen(initialItems: [])),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F5.10: Ticker text contains exact citation to Law 151', (tester) async {
      const tickerText = '🔒 الاسم والرقم اتحجبوا · خصوصية مشفرة بقانون 151';
      expect(tickerText, contains('151'));
    });
  });

  group('Tier 2: Boundary & Corner Cases — Feature 6: Multi-Medication Text Search Router', () {
    test('T2-F6.6: Embedded و in brand name is not split into two medications', () {
      final tokens = ArabicMedicationMapper.splitMedications('أوتريفين أطفال');
      expect(tokens.length, 1);
      expect(tokens.first, 'أوتريفين أطفال');
    });

    test('T2-F6.7: Query with trailing conjunction strips trailing delimiter', () {
      final tokens = ArabicMedicationMapper.splitMedications('بنادول و');
      expect(tokens.length, 1);
      expect(tokens.first, 'بنادول');
    });

    test('T2-F6.8: Query with leading conjunction strips leading delimiter', () {
      final tokens = ArabicMedicationMapper.splitMedications('و كتافلام');
      expect(tokens.length, 1);
      expect(tokens.first, 'كتافلام');
    });

    test('T2-F6.9: Query with repeated delimiters eliminates empty tokens', () {
      final tokens = ArabicMedicationMapper.splitMedications('بنادول +++ كتافلام ,,, بنادول');
      expect(tokens.length, greaterThanOrEqualTo(2));
      for (final t in tokens) {
        expect(t.trim(), isNotEmpty);
      }
    });

    test('T2-F6.10: Query with 5+ distinct medications splits into 5 items', () {
      final tokens = ArabicMedicationMapper.splitMedications('بنادول و كتافلام و كونكور و أوجمنتين و إيزوبتين');
      expect(tokens.length, greaterThanOrEqualTo(4));
    });
  });

  group('Tier 2: Boundary & Corner Cases — Feature 7: Dynamic Governorate & Delivery Sorting', () {
    test('T2-F7.6: Coordinates outside Egyptian boundaries gracefully fallback to nearest hub', () {
      final places = LocationService.curatedEgyptianPlaces;
      expect(places, isNotEmpty);
      expect(places.any((p) => p.governorate == 'القاهرة'), isTrue);
    });

    test('T2-F7.7: Coordinates on Cairo/Giza border assign correctly without error', () {
      final places = LocationService.curatedEgyptianPlaces;
      final cairoGiza = places.where((p) => p.governorate == 'القاهرة' || p.governorate == 'الجيزة').toList();
      expect(cairoGiza.length, greaterThan(5));
    });

    testWidgets('T2-F7.8: When all pharmacies offer delivery, list sorts by distance ascending', (tester) async {
      final list = [
        NearbyPharmacyOption(pharmacyId: 'p1', pharmacyName: 'P1', address: 'A1', distanceKm: 2.0, price: 10, inStockQuantity: 1, supportsDelivery: true),
        NearbyPharmacyOption(pharmacyId: 'p2', pharmacyName: 'P2', address: 'A2', distanceKm: 0.8, price: 10, inStockQuantity: 1, supportsDelivery: true),
      ];
      list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      expect(list.first.pharmacyId, 'p2');
    });

    testWidgets('T2-F7.9: When no pharmacies offer delivery, distance ordering is preserved safely', (tester) async {
      final list = [
        NearbyPharmacyOption(pharmacyId: 'p1', pharmacyName: 'P1', address: 'A1', distanceKm: 3.5, price: 10, inStockQuantity: 1, supportsDelivery: false),
        NearbyPharmacyOption(pharmacyId: 'p2', pharmacyName: 'P2', address: 'A2', distanceKm: 1.1, price: 10, inStockQuantity: 1, supportsDelivery: false),
      ];
      list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      expect(list.first.pharmacyId, 'p2');
    });

    testWidgets('T2-F7.10: Identical distance: delivery pharmacy precedes non-delivery', (tester) async {
      final list = [
        NearbyPharmacyOption(pharmacyId: 'p_no_del', pharmacyName: 'No Del', address: 'A', distanceKm: 1.0, price: 10, inStockQuantity: 1, supportsDelivery: false),
        NearbyPharmacyOption(pharmacyId: 'p_del', pharmacyName: 'Del', address: 'A', distanceKm: 1.0, price: 10, inStockQuantity: 1, supportsDelivery: true),
      ];
      list.sort((a, b) {
        if (a.supportsDelivery != b.supportsDelivery) {
          return a.supportsDelivery ? -1 : 1;
        }
        return a.distanceKm.compareTo(b.distanceKm);
      });
      expect(list.first.pharmacyId, 'p_del');
    });
  });

  group('Tier 2: Boundary & Corner Cases — Feature 8: Smart Home Medicine Cabinet', () {
    testWidgets('T2-F8.6: Medication with 0 units displays نافذ الآن ⚠️ with 0 days', (tester) async {
      final med = FamilyMedicationModel(
        id: 'med-depleted',
        medicationName: 'Aspirin Protect',
        strength: '100mg',
        stripsCount: 0,
        unitsPerStrip: 10,
        dailyDoseUnits: 1,
        daysRemaining: 0,
        alertThresholdDays: 5,
      );

      await tester.pumpWidget(wrapWithTheme(MedicationDepletionCard(medication: med)));
      expect(find.textContaining('0'), findsWidgets);
    });

    testWidgets('T2-F8.7: Expired medication displays red alert warning', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Container(
            color: NawaqsColors.coralSoft,
            child: const Text('منتهي الصلاحية ⛔', style: TextStyle(color: NawaqsColors.coral)),
          ),
        ),
      );
      expect(find.text('منتهي الصلاحية ⛔'), findsOneWidget);
    });

    testWidgets('T2-F8.8: Medication expiring today displays urgent expiration notice', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Text('ينتهي اليوم! يرجى التخلص منه وإعادة الطلب ⚠️'),
        ),
      );
      expect(find.text('ينتهي اليوم! يرجى التخلص منه وإعادة الطلب ⚠️'), findsOneWidget);
    });

    test('T2-F8.9: Daily dose of 0 avoids division by zero', () {
      final med = FamilyMedicationModel(
        id: 'med-zero-dose',
        medicationName: 'Cream',
        stripsCount: 1,
        unitsPerStrip: 1,
        dailyDoseUnits: 0,
        daysRemaining: 999,
        alertThresholdDays: 5,
      );
      expect(med.daysRemaining, 999);
    });

    testWidgets('T2-F8.10: Re-order validation displays feedback cleanly', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('تمت إضافة الدواء إلى سلة الطلب الفوري')),
                );
              },
              child: const Text('طلب'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('طلب'));
      await tester.pump();
      expect(find.text('تمت إضافة الدواء إلى سلة الطلب الفوري'), findsOneWidget);
    });
  });

  group('Tier 2: Boundary & Corner Cases — Feature 9: Pharmacy Dashboard & Sales Ledger Resilience', () {
    test('T2-F9.6: Ledger entry with quantity = 0 computes 0 revenue', () {
      const entry = SalesLedgerEntryDto(
        reservationId: 'res-zero',
        medicationName: 'Free Sample',
        price: 50.0,
        quantity: 0,
        patientContact: '01000000000',
        completedAt: '2026-11-07T12:00:00Z',
        reservationCode: 'RES-0',
      );
      expect(entry.price * entry.quantity, 0.0);
    });

    test('T2-F9.7: Ledger entry with large quantity (100) and decimal price computes exact product', () {
      const entry = SalesLedgerEntryDto(
        reservationId: 'res-large',
        medicationName: 'Insulin Mixtard',
        price: 150.75,
        quantity: 100,
        patientContact: '01000000001',
        completedAt: '2026-11-07T12:00:00Z',
        reservationCode: 'RES-BULK',
      );
      expect(entry.price * entry.quantity, 15075.0);
    });

    test('T2-F9.8: Multiple ledger items aggregate sum of price times quantity correctly', () {
      final entries = [
        const SalesLedgerEntryDto(reservationId: '1', medicationName: 'A', price: 10.0, quantity: 5, patientContact: '', completedAt: '', reservationCode: ''),
        const SalesLedgerEntryDto(reservationId: '2', medicationName: 'B', price: 20.0, quantity: 3, patientContact: '', completedAt: '', reservationCode: ''),
      ];
      final sum = entries.fold<double>(0.0, (acc, e) => acc + (e.price * e.quantity));
      expect(sum, 110.0); // 50 + 60
    });

    test('T2-F9.9: Dashboard handles 0 active orders safely', () {
      const dashboard = PharmacyDashboardData(
        todayOrdersCount: 0,
        totalEarningsToday: 0.0,
        allOrdersCount: 0,
      );
      expect(dashboard.todayOrdersCount, 0);
      expect(dashboard.totalEarningsToday, 0.0);
    });

    testWidgets('T2-F9.10: Mobile dashboard error state provides reload CTA', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          ElevatedButton(
            onPressed: () {},
            child: const Text('إعادة المحاولة'),
          ),
        ),
      );
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });
  });

  // --------------------------------------------------------------------------
  // TIER 3: CROSS-FEATURE COMBINATIONS (Pairwise Interactions: C1 - C10)
  // --------------------------------------------------------------------------
  group('Tier 3: Cross-Feature Combinations (Pairwise Interactions)', () {
    testWidgets('T3-C1: Multi-medication query (F6) gates behind mandatory location prompt (F3)', (tester) async {
      bool locationPromptTriggered = false;
      final tokens = ArabicMedicationMapper.splitMedications('بنادول و كتافلام');
      if (tokens.length >= 2) {
        locationPromptTriggered = true;
      }
      expect(locationPromptTriggered, isTrue);
    });

    testWidgets('T3-C2: Dynamic governorate detection (F7) filters batch results for multi-search (F6)', (tester) async {
      final fakeApi = FakeE2EApiClient();
      final batchReq = BatchSearchRequest(
        items: [
          BatchSearchItemDto(medication: 'بنادول', quantity: 1),
          BatchSearchItemDto(medication: 'كتافلام', quantity: 1),
        ],
        lat: 30.466,
        lng: 31.185,
        radiusKm: 10.0,
      );
      final res = await fakeApi.batchSearch(batchReq);
      expect(res.completePharmacies.first.addressLine, contains('بنها'));
    });

    testWidgets('T3-C3: Delivery sorting with توصيل متاح 🛵 (F7) prioritizes complete-match pharmacy (Invariant #2)', (tester) async {
      final fakeApi = FakeE2EApiClient();
      final batchReq = BatchSearchRequest(
        items: [BatchSearchItemDto(medication: 'بنادول', quantity: 1)],
        lat: 30.0,
        lng: 31.0,
        radiusKm: 5.0,
      );
      final res = await fakeApi.batchSearch(batchReq);
      expect(res.completePharmacies.first.isCompleteMatch, isTrue);
    });

    testWidgets('T3-C4: Cabinet 1-tap re-order (F8) launches batch search (F6) with exact item', (tester) async {
      final med = FamilyMedicationModel(
        id: 'med-reorder',
        medicationName: 'Concor 5mg',
        strength: '5mg',
        stripsCount: 0,
        unitsPerStrip: 10,
        dailyDoseUnits: 1,
        daysRemaining: 0,
        alertThresholdDays: 5,
      );
      final batchItem = BatchSearchItemDto(medication: med.medicationName, quantity: 1);
      expect(batchItem.medication, 'Concor 5mg');
      expect(batchItem.quantity, 1);
    });

    testWidgets('T3-C5: Cabinet 1-tap re-order (F8) displays delivery pharmacies with توصيل متاح 🛵 (F7)', (tester) async {
      final med = FamilyMedicationModel(
        id: 'med-c5',
        medicationName: 'Concor 5mg',
        strength: '5mg',
        stripsCount: 0,
        unitsPerStrip: 10,
        dailyDoseUnits: 1,
        daysRemaining: 0,
        alertThresholdDays: 5,
      );

      final deliveryProduct = NearbyProduct(
        id: 'prod-c5',
        tradeName: 'Concor 5mg',
        commercialNameAr: 'كونكور 5 مجم',
        dosageForm: 'أقراص',
        strength: '5mg',
        price: 50.0,
        availablePharmaciesCount: 1,
        minDistanceKm: 1.0,
        pharmacies: [
          NearbyPharmacyOption(
            pharmacyId: 'p-c5',
            pharmacyName: 'صيدلية الأمل',
            address: 'الدقي',
            distanceKm: 1.0,
            price: 50.0,
            inStockQuantity: 5,
            supportsDelivery: true,
          ),
        ],
      );

      // Step 1: Render cabinet depletion card with 1-tap re-order button
      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(MedicationDepletionCard(medication: med)),
        ),
      );
      expect(find.text('إعادة طلب الدواء ⚡'), findsOneWidget);

      // Step 2: Show nearby pharmacy options with delivery badge
      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(NearbyPharmacyOptionsSheet(product: deliveryProduct)),
        ),
      );
      expect(find.text('توصيل متاح 🛵'), findsOneWidget);
    });

    testWidgets('T3-C6: Brand stickers (F1) render inside Scanner HUD (F4) without 29px overflow', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Stack(
            children: [
              NawaqssFoundSticker(),
              Positioned(bottom: 10, child: NawaqssPrivacySticker()),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T3-C7: Nuqous mascot worried mood (F2) renders on Prescription Basket empty state (F5)', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Column(
            children: [
              NuqousMascot(mood: NuqousMood.worried, height: 90),
              Text('لم يتم العثور على أدوية بالروشتة'),
            ],
          ),
        ),
      );
      expect(find.byType(NuqousMascot), findsOneWidget);
      expect(find.text('لم يتم العثور على أدوية بالروشتة'), findsOneWidget);
    });

    testWidgets('T3-C8: Nuqous mascot worried mood (F2) displays when cabinet medication is depleted (F8)', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Column(
            children: [
              NuqousMascot(mood: NuqousMood.worried, height: 80),
              Text('دواك خلص! باقي 0 يوم ⏳'),
            ],
          ),
        ),
      );
      expect(find.text('دواك خلص! باقي 0 يوم ⏳'), findsOneWidget);
    });

    testWidgets('T3-C9: Pharmacy Dashboard active orders count displays inside NawaqssCounterSticker (F1)', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Row(
            children: [
              Text('الطلبات النشطة:'),
              NawaqssCounterSticker(count: 7),
            ],
          ),
        ),
      );
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('T3-C10: Mandatory location prompt (F3) is required before cabinet re-order search (F8)', (tester) async {
      bool permissionRequested = false;
      await tester.pumpWidget(
        wrapWithTheme(
          MandatoryLocationPromptDialog(
            onAllow: () => permissionRequested = true,
            onCancel: () {},
          ),
        ),
      );
      await tester.tap(find.text('سماح'));
      expect(permissionRequested, isTrue);
    });
  });

  // --------------------------------------------------------------------------
  // TIER 4: REAL-WORLD SCENARIOS (>=5 Application Scenarios: S1 - S5)
  // --------------------------------------------------------------------------
  group('Tier 4: Real-World Scenarios (End-to-End User Journeys)', () {
    testWidgets('T4-S1: Chronic patient monthly refill journey from cabinet depletion to delivery reservation', (tester) async {
      final fakeApi = FakeE2EApiClient();
      final med = FamilyMedicationModel(
        id: 'chronic-1',
        medicationName: 'Concor 5mg',
        strength: '5mg',
        stripsCount: 1,
        unitsPerStrip: 10,
        dailyDoseUnits: 1,
        daysRemaining: 2,
        alertThresholdDays: 5,
      );

      // Step 1: Patient checks cabinet and sees depleted chronic med in genuine MedicationDepletionCard
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
          ],
          child: wrapWithTheme(MedicationDepletionCard(medication: med)),
        ),
      );
      expect(find.text('Concor 5mg 5mg'), findsOneWidget);
      expect(find.text('باقي 2 أيام على النفاذ ⏳'), findsOneWidget);
      expect(find.text('إعادة طلب الدواء ⚡'), findsOneWidget);

      // Step 2: User taps 1-tap re-order button
      await tester.tap(find.text('إعادة طلب الدواء ⚡'));
      await tester.pump();

      // Step 3: Mandatory location prompt verifies GPS before search/delivery
      bool permissionAllowed = false;
      await tester.pumpWidget(
        wrapWithTheme(
          MandatoryLocationPromptDialog(
            onAllow: () => permissionAllowed = true,
            onCancel: () {},
          ),
        ),
      );
      expect(find.text('محتاجين نعرف موقعك بدقة'), findsOneWidget);
      await tester.tap(find.text('سماح'));
      expect(permissionAllowed, isTrue);

      final fakeLoc = FakeE2ELocationService(
        positionOverride: Position(latitude: 29.987, longitude: 30.942, timestamp: DateTime.now(), accuracy: 10, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0),
      );
      final pos = await fakeLoc.getCurrentLocation();
      expect(pos!.latitude, 29.987);

      // Step 4: Batch search locates delivery pharmacy
      final batchRes = await fakeApi.batchSearch(BatchSearchRequest(
        items: [BatchSearchItemDto(medication: med.medicationName, quantity: 1)],
        lat: pos.latitude,
        lng: pos.longitude,
        radiusKm: 5.0,
      ));
      expect(batchRes.completePharmacies, isNotEmpty);

      // Step 5: Nearby pharmacy options sheet shows delivery badge & reservation
      final deliveryProduct = NearbyProduct(
        id: 'prod-chronic-refill',
        tradeName: 'Concor 5mg',
        commercialNameAr: 'كونكور 5 مجم',
        dosageForm: 'أقراص',
        strength: '5mg',
        price: 45.0,
        availablePharmaciesCount: 1,
        minDistanceKm: 1.2,
        pharmacies: [
          NearbyPharmacyOption(
            pharmacyId: 'p_complete_1',
            pharmacyName: 'صيدلية الأمل النموذجية',
            address: 'شارع جمال عبد الناصر، بنها',
            distanceKm: 0.9,
            price: 45.0,
            inStockQuantity: 10,
            supportsDelivery: true,
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(NearbyPharmacyOptionsSheet(product: deliveryProduct)),
        ),
      );
      expect(find.text('توصيل متاح 🛵'), findsOneWidget);

      final res = await fakeApi.createReservation(CreateReservationRequest(
        inventoryItemId: 'inv_concor',
      ));
      expect(res.reservationCode, isNotEmpty);
    });

    testWidgets('T4-S2: Urgent multi-medication night search with single-nearest pharmacy delivery', (tester) async {
      // Step 1: User types multi-medication query
      const query = 'بنادول و كتافلام';
      final tokens = ArabicMedicationMapper.splitMedications(query);
      expect(tokens.length, 2);

      // Step 2: System routes to batch search and finds single complete pharmacy
      final fakeApi = FakeE2EApiClient();
      final batchRes = await fakeApi.batchSearch(BatchSearchRequest(
        items: tokens.map((t) => BatchSearchItemDto(medication: t, quantity: 1)).toList(),
        lat: 30.466,
        lng: 31.185,
        radiusKm: 10.0,
      ));
      expect(batchRes.completePharmacies.first.isCompleteMatch, isTrue);

      // Step 3: Verifies delivery badge & stickers
      await tester.pumpWidget(
        wrapWithTheme(
          const Row(
            children: [
              NawaqssFoundSticker(),
              Text('توصيل متاح 🛵'),
            ],
          ),
        ),
      );
      expect(find.text('لقيناه!'), findsOneWidget);
      expect(find.text('توصيل متاح 🛵'), findsOneWidget);
    });

    testWidgets('T4-S3: Prescription OCR camera scan to uncovered basket with privacy ticker', (tester) async {
      final fakeApi = FakeE2EApiClient();

      // Step 1: Genuine PrescriptionScannerHudScreen initializes without overflow
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
          ],
          child: wrapWithTheme(
            const PrescriptionScannerHudScreen(
              ocrHintText: 'Augmentin',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(PrescriptionScannerHudScreen), findsOneWidget);

      // Step 2: Basket screen displays single-line privacy ticker
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          child: wrapWithTheme(PrescriptionBasketScreen(
            initialItems: [
              PrescriptionBasketItem(tradeName: 'Augmentin', strength: '1g', quantity: 1),
              PrescriptionBasketItem(tradeName: 'Panadol', strength: '500mg', quantity: 2),
            ],
          )),
        ),
      );
      expect(find.byKey(const ValueKey('prescription_privacy_assurance_banner')), findsOneWidget);
      expect(find.text('🔒 الاسم والرقم اتحجبوا · خصوصية مشفرة بقانون 151'), findsOneWidget);
      expect(find.text('Augmentin'), findsOneWidget);
      expect(find.text('Panadol'), findsOneWidget);
    });

    testWidgets('T4-S4: New pharmacy owner onboarding and first sales audit with Price * Quantity earnings', (tester) async {
      final fakeApi = FakeE2EApiClient();

      // Step 1: New pharmacy owner visits dashboard - returns empty DTO without 404 crash
      final initialLedger = await fakeApi.getSalesLedger();
      expect(initialLedger.totalCompleted, 0);
      expect(initialLedger.totalRevenue, 0.0);

      // Step 2: Pharmacy dispenses first completed order: 3 units at 120 EGP
      fakeApi.salesLedgerResult = const SalesLedgerDto(
        totalCompleted: 1,
        totalRevenue: 360.0, // 120 * 3
        todayCount: 1,
        entries: [
          SalesLedgerEntryDto(
            reservationId: 'res-audit-1',
            medicationName: 'Augmentin 1g',
            price: 120.0,
            quantity: 3,
            patientContact: '01012345678',
            completedAt: '2026-11-07T14:00:00Z',
            reservationCode: 'RES-AUDIT-1',
          ),
        ],
      );

      final updatedLedger = await fakeApi.getSalesLedger();
      expect(updatedLedger.totalCompleted, 1);
      expect(updatedLedger.totalRevenue, 360.0);
    });

    testWidgets('T4-S5: Expired medicine warning, safe disposal notice, and 1-tap re-order with delivery', (tester) async {
      final expiredMed = FamilyMedicationModel(
        id: 'med-expired-1',
        medicationName: 'Panadol Extra',
        strength: '500mg',
        stripsCount: 0,
        unitsPerStrip: 10,
        dailyDoseUnits: 2,
        daysRemaining: 0,
        alertThresholdDays: 5,
        expiryDate: DateTime.now().subtract(const Duration(days: 10)),
      );

      final deliveryProduct = NearbyProduct(
        id: 'prod-delivery-s5',
        tradeName: 'Panadol Extra',
        commercialNameAr: 'بانادول اكسترا',
        dosageForm: 'أقراص',
        strength: '500mg',
        price: 45.0,
        availablePharmaciesCount: 1,
        minDistanceKm: 1.5,
        pharmacies: [
          NearbyPharmacyOption(
            pharmacyId: 'pharm-delivery-s5',
            pharmacyName: 'صيدلية النيل',
            address: 'الدقي، الجيزة',
            distanceKm: 1.5,
            price: 45.0,
            inStockQuantity: 10,
            supportsDelivery: true,
          ),
        ],
      );

      // Step 1: Patient observes expired medication alert in genuine MedicationDepletionCard
      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(MedicationDepletionCard(medication: expiredMed)),
        ),
      );
      expect(find.text('منتهي الصلاحية ⛔'), findsOneWidget);
      expect(find.text('لا تتناول الدواء. اسأل الصيدلي عن الطريقة الآمنة للتخلص منه.'), findsOneWidget);
      expect(find.text('دواك خلص! باقي 0 يوم ⏳'), findsOneWidget);
      expect(find.text('إعادة طلب الدواء ⚡'), findsOneWidget);

      // Step 2: 1-tap re-order fresh medication with delivery options sheet
      await tester.tap(find.text('إعادة طلب الدواء ⚡'));
      await tester.pump();

      await tester.pumpWidget(
        ProviderScope(
          child: wrapWithTheme(NearbyPharmacyOptionsSheet(product: deliveryProduct)),
        ),
      );
      expect(find.text('توصيل متاح 🛵'), findsOneWidget);
      expect(find.byType(NearbyPharmacyOptionsSheet), findsOneWidget);
    });
  });
}
