import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/auth/data/auth_models.dart';
import 'package:nawakes_mobile/features/profile/data/profile_models.dart';
import 'package:nawakes_mobile/features/profile/presentation/profile_screen.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_dashboard_models.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/active_orders_tab.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';
import 'package:nawakes_mobile/features/family_cabinet/presentation/family_cabinet_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/batch_search_results_screen.dart';

class FakeDeliveryLocationService extends LocationService {
  @override
  Future<Position?> getCurrentLocation() async => null;
}

class MockDeliveryApiClient implements ApiClient {
  List<PharmacyReservationResponse> reservations = [];
  FamilyCabinetResponseModel? familyCabinetData;
  List<PendingCaregiverInviteModel> pendingInvitesList = [];
  final List<CreateReservationRequest> capturedReservationRequests = [];
  UpdateProfileRequest? lastUpdateProfileRequest;
  ProfileResponse? profileData;

  @override
  Future<List<PharmacyReservationResponse>> getPharmacyReservations() async => reservations;

  @override
  Future<FamilyCabinetResponseModel> getFamilyCabinet() async =>
      familyCabinetData ?? FamilyCabinetResponseModel(profiles: []);

  @override
  Future<List<PendingCaregiverInviteModel>> getPendingCaregiverInvites() async => pendingInvitesList;

  @override
  Future<BatchSearchResponse> batchSearch(BatchSearchRequest request) async {
    return BatchSearchResponse(
      totalRequestedItems: 1,
      radiusKm: 35.0,
      completePharmacies: [
        BatchPharmacyResult(
          pharmacyId: 'pharm-deliv-1',
          pharmacyName: 'صيدلية النيل الحديثة',
          addressLine: 'المعادي، القاهرة',
          phone: '01011111111',
          trustScore: 4.9,
          distanceKm: 2.1,
          latitude: 29.96,
          longitude: 31.25,
          matchedCount: 1,
          totalRequested: 1,
          isCompleteMatch: true,
          totalEstimatedPrice: 50.0,
          items: [
            BatchMedicationDetail(
              medication: 'Augmentin 1g',
              requestedQuantity: 1,
              inStock: true,
              price: 50.0,
              availableQuantity: 10,
              inventoryItemId: 'inv-item-deliv-1',
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
      id: 'res-deliv-${capturedReservationRequests.length}',
      inventoryItemId: body.inventoryItemId,
      pharmacyId: 'pharm-deliv-1',
      pharmacyName: 'صيدلية النيل الحديثة',
      pharmacyPhone: '01011111111',
      medicationName: 'Augmentin 1g',
      status: 'Active',
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
      createdAt: DateTime.now(),
      reservationCode: 'NWQ-DELIV-99',
    );
  }

  @override
  Future<ProfileResponse> getProfile() async =>
      profileData ??
      ProfileResponse(
        userId: 'u_123',
        email: 'patient@nawakes.app',
        fullName: 'عمر نور',
        phone: '01012345678',
        createdAt: DateTime.utc(2026, 11, 2),
        gender: 'ذكر',
        age: 30,
        chronicConditions: 'ضغط الدم',
        knownAllergies: 'بنسلين',
      );

  @override
  Future<ProfileResponse> updateProfile(UpdateProfileRequest request) async {
    lastUpdateProfileRequest = request;
    return ProfileResponse(
      userId: 'u_123',
      email: 'patient@nawakes.app',
      fullName: request.fullName ?? 'عمر نور',
      phone: request.phone ?? '01012345678',
      createdAt: DateTime.utc(2026, 11, 2),
      gender: request.gender,
      age: request.age,
      chronicConditions: request.chronicConditions,
      knownAllergies: request.knownAllergies,
      medicalHistoryNotes: request.medicalHistoryNotes,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createTestApp({
  required Widget child,
  required MockDeliveryApiClient client,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      locationServiceProvider.overrideWithValue(FakeDeliveryLocationService()),
      pharmacyReservationsControllerProvider.overrideWith(
        () => _MockPharmacyReservationsNotifier(client),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
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

class _MockPharmacyReservationsNotifier extends PharmacyReservationsController {
  final MockDeliveryApiClient client;
  _MockPharmacyReservationsNotifier(this.client);

  @override
  Future<List<PharmacyReservationResponse>> build() async {
    return client.getPharmacyReservations();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Clinical Profile & Delivery Infrastructure Tests', () {
    test('RegisterRequest serializes gender, age, chronicConditions, and knownAllergies', () {
      final req = RegisterRequest(
        email: 'patient@nawakes.app',
        password: 'Password123',
        fullName: 'عمر نور',
        role: 'Patient',
        gender: 'ذكر',
        age: 29,
        chronicConditions: 'حساسية الصدر',
        knownAllergies: 'بنسلين ومشتقاته، سلفا',
      );

      final json = req.toJson();
      expect(json['email'], 'patient@nawakes.app');
      expect(json['role'], 'Patient');
      expect(json['gender'], 'ذكر');
      expect(json['age'], 29);
      expect(json['chronicConditions'], 'حساسية الصدر');
      expect(json['knownAllergies'], 'بنسلين ومشتقاته، سلفا');
      expect(json['healthQuestionnaire'], isNotNull);
      expect(json['healthQuestionnaire']['knownAllergies'], contains('بنسلين ومشتقاته'));
    });

    test('ProfileResponse & UpdateProfileRequest roundtrip with clinical fields', () {
      final response = ProfileResponse(
        userId: 'u_123',
        email: 'patient@nawakes.app',
        fullName: 'عمر نور',
        phone: '01012345678',
        createdAt: DateTime.utc(2026, 11, 2),
        gender: 'ذكر',
        age: 32,
        chronicConditions: 'السكري',
        knownAllergies: 'البنسلين',
      );

      final json = response.toJson();
      expect(json['gender'], 'ذكر');
      expect(json['age'], 32);
      expect(json['chronicConditions'], 'السكري');
      expect(json['knownAllergies'], 'البنسلين');

      final deserialized = ProfileResponse.fromJson(json);
      expect(deserialized.gender, 'ذكر');
      expect(deserialized.age, 32);

      final updateReq = UpdateProfileRequest(
        gender: 'أنثى',
        age: 25,
        chronicConditions: 'ضغط الدم',
        knownAllergies: 'الأسبرين',
      );
      final updateJson = updateReq.toJson();
      expect(updateJson['gender'], 'أنثى');
      expect(updateJson['age'], 25);
    });

    test('CreateReservationRequest & ReservationResponse serialize delivery fields', () {
      final req = CreateReservationRequest(
        inventoryItemId: 'item_99',
        fulfillmentType: 'Delivery',
        deliveryAddress: 'مدينة نصر - الحي السابع',
        deliveryContactPhone: '01099887766',
        deliveryNotes: 'برج الأطباء الدور الرابع',
        deliveryLatitude: 30.05,
        deliveryLongitude: 31.34,
      );

      final json = req.toJson();
      expect(json['fulfillmentType'], 'Delivery');
      expect(json['deliveryAddress'], 'مدينة نصر - الحي السابع');
      expect(json['deliveryContactPhone'], '01099887766');
      expect(json['deliveryNotes'], 'برج الأطباء الدور الرابع');
      expect(json['deliveryLatitude'], 30.05);

      final parsed = CreateReservationRequest.fromJson(json);
      expect(parsed.fulfillmentType, 'Delivery');
      expect(parsed.deliveryAddress, 'مدينة نصر - الحي السابع');
    });

    testWidgets('ActiveOrdersTab renders Delivery banner and WhatsApp dispatch button',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockDeliveryApiClient()
        ..reservations = [
          PharmacyReservationResponse(
            id: 'res_deliv_1',
            patientDisplayName: 'مريض #4321',
            medicationName: 'كونكور 5 مجم',
            status: 'Active',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
            createdAt: DateTime.now().toUtc(),
            reservationCode: 'NWQ-DELIV-88',
            fulfillmentType: 'Delivery',
            deliveryAddress: 'المعادي - شارع النصر عمارة 12',
            deliveryContactPhone: '01155443322',
            deliveryNotes: 'الشقة 8 بالدور الثالث',
            deliveryStatus: 'Pending',
            patientGender: 'ذكر',
            patientAge: 45,
          ),
        ];

      await tester.pumpWidget(createTestApp(
        child: const ActiveOrdersTab(),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('طلب توصيل للمنزل (دليفري)'), findsOneWidget);
      expect(find.textContaining('المعادي - شارع النصر'), findsOneWidget);
      expect(find.textContaining('01155443322'), findsOneWidget);
      expect(find.text('📲 إرسال للطيار عبر واتساب'), findsOneWidget);
    });

    testWidgets('FamilyCabinetScreen renders Smart Home Cabinet and Quick Presets',
        (tester) async {
      final client = MockDeliveryApiClient()
        ..familyCabinetData = FamilyCabinetResponseModel(profiles: []);

      await tester.pumpWidget(createTestApp(
        child: const FamilyCabinetScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('صيدلية البيت الذكية'), findsOneWidget);
      expect(find.text('إزاي صيدلية البيت بتفيدك؟'), findsOneWidget);
      expect(find.text('والدي 🧓'), findsOneWidget);
      expect(find.text('والدتي 👵'), findsOneWidget);
      expect(find.text('طفلي 👶'), findsOneWidget);
      expect(find.text('نفسي 👤'), findsOneWidget);
      expect(find.text('صيدلية بيتك فارغة حالياً'), findsOneWidget);
    });

    testWidgets('BatchSearchResultsScreen prompts fulfillment modal and creates delivery reservation',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockDeliveryApiClient();
      final items = [
        BatchSearchItemDto(medication: 'Augmentin 1g', quantity: 1),
      ];

      await tester.pumpWidget(createTestApp(
        child: BatchSearchResultsScreen(
          items: items,
          promptFulfillment: true,
        ),
        client: client,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final bookBtn = find.text('احجز كل الروشتة الآن ⚡');
      expect(bookBtn, findsOneWidget);
      await tester.tap(bookBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('طريقة استلام الأدوية'), findsOneWidget);
      expect(find.text('🛵 توصيل للمنزل'), findsOneWidget);
      expect(find.text('🏪 استلام من الصيدلية'), findsOneWidget);

      await tester.tap(find.text('🛵 توصيل للمنزل'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));
      await tester.enterText(textFields.at(0), 'المعادي - شارع 9');
      await tester.enterText(textFields.at(1), '01012345678');
      await tester.enterText(textFields.at(2), 'الدور الثالث');
      await tester.pump();

      await tester.tap(find.text('تأكيد الحجز'));
      await tester.pumpAndSettle();

      expect(client.capturedReservationRequests.length, 1);
      final req = client.capturedReservationRequests.first;
      expect(req.fulfillmentType, 'Delivery');
      expect(req.deliveryAddress, 'المعادي - شارع 9');
      expect(req.deliveryContactPhone, '01012345678');
      expect(req.deliveryNotes, 'الدور الثالث');
    });

    testWidgets('BatchSearchResultsScreen defaults to Pickup when selected in fulfillment modal',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockDeliveryApiClient();
      final items = [
        BatchSearchItemDto(medication: 'Augmentin 1g', quantity: 1),
      ];

      await tester.pumpWidget(createTestApp(
        child: BatchSearchResultsScreen(
          items: items,
          promptFulfillment: true,
        ),
        client: client,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final bookBtn = find.text('احجز كل الروشتة الآن ⚡');
      expect(bookBtn, findsOneWidget);
      await tester.tap(bookBtn);
      await tester.pumpAndSettle();

      expect(find.text('تأكيد الحجز'), findsOneWidget);
      await tester.tap(find.text('تأكيد الحجز'));
      await tester.pumpAndSettle();

      expect(client.capturedReservationRequests.length, 1);
      final req = client.capturedReservationRequests.first;
      expect(req.fulfillmentType, 'Pickup');
    });

    testWidgets('ProfileScreen saves clinical attributes (gender, age, conditions, allergies)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockDeliveryApiClient();

      await tester.pumpWidget(createTestApp(
        child: const ProfileScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      final editBtn = find.text('تعديل');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      final saveBtn = find.text('حفظ التغييرات');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(client.lastUpdateProfileRequest, isNotNull);
      expect(client.lastUpdateProfileRequest!.gender, 'ذكر');
      expect(client.lastUpdateProfileRequest!.age, 30);
      expect(client.lastUpdateProfileRequest!.chronicConditions, 'ضغط الدم');
      expect(client.lastUpdateProfileRequest!.knownAllergies, 'بنسلين');
    });
  });
}
