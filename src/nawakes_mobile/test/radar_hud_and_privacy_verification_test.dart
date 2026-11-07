import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/services/prescription_frame_crop.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/search/presentation/batch_search_results_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_basket_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_scanner_hud_screen.dart';

// Valid 200x200 JPEG for image downsample and cropping tests
final Uint8List kTestImagePng = Uint8List.fromList(
  img.encodeJpg(img.Image(width: 200, height: 200)),
);

class FakeTestLocationService extends LocationService {
  @override
  Future<Position?> getCurrentLocation() async => null;
}

class MockVerificationApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Completer<ParsedMedicationResponse>? parseCompleter;
  BatchSearchResponse? batchSearchOverride;
  final List<CreateReservationRequest> capturedReservationRequests = [];

  @override
  Future<ParsedMedicationResponse> parsePrescriptionImage(
    dynamic file,
    String? ocrHintText,
  ) {
    if (parseCompleter != null) {
      return parseCompleter!.future;
    }
    return Future.value(ParsedMedicationResponse(
      resolvedName: 'Augmentin 1g',
      strength: '1000mg',
      dosageForm: 'Tablet',
      confidence: 0.95,
      requiresDisambiguation: false,
      candidates: [
        ParsedCandidate(
          tradeName: 'Augmentin 1g',
          strength: '1000mg',
          dosageForm: 'Tablet',
          quantity: 1,
          confidence: 0.95,
        ),
        ParsedCandidate(
          tradeName: 'Concor 5mg',
          strength: '5mg',
          dosageForm: 'Tablet',
          quantity: 2,
          confidence: 0.93,
        ),
      ],
      isSuccess: true,
    ));
  }

  Future<ParsedMedicationResponse> parsePrescriptionImageBytes(
    Uint8List bytes, {
    String filename = 'prescription.jpg',
    String? ocrHintText,
  }) {
    if (parseCompleter != null) {
      return parseCompleter!.future;
    }
    return parsePrescriptionImage(null, ocrHintText);
  }

  @override
  Future<BatchSearchResponse> batchSearch(BatchSearchRequest request) async {
    if (batchSearchOverride != null) {
      return batchSearchOverride!;
    }
    return BatchSearchResponse(
      totalRequestedItems: 2,
      radiusKm: 15.0,
      completePharmacies: [
        BatchPharmacyResult(
          pharmacyId: 'pharm-1',
          pharmacyName: 'صيدلية النيل',
          addressLine: 'الدقي، الجيزة',
          phone: '01011111111',
          trustScore: 4.8,
          distanceKm: 1.5,
          latitude: 30.033,
          longitude: 31.200,
          matchedCount: 2,
          totalRequested: 2,
          isCompleteMatch: true,
          totalEstimatedPrice: 150.0,
          items: [
            BatchMedicationDetail(
              medication: 'Augmentin 1g',
              requestedQuantity: 1,
              inStock: true,
              price: 90.0,
              availableQuantity: 5,
              inventoryItemId: 'inv-item-1',
            ),
            BatchMedicationDetail(
              medication: 'Concor 5mg',
              requestedQuantity: 2,
              inStock: true,
              price: 30.0,
              availableQuantity: 10,
              inventoryItemId: 'inv-item-2',
            ),
          ],
        ),
      ],
      partialPharmacies: [],
    );
  }

  @override
  Future<ReservationResponse> createReservation(CreateReservationRequest body) async {
    capturedReservationRequests.add(body);
    return ReservationResponse(
      id: 'res-${capturedReservationRequests.length}',
      inventoryItemId: body.inventoryItemId,
      pharmacyId: 'pharm-1',
      pharmacyName: 'صيدلية النيل',
      pharmacyPhone: '01011111111',
      medicationName: 'Medication',
      status: 'Active',
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
      createdAt: DateTime.now(),
      reservationCode: 'NWQ-VERIFY',
      prescriptionCropUrl: body.prescriptionCropUrl,
    );
  }

  @override
  Future<BatchReservationResult> createBatchReservation(BatchReservationRequestBody body) async {
    for (final it in body.items) {
      capturedReservationRequests.add(CreateReservationRequest(
        inventoryItemId: it.inventoryItemId,
        prescriptionCropBase64: body.prescriptionCropBase64,
        fulfillmentType: it.fulfillmentType,
      ));
    }
    final created = body.items
        .map((it) => ReservationResponse(
              id: 'res-${it.inventoryItemId}',
              inventoryItemId: it.inventoryItemId,
              pharmacyId: 'pharm-1',
              pharmacyName: 'صيدلية النيل',
              pharmacyPhone: '01011111111',
              medicationName: 'Medication',
              status: 'Active',
              expiresAt: DateTime.now().add(const Duration(hours: 2)),
              createdAt: DateTime.now(),
              reservationCode: 'NWQ-BATCH',
            ))
        .toList();
    return BatchReservationResult(
      createdReservations: created,
      failedItems: [],
      isAllSucceeded: true,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Radar HUD & GUI Microcopy Overhaul Tests', () {
    testWidgets('PrescriptionScannerHudScreen renders FuturisticRadarSweepHudPainter and Arabic microcopy', (tester) async {
      final mockApi = MockVerificationApiClient();
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
                    imageBytes: kTestImagePng,
                  ),
                  child: const Text('Start Radar HUD'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Radar HUD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Futuristic CustomPaint is present in the tree
      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is FuturisticRadarSweepHudPainter,
      );
      expect(customPaintFinder, findsOneWidget);

      // 2. Verify crisp Arabic microcopy on radar HUD
      expect(find.text('جاري تثبيت زوايا الروشتة...'), findsOneWidget);
      expect(find.text('مسح الروشتة الذكي'), findsOneWidget);

      // 3. Advance timer to stage 1 and verify updated microcopy
      await tester.pump(const Duration(milliseconds: 1050));
      expect(find.text('المستشعر الذكي يقرأ خط الطبيب...'), findsOneWidget);

      // Complete the OCR parse
      completer.complete(ParsedMedicationResponse(
        resolvedName: 'Augmentin 1g',
        strength: '1000mg',
        dosageForm: 'Tablet',
        confidence: 0.95,
        requiresDisambiguation: false,
        candidates: [
          ParsedCandidate(
            tradeName: 'Augmentin 1g',
            strength: '1000mg',
            dosageForm: 'Tablet',
            quantity: 1,
            confidence: 0.95,
          ),
        ],
        isSuccess: true,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Navigated to basket screen
      expect(find.text('أدوية الروشتة المفروزة'), findsOneWidget);
    });

    test('PrescriptionFrameCrop downsamples and creates Law No. 151 medication-only crop', () {
      final compressed = PrescriptionFrameCrop.downsampleAndCompress(
        bytes: kTestImagePng,
        maxDimension: 1600,
        quality: 80,
      );
      expect(compressed, isNotEmpty);

      final crop = PrescriptionFrameCrop.cropPrescriptionMedicationBody(
        bytes: compressed,
        headerRatio: 0.20,
        footerRatio: 0.18,
        maxDimension: 1600,
        quality: 80,
      );
      expect(crop, isNotNull);
      expect(crop!, isNotEmpty);
    });
  });

  group('PrescriptionScannerHudScreen Zero RenderFlex Overflow Tests', () {
    testWidgets('PrescriptionScannerHudScreen does not overflow on 360x640 small viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = MockVerificationApiClient();
      mockApi.parseCompleter = Completer<ParsedMedicationResponse>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
          ],
          child: MaterialApp(
            home: PrescriptionScannerHudScreen(
              imageBytes: kTestImagePng,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('PrescriptionScannerHudScreen does not overflow on 600x800 medium viewport', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = MockVerificationApiClient();
      mockApi.parseCompleter = Completer<ParsedMedicationResponse>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
          ],
          child: MaterialApp(
            home: PrescriptionScannerHudScreen(
              imageBytes: kTestImagePng,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));

      expect(tester.takeException(), isNull);
    });
  });

  group('PrescriptionBasketScreen Privacy Assurance Banner & Safety Alert Tests', () {
    testWidgets('Displays compact single-line privacy ticker with key and Law 151 statement', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PrescriptionBasketScreen(
              initialItems: [
                PrescriptionBasketItem(tradeName: 'Concor', strength: '5mg', quantity: 1),
                PrescriptionBasketItem(tradeName: 'Augmentin', strength: '1g', quantity: 1),
              ],
              sanitizedCropBase64: 'dGVzdF9iYXNlNjQ=',
            ),
          ),
        ),
      );

      // 1. Verify privacy assurance banner key
      final tickerFinder = find.byKey(const ValueKey('prescription_privacy_assurance_banner'));
      expect(tickerFinder, findsOneWidget);

      // 2. Exact ticker text
      expect(find.text('🔒 الاسم والرقم اتحجبوا · خصوصية مشفرة بقانون 151'), findsOneWidget);

      // 3. Container height is compact between 34 and 38px
      final renderBox = tester.renderObject<RenderBox>(tickerFinder);
      expect(renderBox.size.height, inInclusiveRange(34.0, 38.0));
    });

    testWidgets('PrescriptionBasketScreen does not overflow on 360x640 and 600x800 viewports', (tester) async {
      for (final size in [const Size(360, 640), const Size(600, 800)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: PrescriptionBasketScreen(
                initialItems: [
                  PrescriptionBasketItem(tradeName: 'Concor', strength: '5mg', quantity: 1),
                  PrescriptionBasketItem(tradeName: 'Augmentin', strength: '1g', quantity: 1),
                ],
                sanitizedCropBase64: 'dGVzdF9iYXNlNjQ=',
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        // Medication list is uncovered and visible without scrolling
        expect(find.text('Concor'), findsOneWidget);
        expect(find.text('Augmentin'), findsOneWidget);
      }
    });

    testWidgets('showAddDialog wraps content in SingleChildScrollView preventing keyboard overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PrescriptionBasketScreen(
              initialItems: [
                PrescriptionBasketItem(tradeName: 'Concor', strength: '5mg', quantity: 1),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final addBtn = find.byTooltip('إضافة دواء يدوي');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('إضافة دواء للروشتة'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Suppresses empty or nominal safety alerts using SizedBox.shrink()', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PrescriptionBasketScreen(
              initialItems: [
                PrescriptionBasketItem(tradeName: 'Concor', strength: '5mg', quantity: 1),
              ],
              safetyAlerts: [
                SafetyAlertResponse(message: '', severity: 'nominal', recommendation: ''),
                SafetyAlertResponse(message: '  ', severity: 'low', recommendation: ''),
                SafetyAlertResponse(message: 'كل المؤشرات طبيعية', severity: 'nominal', recommendation: ''),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // No safety alert header is rendered
      expect(find.text('تدقيق الأمان والجرعات الدوائية'), findsNothing);
      // Medication list is visible immediately above the fold
      expect(find.text('Concor'), findsOneWidget);
    });

    testWidgets('Renders actionable critical or warning safety alerts when present', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PrescriptionBasketScreen(
              initialItems: [
                PrescriptionBasketItem(tradeName: 'Concor', strength: '5mg', quantity: 1),
              ],
              safetyAlerts: [
                SafetyAlertResponse(
                  message: 'تحذير تداخل دوائي خطير',
                  severity: 'critical',
                  recommendation: 'استشر الطبيب قبل الاستخدام',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('تدقيق الأمان والجرعات الدوائية'), findsOneWidget);
      expect(find.text('تحذير تداخل دوائي خطير'), findsOneWidget);
      expect(find.text('استشر الطبيب قبل الاستخدام'), findsOneWidget);
    });
  });

  group('Multi-Pharmacy Reservation Verification Flow Tests', () {
    testWidgets('BatchSearchResultsScreen attaches sanitized prescription crop to every pharmacy reservation', (tester) async {
      final mockApi = MockVerificationApiClient();
      const testCropBase64 = 'c2FuaXRpemVkX3J4X2Jhc2U2NA==';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            locationServiceProvider.overrideWithValue(FakeTestLocationService()),
          ],
          child: MaterialApp(
            home: BatchSearchResultsScreen(
              items: [
                BatchSearchItemDto(medication: 'Augmentin 1g', quantity: 1),
                BatchSearchItemDto(medication: 'Concor 5mg', quantity: 2),
              ],
              sanitizedCropBase64: testCropBase64,
            ),
          ),
        ),
      );

      // Wait for batch search to resolve
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // 1. Verify verification badge is shown in results
      expect(find.byKey(const ValueKey('batch_sanitized_rx_badge')), findsOneWidget);
      expect(find.textContaining('يتم إرفاق صورة الروشتة المقتطعة الخالية من أي بيانات شخصية'), findsOneWidget);

      // 2. Perform booking
      final reserveBtn = find.text('احجز كل الروشتة الآن ⚡');
      expect(reserveBtn, findsOneWidget);
      await tester.tap(reserveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Verify that createReservation was called for each assigned item with sanitized crop attached!
      expect(mockApi.capturedReservationRequests, isNotEmpty);
      expect(mockApi.capturedReservationRequests.length, 2);
      for (final req in mockApi.capturedReservationRequests) {
        expect(req.prescriptionCropBase64, equals(testCropBase64));
      }
    });

    testWidgets('attaches sanitized prescription crop to all reservations when split across 3 distinct pharmacies', (tester) async {
      final mockApi = MockVerificationApiClient();
      const testCropBase64 = 'dGhyZWVfcGhhcm1hY2llc19jcm9w';

      // Mock returning 3 partial pharmacies, each having 1 medication
      mockApi.batchSearchOverride = BatchSearchResponse(
        totalRequestedItems: 3,
        radiusKm: 15.0,
        completePharmacies: [],
        partialPharmacies: [
          BatchPharmacyResult(
            pharmacyId: 'pharm-1',
            pharmacyName: 'صيدلية النيل',
            addressLine: 'الدقي',
            phone: '01011111111',
            trustScore: 4.8,
            distanceKm: 1.0,
            latitude: 30.033,
            longitude: 31.200,
            matchedCount: 1,
            totalRequested: 3,
            isCompleteMatch: false,
            totalEstimatedPrice: 90.0,
            items: [
              BatchMedicationDetail(
                medication: 'Augmentin 1g',
                requestedQuantity: 1,
                inStock: true,
                price: 90.0,
                availableQuantity: 5,
                inventoryItemId: 'inv-item-1',
              ),
            ],
          ),
          BatchPharmacyResult(
            pharmacyId: 'pharm-2',
            pharmacyName: 'صيدلية مصر',
            addressLine: 'المهندسين',
            phone: '01022222222',
            trustScore: 4.7,
            distanceKm: 2.0,
            latitude: 30.050,
            longitude: 31.200,
            matchedCount: 1,
            totalRequested: 3,
            isCompleteMatch: false,
            totalEstimatedPrice: 30.0,
            items: [
              BatchMedicationDetail(
                medication: 'Concor 5mg',
                requestedQuantity: 1,
                inStock: true,
                price: 30.0,
                availableQuantity: 4,
                inventoryItemId: 'inv-item-2',
              ),
            ],
          ),
          BatchPharmacyResult(
            pharmacyId: 'pharm-3',
            pharmacyName: 'صيدلية الأمل',
            addressLine: 'العجوزة',
            phone: '01033333333',
            trustScore: 4.9,
            distanceKm: 3.0,
            latitude: 30.055,
            longitude: 31.210,
            matchedCount: 1,
            totalRequested: 3,
            isCompleteMatch: false,
            totalEstimatedPrice: 45.0,
            items: [
              BatchMedicationDetail(
                medication: 'Panadol Extra',
                requestedQuantity: 2,
                inStock: true,
                price: 45.0,
                availableQuantity: 8,
                inventoryItemId: 'inv-item-3',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            locationServiceProvider.overrideWithValue(FakeTestLocationService()),
          ],
          child: MaterialApp(
            home: BatchSearchResultsScreen(
              items: [
                BatchSearchItemDto(medication: 'Augmentin 1g', quantity: 1),
                BatchSearchItemDto(medication: 'Concor 5mg', quantity: 1),
                BatchSearchItemDto(medication: 'Panadol Extra', quantity: 2),
              ],
              sanitizedCropBase64: testCropBase64,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Book all pharmacies in split basket
      final bookAllBtn = find.textContaining('احجز الكل');
      expect(bookAllBtn, findsOneWidget);
      await tester.tap(bookAllBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Law No. 151 reassurance statement is displayed in confirmation dialog
      expect(find.textContaining('تم إرفاق جزء الأدوية فقط من الروشتة لكل صيدلية للتحقق الطبي'), findsOneWidget);
      expect(find.textContaining('حجب اسم الطبيب وبياناتك الشخصية تماماً'), findsOneWidget);

      // Verify that createReservation was called for each of the 3 items across all 3 pharmacies with sanitized crop
      expect(mockApi.capturedReservationRequests.length, 3);
      for (final req in mockApi.capturedReservationRequests) {
        expect(req.prescriptionCropBase64, equals(testCropBase64));
      }
      final bookedItemIds = mockApi.capturedReservationRequests.map((r) => r.inventoryItemId).toSet();
      expect(bookedItemIds, containsAll(['inv-item-1', 'inv-item-2', 'inv-item-3']));
    });
  });
}
