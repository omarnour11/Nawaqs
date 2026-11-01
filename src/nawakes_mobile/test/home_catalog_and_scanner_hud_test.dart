import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_scanner_hud_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/widgets/home_catalog_view.dart';
import 'package:nawakes_mobile/features/search/presentation/widgets/nearby_pharmacy_options_sheet.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/features/search/presentation/nearby_products_provider.dart';

// 1x1 valid PNG
final Uint8List kTransparentPng = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
  0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84,
  120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78,
  68, 174, 66, 96, 130
]);

final testProducts = [
  NearbyProduct(
    id: 'prod-1',
    tradeName: 'Panadol Extra',
    commercialNameAr: 'بانادول اكسترا',
    dosageForm: 'أقراص',
    strength: '500mg',
    price: 45.0,
    availablePharmaciesCount: 3,
    minDistanceKm: 1.2,
    category: 'مسكنات',
    imageUrl: null,
    pharmacies: [
      NearbyPharmacyOption(
        pharmacyId: 'pharm-1',
        pharmacyName: 'صيدلية النيل',
        address: 'الحي المتميز، 6 أكتوبر',
        distanceKm: 1.2,
        price: 45.0,
        inStockQuantity: 12,
        phone: '01011111111',
      ),
    ],
  ),
  NearbyProduct(
    id: 'prod-2',
    tradeName: 'Concor 5mg',
    commercialNameAr: 'كونكور 5 مجم',
    dosageForm: 'أقراص',
    strength: '5mg',
    price: 62.0,
    availablePharmaciesCount: 1,
    minDistanceKm: 2.5,
    category: 'أدوية مزمنة',
    imageUrl: null,
    pharmacies: [
      NearbyPharmacyOption(
        pharmacyId: 'pharm-2',
        pharmacyName: 'صيدلية الشفاء',
        address: 'الحصري، 6 أكتوبر',
        distanceKm: 2.5,
        price: 62.0,
        inStockQuantity: 5,
        phone: '01022222222',
      ),
    ],
  ),
];

final testProductsResponse = NearbyProductsResponse(
  totalCount: 2,
  radiusKm: 15.0,
  products: testProducts,
);

class MockApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  Completer<ParsedMedicationResponse>? parseCompleter;

  @override
  Future<NearbyProductsResponse> getNearbyProducts({
    required double lat,
    required double lng,
    double radius = 15.0,
    String? category,
    int limit = 30,
  }) async {
    return testProductsResponse;
  }

  @override
  Future<ParsedMedicationResponse> parsePrescriptionImage(
    MultipartFile file,
    String? ocrHintText,
  ) {
    if (parseCompleter != null) {
      return parseCompleter!.future;
    }
    return Future.value(ParsedMedicationResponse(
      resolvedName: 'Panadol Extra',
      strength: '500mg',
      dosageForm: 'Tablet',
      confidence: 0.96,
      requiresDisambiguation: false,
      candidates: [
        ParsedCandidate(
          tradeName: 'Panadol Extra',
          strength: '500mg',
          dosageForm: 'Tablet',
          quantity: 2,
          confidence: 0.96,
        ),
        ParsedCandidate(
          tradeName: 'Concor 5mg',
          strength: '5mg',
          dosageForm: 'Tablet',
          quantity: 1,
          confidence: 0.94,
        ),
        ParsedCandidate(
          tradeName: 'Augmentin 1g',
          strength: '1000mg',
          dosageForm: 'Tablet',
          quantity: 1,
          confidence: 0.92,
        ),
      ],
      isSuccess: true,
    ));
  }

  @override
  Future<ReservationResponse> createReservation(CreateReservationRequest body) async {
    return ReservationResponse(
      id: 'res-1',
      inventoryItemId: body.inventoryItemId,
      pharmacyId: 'pharm-1',
      pharmacyName: 'صيدلية النيل',
      pharmacyPhone: '01011111111',
      medicationName: 'Panadol Extra',
      status: 'Confirmed',
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
      createdAt: DateTime.now(),
      reservationCode: 'NWK-8899',
    );
  }
}

class FakeLocationService extends LocationService {
  final Position? fakePosition;
  final String? fakeAddress;
  final List<LocationSuggestion> fakeSuggestions;

  FakeLocationService({
    this.fakePosition,
    this.fakeAddress,
    this.fakeSuggestions = const [],
  });

  @override
  Future<Position?> getCurrentLocation() async => fakePosition;

  @override
  Future<String?> reverseGeocode(double lat, double lng) async => fakeAddress;

  @override
  Future<List<LocationSuggestion>> searchPlaces(
    String query, {
    double? centerLat,
    double? centerLng,
  }) async {
    if (fakeSuggestions.isNotEmpty) return fakeSuggestions;
    return super.searchPlaces(query, centerLat: centerLat, centerLng: centerLng);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Catalog View & El-Ezaby Pattern Tests', () {
    testWidgets('Renders delivery mode selector, address bar, categories, and products', (tester) async {
      final mockApi = MockApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            nearbyProductsProvider.overrideWith((ref) async => testProducts),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomeCatalogView(
                  onOpenScanner: () {},
                  onSearchKeyword: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Verify delivery mode selector tabs
      expect(find.text('توصيل منزلي'), findsOneWidget);
      expect(find.text('استلام من الصيدلية'), findsOneWidget);

      // Verify delivery address
      expect(find.textContaining('الحي المتميز'), findsOneWidget);
      expect(find.text('تغيير'), findsOneWidget);

      // Verify quick services
      expect(find.text('طلب بالروشتة'), findsOneWidget);
      expect(find.text('التأمين الطبي'), findsOneWidget);
      expect(find.text('نواقص SOS'), findsOneWidget);

      // Verify categories
      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('أدوية عامة'), findsOneWidget);
      expect(find.text('مسكنات'), findsOneWidget);

      // Advance frames so Future resolves into AsyncData
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      // Verify product card details (Notice: No pharmacy name on the home card!)
      expect(find.text('بانادول اكسترا'), findsOneWidget);
      expect(find.text('Panadol Extra'), findsOneWidget);
      expect(find.text('كونكور 5 مجم'), findsOneWidget);
      expect(find.text('45 ج.م'), findsOneWidget);
      expect(find.text('62 ج.م'), findsOneWidget);
      expect(find.text('احجز الآن'), findsNWidgets(2));

      // Neither pharmacy name appears on the home card
      expect(find.text('صيدلية النيل'), findsNothing);
      expect(find.text('صيدلية الشفاء'), findsNothing);
    });

    testWidgets('Tapping reserve button opens NearbyPharmacyOptionsSheet revealing pharmacy details', (tester) async {
      final mockApi = MockApiClient();

      final testProduct = NearbyProduct(
        id: 'prod-1',
        tradeName: 'Panadol Extra',
        commercialNameAr: 'بانادول اكسترا',
        dosageForm: 'أقراص',
        strength: '500mg',
        price: 45.0,
        availablePharmaciesCount: 1,
        minDistanceKm: 1.2,
        category: 'مسكنات',
        imageUrl: null,
        pharmacies: [
          NearbyPharmacyOption(
            pharmacyId: 'pharm-1',
            pharmacyName: 'صيدلية النيل المعتمدة',
            address: 'الحي المتميز، 6 أكتوبر',
            distanceKm: 1.2,
            price: 45.0,
            inStockQuantity: 12,
            phone: '01011111111',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => NearbyPharmacyOptionsSheet.show(ctx, testProduct),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Inside the sheet: pharmacy name and distance are displayed!
      expect(find.text('صيدلية النيل المعتمدة'), findsOneWidget);
      expect(find.text('1.2 كم'), findsOneWidget);
      expect(find.text('متوفر (12 علب)'), findsOneWidget);
      expect(find.text('حجز'), findsOneWidget);

      // Perform one-click reservation
      await tester.tap(find.text('حجز'));
      await tester.pumpAndSettle();

      // Expect success snackbar with reservation code
      expect(find.textContaining('NWK-8899'), findsOneWidget);
    });

    testWidgets('NearbyPharmacyOptionsSheet shows distance warning & delivery support for distant items (>15km)', (tester) async {
      final mockApi = MockApiClient();

      final distantProduct = NearbyProduct(
        id: 'prod-dist',
        tradeName: 'Concor 10mg',
        commercialNameAr: 'كونكور 10 مجم',
        dosageForm: 'أقراص',
        strength: '10mg',
        price: 80.0,
        availablePharmaciesCount: 1,
        minDistanceKm: 22.5,
        category: 'أدوية مزمنة',
        imageUrl: null,
        pharmacies: [
          NearbyPharmacyOption(
            pharmacyId: 'pharm-far',
            pharmacyName: 'صيدلية النصر الإقليمية',
            address: 'طريق مصر الإسكندرية',
            distanceKm: 22.5,
            price: 80.0,
            inStockQuantity: 8,
            supportsDelivery: true,
            inventoryItemId: 'item-far-1',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => NearbyPharmacyOptionsSheet.show(ctx, distantProduct),
                  child: const Text('Open Distant Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Distant Sheet'));
      await tester.pumpAndSettle();

      // Expect distance warning banner and delivery note
      expect(find.text('ملاحظة: الدواء متوفر في صيدلية بعيدة عنك'), findsOneWidget);
      expect(find.textContaining('22.5 كم'), findsWidgets);
      expect(find.textContaining('التوصيل المنزلي'), findsOneWidget);
      expect(find.textContaining('صيدلية واحدة'), findsOneWidget);
    });

    testWidgets('NearbyPharmacyOptionsSheet shows notify button when distant pharmacy does not support delivery', (tester) async {
      final mockApi = MockApiClient();

      final distantProductNoDelivery = NearbyProduct(
        id: 'prod-dist-2',
        tradeName: 'Epanutin 100mg',
        commercialNameAr: 'إيبانوتين 100 مجم',
        dosageForm: 'كبسولات',
        strength: '100mg',
        price: 45.0,
        availablePharmaciesCount: 1,
        minDistanceKm: 35.0,
        category: 'أدوية مزمنة',
        imageUrl: null,
        pharmacies: [
          NearbyPharmacyOption(
            pharmacyId: 'pharm-far-nodelivery',
            pharmacyName: 'صيدلية أسيوط المركزية',
            address: 'شارع الجمهورية، أسيوط',
            distanceKm: 35.0,
            price: 45.0,
            inStockQuantity: 3,
            supportsDelivery: false,
            inventoryItemId: 'item-far-2',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => NearbyPharmacyOptionsSheet.show(ctx, distantProductNoDelivery),
                  child: const Text('Open No Delivery Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open No Delivery Sheet'));
      await tester.pumpAndSettle();

      // Expect distance warning banner, non-delivery note, and notify button
      expect(find.text('ملاحظة: الدواء متوفر في صيدلية بعيدة عنك'), findsOneWidget);
      expect(find.textContaining('ولا تدعم التوصيل'), findsOneWidget);
      expect(find.text('أشعرني عند توفره بصيدلية قريبة 🔔'), findsOneWidget);
      expect(find.textContaining('صيدلية واحدة'), findsOneWidget);
    });
  });

  group('Uber/Talabat-Style Location Picker & GPS Verification Tests', () {
    testWidgets('Tapping "تغيير" opens sheet without clunky tabs and displays popular suggestions', (tester) async {
      final mockApi = MockApiClient();
      final fakeLocService = FakeLocationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            locationServiceProvider.overrideWithValue(fakeLocService),
            nearbyProductsProvider.overrideWith((ref) async => testProducts),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomeCatalogView(
                  onOpenScanner: () {},
                  onSearchKeyword: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Verify initial delivery address
      expect(find.textContaining('الحي المتميز'), findsOneWidget);

      // Tap 'تغيير'
      await tester.tap(find.text('تغيير'));
      await tester.pumpAndSettle();

      // 1. Verify that the clunky tabs are GONE!
      expect(find.text('الخريطة المدمجة 🗺️'), findsNothing);
      expect(find.text('البحث والمحافظات'), findsNothing);

      // 2. Verify sheet title, search field, GPS action tile, and resolved location badge
      expect(find.text('تحديد موقع التوصيل'), findsOneWidget);
      expect(find.text('استخدام موقعي الحالي (GPS)'), findsOneWidget);
      expect(find.text('(الحي المتميز، 6 أكتوبر)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // 3. Verify popular suggestions are shown when query is empty
      expect(find.text('المناطق المقترحة والأكثر طلباً:'), findsOneWidget);
      expect(find.text('الحي الأول'), findsOneWidget);
      expect(find.text('الشيخ زايد'), findsOneWidget);
    });

    testWidgets('Real-time search suggests matching places and tapping updates address and closes sheet', (tester) async {
      final mockApi = MockApiClient();
      final fakeLocService = FakeLocationService(
        fakeSuggestions: [
          const LocationSuggestion(
            title: 'الحي الأول',
            subtitle: 'مدينة 6 أكتوبر، الجيزة',
            latitude: 29.9735,
            longitude: 30.9380,
            governorate: 'الجيزة',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            locationServiceProvider.overrideWithValue(fakeLocService),
            nearbyProductsProvider.overrideWith((ref) async => testProducts),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomeCatalogView(
                  onOpenScanner: () {},
                  onSearchKeyword: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('تغيير'));
      await tester.pumpAndSettle();

      // Results header and suggested match are visible
      expect(find.text('استخدام موقعي الحالي (GPS)'), findsOneWidget);

      // Type in search query "اكتوبر"
      await tester.enterText(find.byType(TextField), 'اكتوبر');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Results header and suggested match are visible
      expect(find.text('نتائج البحث:'), findsOneWidget);
      expect(find.text('الحي الأول'), findsOneWidget);
      expect(find.text('مدينة 6 أكتوبر، الجيزة'), findsOneWidget);

      // Tap the suggestion
      await tester.tap(find.text('الحي الأول'));
      await tester.pumpAndSettle();

      // Sheet is closed
      expect(find.text('تحديد موقع التوصيل'), findsNothing);

      // Verify updated location on home screen address bar & snackbar
      expect(find.textContaining('الحي الأول، مدينة 6 أكتوبر، الجيزة'), findsWidgets);
      expect(find.text('تم تحديث موقع التوصيل إلى: الحي الأول، مدينة 6 أكتوبر، الجيزة'), findsOneWidget);
    });

    testWidgets('GPS button resolves real address and updates home address with "موقعي الحالي (الحي الأول، 6 أكتوبر)"', (tester) async {
      final mockApi = MockApiClient();
      final fakeLocService = FakeLocationService(
        fakePosition: Position(
          longitude: 30.938,
          latitude: 29.9735,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        ),
        fakeAddress: 'الحي الأول، 6 أكتوبر',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            locationServiceProvider.overrideWithValue(fakeLocService),
            nearbyProductsProvider.overrideWith((ref) async => testProducts),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomeCatalogView(
                  onOpenScanner: () {},
                  onSearchKeyword: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('تغيير'));
      await tester.pumpAndSettle();

      // Verify that the resolved address badge is displayed next to GPS button
      expect(find.text('(الحي الأول، 6 أكتوبر)'), findsOneWidget);

      // Tap GPS button
      await tester.tap(find.text('استخدام موقعي الحالي (GPS)'));
      await tester.pumpAndSettle();

      // Sheet is closed
      expect(find.text('تحديد موقع التوصيل'), findsNothing);

      // Home address bar & snackbar now show: "موقعي الحالي (الحي الأول، 6 أكتوبر)"
      expect(find.textContaining('موقعي الحالي (الحي الأول، 6 أكتوبر)'), findsWidgets);
      expect(find.text('تم تحديث موقع التوصيل إلى: موقعي الحالي (الحي الأول، 6 أكتوبر)'), findsOneWidget);
    });

    test('Arabic normalization & multi-token search in LocationService matches curated Egyptian places', () async {
      final locService = LocationService();

      // 1. Search with missing hamza and combined neighborhood + city: "الحي الاول اكتوبر"
      final results1 = await locService.searchPlaces('الحي الاول اكتوبر');
      expect(results1, isNotEmpty);
      expect(results1.any((r) => r.title == 'الحي الأول'), isTrue);

      // 2. Search "مدينه نصر" with teh marbuta normalized to heh
      final results2 = await locService.searchPlaces('مدينه نصر');
      expect(results2, isNotEmpty);
      expect(results2.any((r) => r.title == 'مدينة نصر'), isTrue);

      // 3. Search "الهرم"
      final results3 = await locService.searchPlaces('الهرم');
      expect(results3, isNotEmpty);
      expect(results3.any((r) => r.title == 'شارع الهرم'), isTrue);

      // 4. Search "حدائق الاهرام"
      final results4 = await locService.searchPlaces('حدائق الاهرام');
      expect(results4, isNotEmpty);
      expect(results4.any((r) => r.title == 'حدائق الأهرام'), isTrue);
    });
  });

  group('Prescription Scanner HUD & Multi-Medication Extraction Tests', () {
    testWidgets('PrescriptionScannerHudScreen animates radar, progress steps, and deciphers all 3 medications', (tester) async {
      final mockApi = MockApiClient();
      final completer = Completer<ParsedMedicationResponse>();
      mockApi.parseCompleter = completer;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => PrescriptionScannerHudScreen.start(
                    ctx,
                    imageBytes: kTransparentPng,
                    ocrHintText: 'Rx hint',
                  ),
                  child: const Text('Launch HUD'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch HUD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify HUD header & radar & initial stage
      expect(find.text('مسح الروشتة الذكي'), findsOneWidget);
      expect(find.byIcon(Icons.radar_rounded), findsOneWidget);
      expect(find.text('جاري فحص وضوح صورة الروشتة...'), findsOneWidget);

      // 2. Complete the AI response with 3 candidate medications
      completer.complete(ParsedMedicationResponse(
        resolvedName: 'Panadol Extra',
        strength: '500mg',
        dosageForm: 'Tablet',
        confidence: 0.96,
        requiresDisambiguation: false,
        candidates: [
          ParsedCandidate(
            tradeName: 'Panadol Extra',
            strength: '500mg',
            dosageForm: 'Tablet',
            quantity: 2,
            confidence: 0.96,
          ),
          ParsedCandidate(
            tradeName: 'Concor 5mg',
            strength: '5mg',
            dosageForm: 'Tablet',
            quantity: 1,
            confidence: 0.94,
          ),
          ParsedCandidate(
            tradeName: 'Augmentin 1g',
            strength: '1000mg',
            dosageForm: 'Tablet',
            quantity: 1,
            confidence: 0.92,
          ),
        ],
        isSuccess: true,
      ));

      // Pump to process response and transition to basket (delayed 500ms + push transition 300ms)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // 3. Verify that all 3 prescribed medications were extracted together into the basket!
      expect(find.text('أدوية الروشتة المفروزة'), findsOneWidget);
      expect(find.text('Panadol Extra'), findsOneWidget);
      expect(find.text('Concor 5mg'), findsOneWidget);
      expect(find.text('Augmentin 1g'), findsOneWidget);
    });
  });
}
