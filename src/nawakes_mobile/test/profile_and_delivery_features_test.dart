import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/auth/data/auth_models.dart';
import 'package:nawakes_mobile/features/profile/data/profile_models.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_dashboard_models.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/active_orders_tab.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';
import 'package:nawakes_mobile/features/family_cabinet/presentation/family_cabinet_screen.dart';

class MockDeliveryApiClient implements ApiClient {
  List<PharmacyReservationResponse> reservations = [];
  FamilyCabinetResponseModel? familyCabinetData;
  List<PendingCaregiverInviteModel> pendingInvitesList = [];

  @override
  Future<List<PharmacyReservationResponse>> getPharmacyReservations() async => reservations;

  @override
  Future<FamilyCabinetResponseModel> getFamilyCabinet() async =>
      familyCabinetData ?? FamilyCabinetResponseModel(profiles: []);

  @override
  Future<List<PendingCaregiverInviteModel>> getPendingCaregiverInvites() async => pendingInvitesList;

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
        child: child,
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
  });
}
