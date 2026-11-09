import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_dashboard_models.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_profile_models.dart';
import 'package:nawakes_mobile/features/pharmacy/data/sales_ledger_models.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/active_orders_tab.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/add_inventory_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/inventory_tab.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_onboarding_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/sales_ledger_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/shortage_queue_tab.dart';
import 'package:nawakes_mobile/features/profile/data/medication_models.dart';
import 'package:dio/dio.dart' show MultipartFile;

/// Fake ApiClient specifically designed for pharmacy testing
class FakePharmacyApiClient implements ApiClient {
  MyPharmacyDto? myPharmacyData;
  List<PharmacyInventoryItemDto> inventoryList = [];
  List<PharmacyReservationResponse> reservationsList = [];
  List<ShortageRequestDto> shortageRequestsList = [];
  SalesLedgerDto? salesLedgerData;

  String? lastReadyReservationId;
  String? lastCompletedReservationId;
  String? lastCancelledReservationId;
  CancelByPharmacyRequest? lastCancelReq;
  String? lastAvailabilityUpdatedId;
  SetAvailabilityRequest? lastAvailabilityReq;
  String? lastToggledStatusId;
  ToggleStatusRequest? lastToggleStatusReq;
  AddInventoryItemRequest? lastAddInventoryReq;
  RegisterPharmacyRequest? lastRegisterPharmacyReq;
  String? lastClaimedShortageId;
  bool bulkImportCalled = false;

  List<String> suggestedList = [];

  @override
  Future<List<String>> suggestMedications(String prefix) async => suggestedList;

  @override
  Future<MyPharmacyDto?> getMyPharmacy() async => myPharmacyData;

  @override
  Future<IdResponse> registerPharmacy(RegisterPharmacyRequest body) async {
    lastRegisterPharmacyReq = body;
    myPharmacyData = MyPharmacyDto(
      id: 'pharm_1',
      name: body.name,
      addressLine: body.addressLine,
      city: body.city,
      phone: body.phone,
      latitude: body.latitude,
      longitude: body.longitude,
      licenseDocUrl: body.licenseDocUrl,
      nationalIdDocUrl: body.nationalIdDocUrl,
      verificationStatus: 'Pending',
      trustScore: 5.0,
      averageRating: 5.0,
      ratingCount: 1,
      createdAt: DateTime.now().toUtc(),
    );
    return IdResponse(id: 'pharm_1');
  }

  @override
  Future<PagedInventoryResult> getPharmacyInventory({
    int page = 1,
    int pageSize = 50,
    String? search,
    String? status,
  }) async {
    var filtered = inventoryList;
    if (search != null && search.isNotEmpty) {
      filtered = filtered
          .where((i) => i.medicationName.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }
    if (status != null && status.isNotEmpty) {
      filtered = filtered.where((i) => i.status == status).toList();
    }
    return PagedInventoryResult(
      items: filtered,
      pageNumber: page,
      pageSize: pageSize,
      totalCount: filtered.length,
      totalPages: 1,
    );
  }

  @override
  Future<PharmacyInventoryItemDto> addInventoryItem(AddInventoryItemRequest body) async {
    lastAddInventoryReq = body;
    final newItem = PharmacyInventoryItemDto(
      id: 'inv_${inventoryList.length + 1}',
      medicationName: body.medicationName,
      price: body.price,
      quantity: 10,
      status: 'InStock',
      createdAt: DateTime.now().toUtc(),
    );
    inventoryList.add(newItem);
    return newItem;
  }

  @override
  Future<dynamic> setAvailability(String id, SetAvailabilityRequest body) async {
    lastAvailabilityUpdatedId = id;
    lastAvailabilityReq = body;
    final idx = inventoryList.indexWhere((i) => i.id == id);
    if (idx != -1) {
      final old = inventoryList[idx];
      inventoryList[idx] = PharmacyInventoryItemDto(
        id: old.id,
        medicationName: old.medicationName,
        price: body.price ?? old.price,
        quantity: body.quantity,
        status: body.quantity > 0 ? 'InStock' : 'OutOfStock',
        patientNote: body.patientNote ?? old.patientNote,
        createdAt: old.createdAt,
        lastUpdatedAt: DateTime.now().toUtc(),
      );
    }
    return null;
  }

  @override
  Future<dynamic> toggleInventoryStatus(String id, ToggleStatusRequest body) async {
    lastToggledStatusId = id;
    lastToggleStatusReq = body;
    final idx = inventoryList.indexWhere((i) => i.id == id);
    if (idx != -1) {
      final old = inventoryList[idx];
      final isNowInStock = body.status == 0;
      inventoryList[idx] = PharmacyInventoryItemDto(
        id: old.id,
        medicationName: old.medicationName,
        price: old.price,
        quantity: isNowInStock ? 10 : 0,
        status: isNowInStock ? 'InStock' : 'OutOfStock',
        createdAt: old.createdAt,
        lastUpdatedAt: DateTime.now().toUtc(),
      );
    }
    return null;
  }

  @override
  Future<BulkImportResultDto> bulkImportInventory(MultipartFile file) async {
    bulkImportCalled = true;
    return BulkImportResultDto(
      importedCount: 15,
      skippedCount: 2,
      errors: [],
    );
  }

  @override
  Future<List<PharmacyReservationResponse>> getPharmacyReservations() async => reservationsList;

  @override
  Future<PharmacyReservationResponse> markReservationReady(String id) async {
    lastReadyReservationId = id;
    final idx = reservationsList.indexWhere((r) => r.id == id);
    if (idx != -1) {
      final old = reservationsList[idx];
      final updated = PharmacyReservationResponse(
        id: old.id,
        reservationCode: old.reservationCode,
        medicationName: old.medicationName,
        patientDisplayName: old.patientDisplayName,
        expiresAt: old.expiresAt,
        status: 'Ready',
        createdAt: old.createdAt,
      );
      reservationsList[idx] = updated;
      return updated;
    }
    throw Exception('Reservation not found');
  }

  @override
  Future<PharmacyReservationResponse> completePharmacyReservation(String id) async {
    lastCompletedReservationId = id;
    final idx = reservationsList.indexWhere((r) => r.id == id);
    if (idx != -1) {
      final old = reservationsList[idx];
      final updated = PharmacyReservationResponse(
        id: old.id,
        reservationCode: old.reservationCode,
        medicationName: old.medicationName,
        patientDisplayName: old.patientDisplayName,
        expiresAt: old.expiresAt,
        status: 'Completed',
        createdAt: old.createdAt,
      );
      reservationsList[idx] = updated;
      return updated;
    }
    throw Exception('Reservation not found');
  }

  @override
  Future<void> cancelReservationByPharmacy(String id, CancelByPharmacyRequest body) async {
    lastCancelledReservationId = id;
    lastCancelReq = body;
    final idx = reservationsList.indexWhere((r) => r.id == id);
    if (idx != -1) {
      final old = reservationsList[idx];
      reservationsList[idx] = PharmacyReservationResponse(
        id: old.id,
        reservationCode: old.reservationCode,
        medicationName: old.medicationName,
        patientDisplayName: old.patientDisplayName,
        expiresAt: old.expiresAt,
        status: 'Cancelled',
        createdAt: old.createdAt,
      );
    }
  }

  @override
  Future<List<ShortageRequestDto>> getOpenShortageRequests(
      double lat, double lng, double radiusKm) async =>
      shortageRequestsList;

  @override
  Future<ClaimShortageResponse> claimShortageRequest(String id) async {
    lastClaimedShortageId = id;
    shortageRequestsList.removeWhere((r) => r.id == id);
    return ClaimShortageResponse(
      reservationId: 'CLAIM-7788',
    );
  }

  @override
  Future<SalesLedgerDto> getSalesLedger({int take = 100}) async {
    return salesLedgerData ??
        SalesLedgerDto(
          todayCount: 8,
          totalRevenue: 1450.0,
          totalCompleted: 42,
          entries: [
            SalesLedgerEntryDto(
              reservationId: 'res_1',
              reservationCode: 'NWQ-9911',
              medicationName: 'كونكور 5 مجم',
              patientContact: '01012345678',
              completedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
              price: 45.0,
              quantity: 2,
            ),
            SalesLedgerEntryDto(
              reservationId: 'res_2',
              reservationCode: 'NWQ-8822',
              medicationName: 'بانادول إكسترا',
              patientContact: '01198765432',
              completedAt: DateTime.now().toUtc().subtract(const Duration(hours: 3)),
              price: 35.0,
              quantity: 1,
            ),
          ],
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake LocationService returning Cairo coordinates
class FakePharmacyLocationService extends LocationService {
  @override
  Future<Position?> getCurrentLocation() async {
    return Position(
      latitude: 30.0444,
      longitude: 31.2357,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }
}

Widget buildTestPharmacyApp({
  required Widget child,
  required FakePharmacyApiClient apiClient,
  FakePharmacyLocationService? locationService,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(apiClient),
      locationServiceProvider
          .overrideWithValue(locationService ?? FakePharmacyLocationService()),
    ],
    child: MaterialApp(
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'fake_jwt_token',
      'refresh_token': 'fake_refresh_token',
      'user_role': 'PharmacyOwner',
    });
  });

  group('1. PharmacyDashboardScreen & Navigation Shell', () {
    testWidgets('Renders dashboard header, verification chip, tabs and active badge',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient()
        ..myPharmacyData = MyPharmacyDto(
          id: 'p1',
          name: 'صيدلية الشفاء الحديثة',
          addressLine: '12 شارع قصر العيني',
          city: 'القاهرة',
          phone: '01011122233',
          latitude: 30.0444,
          longitude: 31.2357,
          verificationStatus: 'Approved',
          trustScore: 4.9,
          averageRating: 4.8,
          ratingCount: 50,
          createdAt: DateTime.now().toUtc(),
        )
        ..reservationsList = [
          PharmacyReservationResponse(
            id: 'r1',
            reservationCode: 'NWQ-1122',
            medicationName: 'أنسولين لانتوس',
            patientDisplayName: 'كريم ممدوح',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
            status: 'Active',
            createdAt: DateTime.now().toUtc(),
          ),
          PharmacyReservationResponse(
            id: 'r2',
            reservationCode: 'NWQ-3344',
            medicationName: 'جلوكوفاج 1000',
            patientDisplayName: 'سارة خالد',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 45)),
            status: 'Ready',
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const PharmacyDashboardScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Top bar title
      expect(find.text('صيدلية الشفاء الحديثة'), findsOneWidget);

      // 5 Navigation Destinations
      expect(find.text('الطلبات'), findsOneWidget);
      expect(find.text('المخزون'), findsOneWidget);
      expect(find.text('النواقص'), findsOneWidget);
      expect(find.text('المبيعات'), findsOneWidget);
      expect(find.text('الملف'), findsOneWidget);

      // Active orders badge count should be 2
      expect(find.text('2'), findsOneWidget);

      // Verify switching between tabs
      // Switch to Inventory
      await tester.tap(find.text('المخزون'));
      await tester.pumpAndSettle();
      expect(find.text('صيدلية موثقة'), findsOneWidget);

      // Switch to Shortage Queue
      await tester.tap(find.text('النواقص'));
      await tester.pumpAndSettle();

      // Switch to Sales Ledger
      await tester.tap(find.text('المبيعات'));
      await tester.pumpAndSettle();
      expect(find.text('طلبات اليوم'), findsOneWidget);
      expect(find.text('إجمالي الإيراد'), findsOneWidget);

      // Switch to Profile Tab
      await tester.tap(find.text('الملف'));
      await tester.pumpAndSettle();
      expect(find.text('بيانات الاتصال والموقع'), findsOneWidget);
      expect(find.text('موثقة ومعتمدة'), findsOneWidget);
    });

    testWidgets('Displays warning banner when verification status is Pending or Rejected',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient()
        ..myPharmacyData = MyPharmacyDto(
          id: 'p2',
          name: 'صيدلية النور الجديدة',
          addressLine: 'شارع الجمهورية',
          city: 'المنصورة',
          phone: '01222233344',
          latitude: 31.0409,
          longitude: 31.3785,
          verificationStatus: 'Pending',
          trustScore: 4.0,
          averageRating: 0.0,
          ratingCount: 0,
          createdAt: DateTime.now().toUtc(),
        );

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const PharmacyDashboardScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Pending verification banner
      expect(find.text('طلب التوثيق قيد المراجعة'), findsOneWidget);
      expect(find.text('تعديل البيانات'), findsOneWidget);
    });

    testWidgets('Logout button displays Arabic confirmation dialog and cancels cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient();

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const PharmacyDashboardScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Tap logout icon in top bar
      final logoutBtn = find.byIcon(Icons.logout_rounded);
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Check confirmation dialog
      expect(find.text('تسجيل الخروج'), findsWidgets);
      expect(find.text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'), findsNothing);
    });
  });

  group('2. InventoryTab & Stock Management', () {
    testWidgets('Renders stock metrics, list items, and quick availability toggles',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient()
        ..myPharmacyData = MyPharmacyDto(
          id: 'p1',
          name: 'صيدلية النور',
          addressLine: 'شارع الهرم',
          city: 'الجيزة',
          phone: '01000000000',
          latitude: 30.0,
          longitude: 31.0,
          verificationStatus: 'Approved',
          trustScore: 4.8,
          averageRating: 4.7,
          ratingCount: 30,
          createdAt: DateTime.now().toUtc(),
        )
        ..inventoryList = [
          PharmacyInventoryItemDto(
            id: 'item_1',
            medicationName: 'بانادول أزرق 500 مجم',
            price: 25.0,
            quantity: 15,
            status: 'InStock',
            createdAt: DateTime.now().toUtc(),
          ),
          PharmacyInventoryItemDto(
            id: 'item_2',
            medicationName: 'كونكور كور 2.5 مجم',
            price: 60.0,
            quantity: 2,
            status: 'InStock',
            createdAt: DateTime.now().toUtc(),
          ),
          PharmacyInventoryItemDto(
            id: 'item_3',
            medicationName: 'أوجمنتين 1 جم أقراص',
            price: 110.0,
            quantity: 0,
            status: 'OutOfStock',
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const InventoryTab(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Check stock counters
      expect(find.text('بانادول أزرق 500 مجم'), findsOneWidget);
      expect(find.text('كونكور كور 2.5 مجم'), findsOneWidget);
      expect(find.text('أوجمنتين 1 جم أقراص'), findsOneWidget);

      // Verify availability quick action buttons: متاح, محدود, غير متاح
      expect(find.text('متاح'), findsWidgets);
      expect(find.text('محدود'), findsWidgets);
      expect(find.text('غير متاح'), findsWidgets);

      // Tap 'محدود' on item_1 (sets quantity to 3)
      final limitedButtons = find.widgetWithText(InkWell, 'محدود');
      await tester.tap(limitedButtons.first);
      await tester.pumpAndSettle();

      expect(fakeApi.lastAvailabilityUpdatedId, 'item_1');
      expect(fakeApi.lastAvailabilityReq?.quantity, 3);

      // Tap 'غير متاح' on item_1 (sets quantity to 0)
      final outOfStockButtons = find.widgetWithText(InkWell, 'غير متاح');
      await tester.tap(outOfStockButtons.first);
      await tester.pumpAndSettle();

      expect(fakeApi.lastAvailabilityUpdatedId, 'item_1');
      expect(fakeApi.lastAvailabilityReq?.quantity, 0);
    });

    testWidgets('Search input filters inventory items by medication name',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient()
        ..inventoryList = [
          PharmacyInventoryItemDto(
            id: 'item_1',
            medicationName: 'بانادول أزرق',
            price: 25.0,
            quantity: 10,
            status: 'InStock',
            createdAt: DateTime.now().toUtc(),
          ),
          PharmacyInventoryItemDto(
            id: 'item_2',
            medicationName: 'كونكور 5 مجم',
            price: 60.0,
            quantity: 10,
            status: 'InStock',
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const InventoryTab(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('بانادول أزرق'), findsOneWidget);
      expect(find.text('كونكور 5 مجم'), findsOneWidget);

      // Search for 'كونكور'
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'كونكور');
      await tester.pumpAndSettle();

      expect(find.text('كونكور 5 مجم'), findsOneWidget);
      expect(find.text('بانادول أزرق'), findsNothing);
    });

    testWidgets('CSV Import sheet opens, displays format guidelines, and imports inventory',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient();

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const InventoryTab(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Tap CSV import icon button
      final csvButton = find.widgetWithText(TextButton, 'استيراد CSV');
      expect(csvButton, findsOneWidget);
      await tester.tap(csvButton);
      await tester.pumpAndSettle();

      expect(find.text('استيراد مخزون'), findsOneWidget);
      expect(find.text('الصيغة: MedicationName,Price,Status — Status = InStock أو OutOfStock'),
          findsOneWidget);

      // Tap import button
      final submitImportBtn = find.widgetWithText(FilledButton, 'استيراد');
      await tester.tap(submitImportBtn);
      await tester.pumpAndSettle();

      expect(fakeApi.bulkImportCalled, isTrue);
      expect(find.text('اتضاف 15 · اتنحّى 2'), findsOneWidget);
    });
  });

  group('3. ActiveOrdersTab & Reservation Fulfillment', () {
    testWidgets('Renders reservation card with countdown, pickup code, and localized Arabic badges',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient()
        ..reservationsList = [
          PharmacyReservationResponse(
            id: 'res_101',
            reservationCode: 'NWQ-7788',
            medicationName: 'أسبوسيد أطفال 75 مجم',
            patientDisplayName: 'محمود عصام',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 90)),
            status: 'Active',
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const ActiveOrdersTab(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Medication and patient name
      expect(find.text('أسبوسيد أطفال 75 مجم'), findsWidgets);
      expect(find.text('محمود عصام'), findsOneWidget);

      // Localized labels
      expect(find.text('كود الاستلام'), findsOneWidget);
      expect(find.text('NWQ-7788'), findsOneWidget);
      expect(find.text('صلاحية الحجز'), findsOneWidget);

      // Localized status badge (قيد التجهيز instead of Active)
      expect(find.textContaining('قيد التجهيز'), findsOneWidget);

      // Action buttons
      expect(find.widgetWithText(OutlinedButton, 'جاهز'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'تم الاستلام'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'إلغاء'), findsOneWidget);
    });

    testWidgets('Marks reservation ready and confirms pickup',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient()
        ..reservationsList = [
          PharmacyReservationResponse(
            id: 'res_101',
            reservationCode: 'NWQ-7788',
            medicationName: 'أسبوسيد أطفال 75 مجم',
            patientDisplayName: 'محمود عصام',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 90)),
            status: 'Active',
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const ActiveOrdersTab(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'جاهز'
      await tester.tap(find.widgetWithText(OutlinedButton, 'جاهز'));
      await tester.pumpAndSettle();

      expect(fakeApi.lastReadyReservationId, 'res_101');
      expect(find.textContaining('جاهز للاستلام'), findsWidgets);

      // Tap 'تم الاستلام' and verify handover proof via patient code
      await tester.tap(find.widgetWithText(FilledButton, 'تم الاستلام'));
      await tester.pumpAndSettle();

      if (find.byType(TextField).evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField), 'NWQ-7788');
        await tester.tap(find.widgetWithText(FilledButton, 'تحقق وتسليم الطلب'));
        await tester.pumpAndSettle();
      }

      expect(fakeApi.lastCompletedReservationId, 'res_101');
    });

    testWidgets('Cancellation dialog prompts for reason and cancels reservation',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient()
        ..reservationsList = [
          PharmacyReservationResponse(
            id: 'res_101',
            reservationCode: 'NWQ-7788',
            medicationName: 'أسبوسيد أطفال',
            patientDisplayName: 'محمود عصام',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 90)),
            status: 'Active',
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const ActiveOrdersTab(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'إلغاء'
      await tester.tap(find.widgetWithText(OutlinedButton, 'إلغاء'));
      await tester.pumpAndSettle();

      // Check dialog content
      expect(find.text('إلغاء الحجز'), findsWidgets);
      expect(find.text('المخزون هيرجع متاح فورًا وهيتبلغ المريض.'), findsOneWidget);

      // Enter cancellation reason
      final reasonField = find.byType(TextField);
      await tester.enterText(reasonField, 'الدواء غير متوفر حالياً');
      await tester.pumpAndSettle();

      // Tap confirm cancel (FilledButton with text 'إلغاء الحجز')
      final confirmBtn = find.widgetWithText(FilledButton, 'إلغاء الحجز');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(fakeApi.lastCancelledReservationId, 'res_101');
      expect(fakeApi.lastCancelReq?.reason, 'الدواء غير متوفر حالياً');
    });

    testWidgets('Displays localized empty state when no active reservations exist',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient()..reservationsList = [];

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const ActiveOrdersTab(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد طلبات جارية'), findsOneWidget);
      expect(find.text('ستظهر حجوزات المرضى الجديدة هنا فور وصولها بشكل لحظي.'),
          findsOneWidget);
    });
  });

  group('4. ShortageQueueTab & Nearby Requests', () {
    testWidgets('Renders shortage requests and handles claim/offer action',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient()
        ..shortageRequestsList = [
          ShortageRequestDto(
            id: 'shortage_1',
            medicationName: 'إنسولين نوفورابيد فليكس بن',
            quantityNeeded: 2,
            distanceKm: 1.8,
            notes: 'محتاج علبتين ضروري للوالد',
            createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 15)),
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
          ),
        ];

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const ShortageQueueTab(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إنسولين نوفورابيد فليكس بن'), findsOneWidget);
      expect(find.textContaining('١٫٨ كم'), findsOneWidget);
      expect(find.text('محتاج علبتين ضروري للوالد'), findsOneWidget);

      // Claim button
      final claimBtn = find.widgetWithText(FilledButton, 'اطلب الحجز للمريض (ساعتين)');
      expect(claimBtn, findsOneWidget);
      await tester.tap(claimBtn);
      await tester.pumpAndSettle();

      expect(fakeApi.lastClaimedShortageId, 'shortage_1');
      expect(find.textContaining('اتحجز للمريض'), findsOneWidget);
    });

    testWidgets('Displays empty state when no shortage requests exist nearby',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient()..shortageRequestsList = [];

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const ShortageQueueTab(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مفيش استغاثات نواقص حوالينك'), findsOneWidget);
      expect(find.textContaining('لما مريض يعجز عن دواء'), findsOneWidget);
    });
  });

  group('5. SalesLedgerScreen & Financial Records', () {
    testWidgets('Displays revenue metrics, sales entries, and live search filtering',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient();

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const SalesLedgerScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Check stats cards
      expect(find.text('طلبات اليوم'), findsOneWidget);
      expect(find.text('٨'), findsOneWidget);
      expect(find.text('إجمالي الإيراد'), findsOneWidget);
      expect(find.text('١٤٥٠ ج.م'), findsOneWidget);
      expect(find.text('كل الطلبات'), findsOneWidget);
      expect(find.text('٤٢'), findsOneWidget);

      // Check entries
      expect(find.text('كونكور 5 مجم'), findsOneWidget);
      expect(find.text('بانادول إكسترا'), findsOneWidget);

      // Search by medication name
      final searchField = find.widgetWithText(TextField, 'ابحث بدواء أو كود تصريح');
      await tester.enterText(searchField, 'كونكور');
      await tester.pumpAndSettle();

      expect(find.text('كونكور 5 مجم'), findsOneWidget);
      expect(find.text('بانادول إكسترا'), findsNothing);

      // Search by reservation code
      await tester.enterText(searchField, '8822');
      await tester.pumpAndSettle();

      expect(find.text('بانادول إكسترا'), findsOneWidget);
      expect(find.text('كونكور 5 مجم'), findsNothing);
    });
  });

  group('6. AddInventoryScreen & Medication Entry', () {
    testWidgets('Validates required fields and successfully adds new medication to inventory',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient();

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const AddInventoryScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إضافة دواء'), findsOneWidget);
      expect(find.text('اسم الدواء'), findsOneWidget);
      expect(find.text('السعر (ج.م)'), findsOneWidget);

      // Attempt submit without filling fields
      final submitBtn = find.widgetWithText(ElevatedButton, 'حفظ في المخزون');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('مطلوب'), findsOneWidget);

      // Fill valid medication name and price with Arabic digits
      final nameField = find.widgetWithText(TextFormField, 'مثلاً: باراسيتامول 500 مجم');
      final priceField = find.widgetWithText(TextFormField, '0.00');

      await tester.enterText(nameField, 'فيتامين سي 1000 فوار');
      await tester.enterText(priceField, '٤٥.٥');
      await tester.pumpAndSettle();

      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(fakeApi.lastAddInventoryReq?.medicationName, 'فيتامين سي 1000 فوار');
      expect(fakeApi.lastAddInventoryReq?.price, 45.5);
      expect(fakeApi.lastAddInventoryReq?.quantity, 10);
    });

    testWidgets('Suggests medication from official catalog and allows setting custom price and quantity',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient()
        ..suggestedList = ['كونكور 5 مجم أقراص'];

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const AddInventoryScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextFormField, 'مثلاً: باراسيتامول 500 مجم');
      final qtyField = find.widgetWithText(TextFormField, 'مثلاً: 10');
      final priceField = find.widgetWithText(TextFormField, '0.00');

      // Type partial name to trigger debounce
      await tester.enterText(nameField, 'كون');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Expect "هل تقصد من قاعدة بيانات الأدوية الرسمية؟" suggestion chip
      expect(find.text('هل تقصد من قاعدة بيانات الأدوية الرسمية؟'), findsOneWidget);
      expect(find.text('كونكور 5 مجم أقراص'), findsOneWidget);

      // Tap suggestion chip
      await tester.tap(find.text('كونكور 5 مجم أقراص'));
      await tester.pumpAndSettle();

      // Enter price and custom quantity
      await tester.enterText(qtyField, '25');
      await tester.enterText(priceField, '75.0');
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(ElevatedButton, 'حفظ في المخزون');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(fakeApi.lastAddInventoryReq?.medicationName, 'كونكور 5 مجم أقراص');
      expect(fakeApi.lastAddInventoryReq?.price, 75.0);
      expect(fakeApi.lastAddInventoryReq?.quantity, 25);
    });
  });

  group('7. PharmacyOnboardingScreen & Wizard', () {
    testWidgets('Renders all pharmacy registration fields with Arabic localization',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakePharmacyApiClient()
        ..myPharmacyData = MyPharmacyDto(
          id: 'pharm_draft',
          name: 'صيدلية النور والأمل',
          addressLine: '25 شارع فيصل',
          city: 'الجيزة',
          phone: '01099887766',
          latitude: 30.0131,
          longitude: 31.1991,
          verificationStatus: 'Pending',
          trustScore: 4.5,
          averageRating: 4.0,
          ratingCount: 10,
          createdAt: DateTime.now().toUtc(),
        );

      await tester.pumpWidget(
        buildTestPharmacyApp(
          child: const PharmacyOnboardingScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check Arabic headers and labels
      expect(find.text('تسجيل بيانات الصيدلية'), findsOneWidget);
      expect(find.text('بيانات الصيدلية'), findsOneWidget);
      expect(find.text('اسم الصيدلية'), findsOneWidget);
      expect(find.text('العنوان بالتفصيل'), findsOneWidget);
      expect(find.text('المدينة / المحافظة'), findsOneWidget);
      expect(find.text('رقم الهاتف'), findsOneWidget);
      expect(find.text('الموقع — حدد موقع الصيدلية بدقة على الخريطة'), findsOneWidget);
      expect(find.text('مستندات التحقق والتراخيص'), findsOneWidget);
      expect(find.text('تحديث البيانات وإعادة الإرسال', skipOffstage: false), findsOneWidget);

      // Pre-filled values
      expect(find.text('صيدلية النور والأمل'), findsOneWidget);
      expect(find.text('25 شارع فيصل'), findsOneWidget);
      expect(find.text('الجيزة'), findsOneWidget);
      expect(find.text('01099887766'), findsOneWidget);
    });
  });
}
