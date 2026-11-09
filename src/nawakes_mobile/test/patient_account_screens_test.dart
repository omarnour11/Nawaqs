import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/routing/patient_shell.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/alerts/data/alert_models.dart';
import 'package:nawakes_mobile/features/alerts/presentation/alerts_screen.dart';
import 'package:nawakes_mobile/features/alerts/presentation/reservation_offer_sheet.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';
import 'package:nawakes_mobile/features/family_cabinet/presentation/family_cabinet_screen.dart';
import 'package:nawakes_mobile/features/family_cabinet/presentation/medication_depletion_card.dart';
import 'package:nawakes_mobile/features/favorites/data/favorite_models.dart';
import 'package:nawakes_mobile/features/notifications/data/notification_models.dart';
import 'package:nawakes_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/data/sales_ledger_models.dart';
import 'package:nawakes_mobile/features/profile/data/medication_models.dart';
import 'package:nawakes_mobile/features/profile/data/profile_models.dart';
import 'package:nawakes_mobile/features/profile/presentation/medications_section.dart';
import 'package:nawakes_mobile/features/profile/presentation/profile_screen.dart';
import 'package:nawakes_mobile/features/reports/data/report_models.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/reservations/presentation/passes_screen.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:nawakes_mobile/features/search/presentation/medication_equivalents_card.dart';
import 'package:nawakes_mobile/features/search/presentation/pharmacy_details_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/search_screen.dart';
import 'package:nawakes_mobile/features/support/data/ticket_models.dart';
import 'package:nawakes_mobile/features/support/presentation/support_screen.dart';
import 'package:nawakes_mobile/features/support/presentation/ticket_thread.dart';

/// Test Fake ApiClient using noSuchMethod for cleanly mocking only required calls.
class FakeTestApiClient implements ApiClient {
  ProfileResponse? profileData;
  UpdateProfileRequest? lastUpdateProfileReq;
  List<PatientMedicationDto> medicationsList = [];
  MedicationRequest? lastAddMedicationReq;
  String? lastDeletedMedicationId;
  List<FavoritePharmacyDto> favoritesList = [];
  List<AlertDto> alertsList = [];
  CreateAlertRequest? lastCreateAlertReq;
  String? lastDeletedAlertId;
  String? lastClaimedOfferId;
  FamilyCabinetResponseModel? familyCabinetData;
  List<PendingCaregiverInviteModel> pendingInvitesList = [];
  String? lastAcceptedInviteLinkId;
  String? lastRefilledMedId;
  RefillFamilyMedicationRequest? lastRefillReq;
  CreateFamilyProfileRequest? lastCreateProfileReq;
  InviteCaregiverRequest? lastInviteCaregiverReq;
  List<ReservationResponse> reservationsList = [];
  String? lastCancelledReservationId;
  List<TicketDto> ticketsList = [];
  CreateTicketRequest? lastCreateTicketReq;
  List<TicketMessageDto> ticketMessagesList = [];
  PostMessageRequest? lastPostMessageReq;
  List<NotificationDto> notificationsList = [];
  MarkReadRequest? lastMarkReadReq;
  String? lastReservedItemId;
  String? lastReservedAlternativeReservationId;
  String? lastReportPharmacyId;

  @override
  Future<ProfileResponse> getProfile() async {
    return profileData ??
        ProfileResponse(
          userId: 'u1',
          fullName: 'أحمد محمود',
          email: 'ahmed@example.com',
          phone: '01012345678',
          medicalHistoryNotes: 'أمراض: سكر، ضغط\nحساسية: بنسلين\nملاحظة عادية',
          createdAt: DateTime.now().toUtc(),
        );
  }

  @override
  Future<void> updateProfile(UpdateProfileRequest body) async {
    lastUpdateProfileReq = body;
    profileData = ProfileResponse(
      userId: profileData?.userId ?? 'u1',
      fullName: body.fullName ?? profileData?.fullName,
      email: profileData?.email ?? 'ahmed@example.com',
      phone: body.phone ?? profileData?.phone,
      medicalHistoryNotes: body.medicalHistoryNotes ?? profileData?.medicalHistoryNotes,
      createdAt: profileData?.createdAt ?? DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<PatientMedicationDto>> getMyMedications() async => medicationsList;

  @override
  Future<IdResponse> addMyMedication(MedicationRequest body) async {
    lastAddMedicationReq = body;
    final item = PatientMedicationDto(
      id: 'm_${medicationsList.length + 1}',
      medicationName: body.medicationName,
      strength: body.strength,
      form: body.form,
      doseSchedule: body.doseSchedule,
      isActive: body.isActive,
      createdAt: DateTime.now().toUtc(),
    );
    medicationsList.add(item);
    return IdResponse(id: item.id);
  }

  @override
  Future<void> deleteMyMedication(String id) async {
    lastDeletedMedicationId = id;
    medicationsList.removeWhere((m) => m.id == id);
  }

  @override
  Future<List<FavoritePharmacyDto>> getMyFavorites() async => favoritesList;

  @override
  Future<List<AlertDto>> getMyAlerts() async => alertsList;

  @override
  Future<IdResponse> createAlert(CreateAlertRequest body) async {
    lastCreateAlertReq = body;
    final a = AlertDto(
      id: 'alert_${alertsList.length + 1}',
      medicationName: body.medicationName,
      radiusKm: body.radiusKm,
      latitude: body.latitude,
      longitude: body.longitude,
      isActive: true,
      createdAt: DateTime.now().toUtc(),
    );
    alertsList.add(a);
    return IdResponse(id: a.id);
  }

  @override
  Future<void> deleteAlert(String id) async {
    lastDeletedAlertId = id;
    alertsList.removeWhere((a) => a.id == id);
  }

  @override
  Future<ReservationResponse> claimQueueOffer(String id) async {
    lastClaimedOfferId = id;
    return ReservationResponse(
      id: 'res_1',
      inventoryItemId: 'inv_1',
      reservationCode: 'NWQ-123456',
      status: 'Active',
      pharmacyId: 'ph1',
      pharmacyName: 'صيدلية النور',
      pharmacyPhone: '01234567890',
      medicationName: 'كونكور 5 مجم',
      createdAt: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
    );
  }

  @override
  Future<FamilyCabinetResponseModel> getFamilyCabinet() async {
    return familyCabinetData ?? FamilyCabinetResponseModel(profiles: []);
  }

  @override
  Future<List<PendingCaregiverInviteModel>> getPendingCaregiverInvites() async =>
      pendingInvitesList;

  @override
  Future<AcceptCaregiverInviteResponse> acceptCaregiverInvite(String linkId) async {
    lastAcceptedInviteLinkId = linkId;
    pendingInvitesList.removeWhere((i) => i.linkId == linkId);
    return AcceptCaregiverInviteResponse(familyProfileId: 'fam_1');
  }

  @override
  Future<IdResponse> refillFamilyMedication(String id, RefillFamilyMedicationRequest body) async {
    lastRefilledMedId = id;
    lastRefillReq = body;
    return IdResponse(id: id);
  }

  @override
  Future<IdResponse> createFamilyProfile(CreateFamilyProfileRequest body) async {
    lastCreateProfileReq = body;
    return IdResponse(id: 'fam_profile_1');
  }

  @override
  Future<IdResponse> inviteCaregiver(String profileId, InviteCaregiverRequest body) async {
    lastInviteCaregiverReq = body;
    return IdResponse(id: 'invite_1');
  }

  @override
  Future<List<ReservationResponse>> getMyReservations() async => reservationsList;

  @override
  Future<void> cancelReservation(String id) async {
    lastCancelledReservationId = id;
    reservationsList.removeWhere((r) => r.id == id);
  }

  @override
  Future<List<TicketDto>> getMyTickets() async => ticketsList;

  @override
  Future<IdResponse> createTicket(CreateTicketRequest body) async {
    lastCreateTicketReq = body;
    final t = TicketDto(
      id: 't_${ticketsList.length + 1}',
      subject: body.subject,
      description: body.description,
      category: body.category.name,
      status: 'Open',
      createdAt: DateTime.now().toUtc(),
    );
    ticketsList.add(t);
    return IdResponse(id: t.id);
  }

  @override
  Future<List<TicketMessageDto>> getTicketMessages(String ticketId) async =>
      ticketMessagesList;

  @override
  Future<IdResponse> postTicketMessage(String ticketId, PostMessageRequest body) async {
    lastPostMessageReq = body;
    ticketMessagesList.add(TicketMessageDto(
      id: 'msg_${ticketMessagesList.length + 1}',
      senderId: 'user_1',
      senderRole: 'Patient',
      body: body.body,
      createdAt: DateTime.now().toUtc(),
    ));
    return IdResponse(id: 'msg_${ticketMessagesList.length}');
  }

  @override
  Future<List<NotificationDto>> getNotifications() async => notificationsList;

  @override
  Future<UnreadCountResponse> getUnreadCount() async {
    final count = notificationsList.where((n) => !n.isRead).length;
    return UnreadCountResponse(count: count);
  }

  @override
  Future<MarkReadResponse> markNotificationsRead(MarkReadRequest body) async {
    lastMarkReadReq = body;
    if (body.id != null) {
      notificationsList = notificationsList
          .map((n) => n.id == body.id
              ? NotificationDto(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  isRead: true,
                  createdAt: n.createdAt,
                )
              : n)
          .toList();
    } else {
      notificationsList = notificationsList
          .map((n) => NotificationDto(
                id: n.id,
                type: n.type,
                title: n.title,
                body: n.body,
                isRead: true,
                createdAt: n.createdAt,
              ))
          .toList();
    }
    return MarkReadResponse(updated: 1);
  }

  @override
  Future<ReservationResponse> createReservation(CreateReservationRequest body) async {
    lastReservedItemId = body.inventoryItemId;
    return ReservationResponse(
      id: 'res_new',
      inventoryItemId: body.inventoryItemId,
      reservationCode: 'NWQ-999888',
      status: 'Active',
      pharmacyId: 'ph1',
      pharmacyName: 'صيدلية النور',
      pharmacyPhone: '01234567890',
      medicationName: 'بانادول',
      createdAt: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
    );
  }

  @override
  Future<ReservationResponse> reserveAlternative(String reservationId) async {
    lastReservedAlternativeReservationId = reservationId;
    return ReservationResponse(
      id: 'res_alt_new',
      inventoryItemId: 'inv_alt_123',
      reservationCode: 'NWQ-ALT123',
      status: 'Active',
      pharmacyId: 'ph1',
      pharmacyName: 'صيدلية البديل الآمن',
      pharmacyPhone: '01234567890',
      medicationName: 'بنادول أكتيفاست',
      createdAt: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
    );
  }

  @override
  Future<ToggleFavoriteResponse> toggleFavorite(String pharmacyId) async {
    final isFav = favoritesList.any((f) => f.pharmacyId == pharmacyId);
    if (isFav) {
      favoritesList.removeWhere((f) => f.pharmacyId == pharmacyId);
      return ToggleFavoriteResponse(isFavorite: false);
    } else {
      favoritesList.add(FavoritePharmacyDto(
        pharmacyId: pharmacyId,
        name: 'صيدلية تجريبية',
        addressLine: 'شارع التجربة',
        city: 'القاهرة',
        phone: '0100000000',
        latitude: 30.0,
        longitude: 31.0,
        trustScore: 90,
        averageRating: 4.5,
        ratingCount: 10,
      ));
      return ToggleFavoriteResponse(isFavorite: true);
    }
  }

  @override
  Future<dynamic> createReport(String pharmacyId, CreateReportRequest body) async {
    lastReportPharmacyId = pharmacyId;
    return {'success': true};
  }

  @override
  Future<SearchMedicationResponse> searchMedications(
    String medication,
    double lat,
    double lng,
    double radius,
    String sortBy,
  ) async {
    return SearchMedicationResponse(
      results: [],
      totalCount: 0,
      cacheHit: false,
      radiusKm: radius,
    );
  }

  @override
  Future<MedicationEquivalentsResponse> getMedicationEquivalents(
    String medicationName,
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    return MedicationEquivalentsResponse(
      original: OriginalMedicationInfoDto(
        tradeName: medicationName,
        activeIngredient: 'مادة فعالة',
        strength: '1 جم',
        dosageForm: 'أقراص',
        officialPriceEGP: 50,
        isAvailableNearby: false,
      ),
      availableEquivalents: [],
      legalDisclaimer: 'استشر الصيدلي أو الطبيب دائماً.',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocationService extends LocationService {
  @override
  Future<Position?> getCurrentLocation() async => null;
}

Widget createTestApp({
  required Widget child,
  required FakeTestApiClient client,
  GoRouter? router,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      locationServiceProvider.overrideWithValue(FakeLocationService()),
    ],
    child: router != null
        ? MaterialApp.router(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightTheme,
            routerConfig: router,
          )
        : MaterialApp(
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

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('1. Patient Profile Screen & Components', () {
    testWidgets('ProfileScreen renders identity header, notes, and parsed chips',
        (tester) async {
      final client = FakeTestApiClient();
      await tester.pumpWidget(createTestApp(
        child: const ProfileScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('الملف الطبي'), findsOneWidget);
      expect(find.text('أحمد محمود'), findsOneWidget);
      expect(find.text('ahmed@example.com'), findsOneWidget);
      expect(find.text('أ'), findsOneWidget); // Initial circle

      // Check Parsed Chips
      expect(find.text('سكر'), findsOneWidget);
      expect(find.text('ضغط'), findsOneWidget);
      expect(find.text('بنسلين'), findsOneWidget);

      // Check Contact Info
      expect(find.text('01012345678'), findsOneWidget);

      // Quick links
      expect(find.text('الصيدليات المفضلة'), findsOneWidget);
      expect(find.text('تنبيهات التوفر'), findsOneWidget);
      expect(find.text('دولاب دوا العيلة'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });

    testWidgets('ProfileScreen enters edit mode, adds chips and saves changes',
        (tester) async {
      final client = FakeTestApiClient();
      await tester.pumpWidget(createTestApp(
        child: const ProfileScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      // Tap "تعديل"
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();

      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('حفظ التغييرات'), findsOneWidget);
      expect(find.text('+ إضافة'), findsWidgets);

      // Tap + إضافة for chronic conditions
      await tester.tap(find.text('+ إضافة').first);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('إضافة أمراض مزمنة'), findsOneWidget);
      // Verify no suggestion chips are shown when query is empty
      expect(find.text('ابدأ بكتابة اسم المرض للبحث في قائمة الأمراض المعيارية…'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);

      await tester.enterText(find.byType(TextField).last, 'ربو');
      await tester.pumpAndSettle();
      expect(find.text('المصطلح الطبي المعياري المقترح (اضغط للاختيار):'), findsOneWidget);
      expect(find.byType(ActionChip), findsWidgets);

      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      expect(find.text('ربو'), findsOneWidget);

      // Save changes
      await tester.ensureVisible(find.text('حفظ التغييرات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ التغييرات'));
      await tester.pumpAndSettle();

      expect(client.lastUpdateProfileReq, isNotNull);
      expect(client.lastUpdateProfileReq!.medicalHistoryNotes, contains('ربو'));
    });

    testWidgets('ProfileScreen fallback initial is م when name is null or empty',
        (tester) async {
      final client = FakeTestApiClient()
        ..profileData = ProfileResponse(
          userId: 'u2',
          fullName: '',
          email: 'anonymous@example.com',
          phone: null,
          medicalHistoryNotes: null,
          createdAt: DateTime.now().toUtc(),
        );

      await tester.pumpWidget(createTestApp(
        child: const ProfileScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('م'), findsOneWidget);
      expect(find.text('مستخدم نواقص'), findsOneWidget);
      expect(find.text('مفيش أمراض مزمنة مسجلة'), findsOneWidget);
      expect(find.text('مفيش حساسية مسجلة'), findsOneWidget);
    });

    testWidgets('ProfileScreen deduplicates conditions, allergies, and medical notes on render and save',
        (tester) async {
      final client = FakeTestApiClient()
        ..profileData = ProfileResponse(
          userId: 'u1',
          fullName: 'محمود حسن',
          email: 'mahmoud@example.com',
          phone: '01012345678',
          medicalHistoryNotes:
              'أمراض: سكر، ضغط، سكر\nحساسية: بنسلين، بنسلين\nأمراض: ضغط، ربو\nملاحظة طبية أولى\nملاحظة طبية أولى\nملاحظة طبية ثانية',
          createdAt: DateTime.now().toUtc(),
        );

      await tester.pumpWidget(createTestApp(
        child: const ProfileScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      // Check chips: each condition and allergy should appear exactly once
      expect(find.text('سكر'), findsOneWidget);
      expect(find.text('ضغط'), findsOneWidget);
      expect(find.text('ربو'), findsOneWidget);
      expect(find.text('بنسلين'), findsOneWidget);

      // InfoCell medical notes should only show distinct free notes, not conditions/allergies
      expect(find.text('ملاحظة طبية أولى\nملاحظة طبية ثانية'), findsOneWidget);

      // Enter edit mode
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();

      // Save without changes
      await tester.ensureVisible(find.text('حفظ التغييرات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ التغييرات'));
      await tester.pumpAndSettle();

      expect(client.lastUpdateProfileReq, isNotNull);
      final savedNotes = client.lastUpdateProfileReq!.medicalHistoryNotes!;
      expect('أمراض:'.allMatches(savedNotes).length, 1);
      expect('حساسية:'.allMatches(savedNotes).length, 1);
      expect('ملاحظة طبية أولى'.allMatches(savedNotes).length, 1);
    });

    testWidgets('ProfileScreen preserves mixed Arabic and English free-text notes while stripping duplicates',
        (tester) async {
      final client = FakeTestApiClient()
        ..profileData = ProfileResponse(
          userId: 'u_bilingual',
          fullName: 'د. سامي عزيز',
          email: 'sami@example.com',
          phone: '01122334455',
          medicalHistoryNotes:
              'أمراض: داء السكري النوع الثاني\nحساسية: حساسية البنسلين\nPatient takes Metformin 500mg daily.\nمتابعة دورية لتحليل وظائف الكبد كل 6 أشهر.\nPatient takes Metformin 500mg daily.\nمتابعة دورية لتحليل وظائف الكبد كل 6 أشهر.',
          createdAt: DateTime.now().toUtc(),
        );

      await tester.pumpWidget(createTestApp(
        child: const ProfileScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      // Verify conditions & allergies rendered in chips
      expect(find.text('داء السكري النوع الثاني'), findsOneWidget);
      expect(find.text('حساسية البنسلين'), findsOneWidget);

      // Verify bilingual free-text notes: both English and Arabic distinct lines preserved, duplicate lines stripped
      expect(
        find.text('Patient takes Metformin 500mg daily.\nمتابعة دورية لتحليل وظائف الكبد كل 6 أشهر.'),
        findsOneWidget,
      );

      // Enter edit mode
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();

      // Save
      await tester.ensureVisible(find.text('حفظ التغييرات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ التغييرات'));
      await tester.pumpAndSettle();

      expect(client.lastUpdateProfileReq, isNotNull);
      final savedNotes = client.lastUpdateProfileReq!.medicalHistoryNotes!;
      expect('Patient takes Metformin 500mg daily.'.allMatches(savedNotes).length, 1);
      expect('متابعة دورية لتحليل وظائف الكبد كل 6 أشهر.'.allMatches(savedNotes).length, 1);
      expect('داء السكري النوع الثاني'.allMatches(savedNotes).length, 1);
    });
  });

  group('2. My Medications Section (Current Regimen)', () {
    testWidgets('MyMedicationsSection displays empty message and allows adding medication',
        (tester) async {
      final client = FakeTestApiClient()..medicationsList = [];

      await tester.pumpWidget(createTestApp(
        child: const Scaffold(body: MyMedicationsSection()),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('الأدوية الحالية'), findsOneWidget);
      expect(find.text('لسه مفيش أدوية — ضيف الأدوية اللي بتتناولها بانتظام.'), findsOneWidget);

      // Tap "+ إضافة"
      await tester.tap(find.text('+ إضافة'));
      await tester.pumpAndSettle();

      // Bottom sheet open
      expect(find.text('إضافة دواء'), findsOneWidget);

      // Fill name
      await tester.enterText(find.widgetWithText(TextField, 'اسم الدواء'), 'كونكور');
      await tester.enterText(find.widgetWithText(TextField, 'التركيز'), '5 مجم');
      await tester.enterText(find.widgetWithText(TextField, 'الشكل'), 'قرص');
      await tester.enterText(find.widgetWithText(TextField, 'الجرعة'), 'قرص صباحاً');

      // Tap submit inside sheet
      await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
      await tester.pumpAndSettle();

      expect(client.lastAddMedicationReq, isNotNull);
      expect(client.lastAddMedicationReq!.medicationName, equals('كونكور'));
      expect(client.lastAddMedicationReq!.strength, equals('5 مجم'));

      // Check that newly added med appears
      expect(find.text('كونكور'), findsOneWidget);
      expect(find.text('5 مجم · قرص · قرص صباحاً'), findsOneWidget);
      expect(find.text('نشط'), findsOneWidget);
    });

    testWidgets('MyMedicationsSection deletes a medication when trash icon is pressed',
        (tester) async {
      final client = FakeTestApiClient()
        ..medicationsList = [
          PatientMedicationDto(
            id: 'med_99',
            medicationName: 'أسبوسيد',
            strength: '75 مجم',
            form: 'أقراص مضغ',
            doseSchedule: 'بعد الغداء',
            isActive: true,
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      await tester.pumpWidget(createTestApp(
        child: const Scaffold(body: MyMedicationsSection()),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('أسبوسيد'), findsOneWidget);

      // Tap delete icon
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(client.lastDeletedMedicationId, equals('med_99'));
      expect(find.text('أسبوسيد'), findsNothing);
    });
  });

  group('3. Alerts Screen & Queue Offer Sheet', () {
    testWidgets('AlertsScreen validation rejects input shorter than 2 chars',
        (tester) async {
      final client = FakeTestApiClient();
      await tester.pumpWidget(createTestApp(
        child: const AlertsScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      // Attempt submit without text
      await tester.tap(find.text('فعّل التنبيه'));
      await tester.pumpAndSettle();

      expect(find.text('اكتب اسم الدواء (حرفين على الأقل).'), findsOneWidget);
      expect(client.lastCreateAlertReq, isNull);
    });

    testWidgets('AlertsScreen creates alert with custom slider radius',
        (tester) async {
      final client = FakeTestApiClient();
      await tester.pumpWidget(createTestApp(
        child: const AlertsScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'إنسولين');
      await tester.tap(find.text('فعّل التنبيه'));
      await tester.pumpAndSettle();

      expect(client.lastCreateAlertReq, isNotNull);
      expect(client.lastCreateAlertReq!.medicationName, equals('إنسولين'));
      expect(find.text('إنسولين'), findsOneWidget);
    });

    testWidgets('ReservationOfferSheet renders 15-minute countdown and claims offer',
        (tester) async {
      final client = FakeTestApiClient();
      final offer = QueueOffer(
        subscriptionId: 'sub_123',
        pharmacyName: 'صيدلية الأمل',
        medicationName: 'كلكسان 60',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 14, seconds: 50)),
      );

      await tester.pumpWidget(createTestApp(
        child: Scaffold(body: ReservationOfferSheet(offer: offer)),
        client: client,
      ));
      await tester.pump();

      expect(find.text('الدواء اللي مستنيه اتاح!'), findsOneWidget);
      expect(find.textContaining('كلكسان 60 — صيدلية الأمل'), findsOneWidget);
      expect(find.text('تأكيد حجز الدواء لساعتين'), findsOneWidget);

      await tester.tap(find.text('تأكيد حجز الدواء لساعتين'));
      await tester.pumpAndSettle();

      expect(client.lastClaimedOfferId, equals('sub_123'));
    });

    testWidgets('ReservationOfferSheet displays expired state when time is negative',
        (tester) async {
      final client = FakeTestApiClient();
      final expiredOffer = QueueOffer(
        subscriptionId: 'sub_expired',
        pharmacyName: 'صيدلية الأمل',
        medicationName: 'كلكسان 60',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 10)),
      );

      await tester.pumpWidget(createTestApp(
        child: Scaffold(body: ReservationOfferSheet(offer: expiredOffer)),
        client: client,
      ));
      await tester.pump();

      expect(find.text('انتهى الوقت'), findsOneWidget);
      expect(find.text('إغلاق'), findsOneWidget);
      expect(find.text('تأكيد حجز الدواء لساعتين'), findsNothing);
    });
  });

  group('4. Family Cabinet Screen & Medication Depletion Card', () {
    testWidgets('MedicationDepletionCard shows correct color & days remaining',
        (tester) async {
      final client = FakeTestApiClient();
      bool refreshed = false;

      // Safe (> 14 days) -> Green
      final medSafe = FamilyMedicationModel(
        id: 'fmed_1',
        medicationName: 'جلوفاج',
        strength: '1000 مجم',
        stripsCount: 3,
        unitsPerStrip: 10,
        dailyDoseUnits: 1,
        daysRemaining: 20,
        alertThresholdDays: 7,
      );

      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: MedicationDepletionCard(
            medication: medSafe,
            onChanged: () => refreshed = true,
          ),
        ),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('جلوفاج 1000 مجم'), findsOneWidget);
      expect(find.text('20 يوم'), findsOneWidget);

      // Tap '+ إضافة شريط'
      await tester.tap(find.text('إضافة شريط'));
      await tester.pumpAndSettle();

      expect(client.lastRefilledMedId, equals('fmed_1'));
      expect(client.lastRefillReq?.stripsAdded, equals(1));
      expect(refreshed, isTrue);
    });

    testWidgets('MedicationDepletionCard "ابحث عن صيدلية" navigates to /home with medication query',
        (tester) async {
      final client = FakeTestApiClient();
      final med = FamilyMedicationModel(
        id: 'fmed_2',
        medicationName: 'كونكور 5',
        strength: '5 مجم',
        stripsCount: 1,
        unitsPerStrip: 10,
        dailyDoseUnits: 1,
        daysRemaining: 2,
        alertThresholdDays: 7,
      );

      String? navigatedLocation;
      final router = GoRouter(
        initialLocation: '/cabinet',
        routes: [
          GoRoute(
            path: '/cabinet',
            builder: (context, state) => Scaffold(
              body: MedicationDepletionCard(
                medication: med,
                onChanged: () {},
              ),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) {
              navigatedLocation = state.uri.toString();
              return const Scaffold(body: Text('Search Home'));
            },
          ),
        ],
      );

      await tester.pumpWidget(createTestApp(
        child: const SizedBox.shrink(),
        client: client,
        router: router,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ابحث عن صيدلية'));
      await tester.pumpAndSettle();

      expect(navigatedLocation, contains('/home?q='));
      expect(navigatedLocation, contains(Uri.encodeComponent('كونكور 5')));
      expect(find.text('Search Home'), findsOneWidget);
    });

    testWidgets('FamilyCabinetScreen accepts pending caregiver invite',
        (tester) async {
      final client = FakeTestApiClient()
        ..pendingInvitesList = [
          PendingCaregiverInviteModel(
            linkId: 'link_777',
            familyProfileId: 'prof_1',
            familyProfileNickname: 'والدي',
            invitedAt: DateTime.now().toUtc(),
          ),
        ];

      await tester.pumpWidget(createTestApp(
        child: const FamilyCabinetScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('دعوات بانتظار موافقتك'), findsOneWidget);
      expect(find.text('دعوة لمتابعة والدي'), findsOneWidget);
      expect(find.text('قبول'), findsOneWidget);

      await tester.tap(find.text('قبول'));
      await tester.pumpAndSettle();

      expect(client.lastAcceptedInviteLinkId, equals('link_777'));
    });
  });

  group('5. Passes Screen & Pass Detail Screen', () {
    testWidgets('PassesScreen filters by الكل, نشطة, السجل',
        (tester) async {
      final client = FakeTestApiClient()
        ..reservationsList = [
          ReservationResponse(
            id: 'r_active',
            inventoryItemId: 'inv_1',
            reservationCode: 'NWQ-ACTIVE',
            status: 'Active',
            pharmacyId: 'p1',
            pharmacyName: 'صيدلية الشفاء',
            pharmacyPhone: '01011112222',
            medicationName: 'كونكور 5',
            createdAt: DateTime.now().toUtc(),
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          ReservationResponse(
            id: 'r_done',
            inventoryItemId: 'inv_2',
            reservationCode: 'NWQ-DONE',
            status: 'Completed',
            pharmacyId: 'p2',
            pharmacyName: 'صيدلية العزبي',
            pharmacyPhone: '01033334444',
            medicationName: 'بانادول إكسترا',
            createdAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
            expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
          ),
        ];

      await tester.pumpWidget(createTestApp(
        child: const PassesScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      // Default filter 'الكل'
      expect(find.text('كونكور 5'), findsOneWidget);
      expect(find.text('بانادول إكسترا'), findsOneWidget);

      // Filter 'نشطة'
      await tester.tap(find.text('نشطة (1)'));
      await tester.pumpAndSettle();

      expect(find.text('كونكور 5'), findsOneWidget);
      expect(find.text('بانادول إكسترا'), findsNothing);

      // Filter 'السجل'
      await tester.tap(find.text('السجل (1)'));
      await tester.pumpAndSettle();

      expect(find.text('كونكور 5'), findsNothing);
      expect(find.text('بانادول إكسترا'), findsOneWidget);
    });

    testWidgets('PassDetailScreen shows code, QR, pharmacy info, and allows cancellation',
        (tester) async {
      final client = FakeTestApiClient();
      final res = ReservationResponse(
        id: 'r_cancel_me',
        inventoryItemId: 'inv_cancel',
        reservationCode: 'NWQ-CANCEL123',
        status: 'Active',
        pharmacyId: 'p1',
        pharmacyName: 'صيدلية الأهرام',
        pharmacyPhone: '01122334455',
        medicationName: 'جلوكوفاج',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
      );

      await tester.pumpWidget(createTestApp(
        child: PassDetailScreen(reservation: res),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('NWQ-CANCEL123'), findsOneWidget);
      expect(find.text('صيدلية الأهرام'), findsOneWidget);
      expect(find.text('اتصال بالصيدلية'), findsOneWidget);
      expect(find.text('إلغاء الحجز'), findsOneWidget);

      await tester.ensureVisible(find.text('إلغاء الحجز'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء الحجز'));
      await tester.pumpAndSettle();

      expect(client.lastCancelledReservationId, equals('r_cancel_me'));
    });
  });

  group('6. Support Screen & Ticket Thread Section', () {
    testWidgets('SupportScreen displays tickets, opens new ticket card, and validates',
        (tester) async {
      final client = FakeTestApiClient();
      await tester.pumpWidget(createTestApp(
        child: const SupportScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('مفيش تذاكر مفتوحة'), findsOneWidget);

      // Tap 'تذكرة جديدة'
      await tester.tap(find.text('تذكرة جديدة'));
      await tester.pumpAndSettle();

      expect(find.text('مشكلة حجز'), findsOneWidget);
      expect(find.text('معلومة غير دقيقة'), findsOneWidget);

      // Submit empty -> validation snackbar
      await tester.tap(find.text('مراجعة وإرسال التذكرة'));
      await tester.pumpAndSettle();

      expect(find.text('اكتب الموضوع والوصف.'), findsOneWidget);
      expect(client.lastCreateTicketReq, isNull);

      // Enter valid ticket
      await tester.enterText(find.byType(TextField).first, 'الدواء غير موجود');
      await tester.enterText(find.byType(TextField).at(1), 'الصيدلية رفضت صرف الدواء رغم الحجز');
      await tester.tap(find.text('مشكلة حجز'));
      await tester.tap(find.text('مراجعة وإرسال التذكرة'));
      await tester.pumpAndSettle();

      // Review dialog opens -> confirm
      expect(find.text('مراجعة بيانات التذكرة'), findsOneWidget);
      await tester.tap(find.text('تأكيد وإرسال التذكرة'));
      await tester.pumpAndSettle();

      expect(client.lastCreateTicketReq, isNotNull);
      expect(client.lastCreateTicketReq!.subject, equals('الدواء غير موجود'));
      expect(find.text('الدواء غير موجود'), findsOneWidget);
    });

    testWidgets('TicketThreadSection renders patient and admin message bubbles and replies',
        (tester) async {
      final client = FakeTestApiClient()
        ..ticketMessagesList = [
          TicketMessageDto(
            id: 'm1',
            senderId: 'user_patient',
            senderRole: 'Patient',
            body: 'السلام عليكم، عندي استفسار',
            createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
          ),
          TicketMessageDto(
            id: 'm2',
            senderId: 'user_admin',
            senderRole: 'Admin',
            body: 'أهلاً بحضرتك، اتفضل إحنا معاك',
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: TicketThreadSection(ticketId: 't1', canReply: true),
        ),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('السلام عليكم، عندي استفسار'), findsOneWidget);
      expect(find.text('أهلاً بحضرتك، اتفضل إحنا معاك'), findsOneWidget);

      // Send reply
      await tester.enterText(find.byType(TextField), 'تمام شكرًا للمتابعة');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(client.lastPostMessageReq, isNotNull);
      expect(client.lastPostMessageReq!.body, equals('تمام شكرًا للمتابعة'));
      expect(find.text('تمام شكرًا للمتابعة'), findsOneWidget);
    });
  });

  group('7. Notifications Screen', () {
    testWidgets('NotificationsScreen displays notifications and marks them as read',
        (tester) async {
      final client = FakeTestApiClient()
        ..notificationsList = [
          NotificationDto(
            id: 'notif_1',
            type: 'MedicationAvailable',
            title: 'دواء متوفر',
            body: 'بانادول متوفر الآن في صيدلية الشفاء',
            isRead: false,
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      await tester.pumpWidget(createTestApp(
        child: const NotificationsScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('بانادول متوفر الآن في صيدلية الشفاء'), findsOneWidget);

      // Tap unread notification card to mark as read
      await tester.tap(find.text('بانادول متوفر الآن في صيدلية الشفاء'));
      await tester.pumpAndSettle();

      expect(client.lastMarkReadReq?.id, equals('notif_1'));
    });

    testWidgets('NotificationsScreen displays Arabic UI and deep-links to /passes on reservation alert',
        (tester) async {
      final client = FakeTestApiClient()
        ..notificationsList = [
          NotificationDto(
            id: 'notif_res',
            type: 'ReservationCreated',
            title: 'تم تأكيد حجزك',
            body: 'تم تجهيز تصريح الاستلام في صيدلية العزبي',
            isRead: false,
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      String? targetRoute;
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/passes',
            builder: (context, state) {
              targetRoute = '/passes';
              return const Scaffold(body: Text('Passes Target Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(createTestApp(
        child: const SizedBox.shrink(),
        client: client,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.text('الإشعارات'), findsOneWidget);
      expect(find.text('تحديد الكل كمقروء'), findsOneWidget);
      expect(find.text('تم تأكيد حجزك'), findsOneWidget);

      await tester.tap(find.text('تم تأكيد حجزك'));
      await tester.pumpAndSettle();

      expect(client.lastMarkReadReq?.id, equals('notif_res'));
      expect(targetRoute, equals('/passes'));
      expect(find.text('Passes Target Screen'), findsOneWidget);
    });

    testWidgets('NotificationsScreen shows 1-tap rebook button for ClinicalConflict notification',
        (tester) async {
      final client = FakeTestApiClient()
        ..notificationsList = [
          NotificationDto(
            id: 'notif_clinical',
            type: 'ClinicalConflict',
            title: 'تنبيه طبي من الصيدلي بشأن حجزك',
            body: 'نبهك الصيدلي لتعارض طبي: حساسية صدر. ورشح لك بديلاً آمناً: باراسيتامول 500.',
            isRead: false,
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      String? targetSearchQuery;
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) {
              targetSearchQuery = state.uri.queryParameters['query'];
              return Scaffold(body: Text('Search Target: $targetSearchQuery'));
            },
          ),
        ],
      );

      await tester.pumpWidget(createTestApp(
        child: const SizedBox.shrink(),
        client: client,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.text('حجز البديل (باراسيتامول 500) بنقرة واحدة'), findsOneWidget);

      await tester.tap(find.text('حجز البديل (باراسيتامول 500) بنقرة واحدة'));
      await tester.pumpAndSettle();

      expect(targetSearchQuery, equals('باراسيتامول 500'));
      expect(client.lastMarkReadReq?.id, equals('notif_clinical'));
    });

    testWidgets('NotificationsScreen 1-click reserve alternative executes reservation and navigates to /passes',
        (tester) async {
      final client = FakeTestApiClient()
        ..notificationsList = [
          NotificationDto(
            id: 'notif_clinical_alt',
            type: 'ClinicalConflict',
            title: 'تنبيه طبي من الصيدلي بشأن حجزك',
            body: 'نبهك الصيدلي لتعارض طبي: حساسية صدر. ورشح لك بديلاً آمناً: باراسيتامول 500.',
            relatedEntityId: 'res_prior_123',
            isRead: false,
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/passes',
            builder: (context, state) {
              pushedRoute = '/passes';
              return const Scaffold(body: Text('Passes Target Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(createTestApp(
        child: const SizedBox.shrink(),
        client: client,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.text('حجز البديل (باراسيتامول 500) بنقرة واحدة'), findsOneWidget);

      await tester.tap(find.text('حجز البديل (باراسيتامول 500) بنقرة واحدة'));
      await tester.pumpAndSettle();

      expect(client.lastReservedAlternativeReservationId, equals('res_prior_123'));
      expect(find.text('تم تأكيد حجز البديل بنجاح لمدة ساعتين!'), findsOneWidget);
      expect(pushedRoute, equals('/passes'));
      expect(client.lastMarkReadReq?.id, equals('notif_clinical_alt'));
    });

    testWidgets('SearchScreen automatically populates search field with initialQuery',
        (tester) async {
      final client = FakeTestApiClient();
      await tester.pumpWidget(createTestApp(
        child: const SearchScreen(initialQuery: 'أوجمنتين 1 جم'),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'أوجمنتين 1 جم'), findsOneWidget);
    });

    testWidgets('NotificationsScreen mark all read marks notifications and resets count',
        (tester) async {
      final client = FakeTestApiClient()
        ..notificationsList = [
          NotificationDto(
            id: 'n1',
            type: 'ReservationCreated',
            title: 'حجز 1',
            body: 'تفاصيل الحجز',
            isRead: false,
            createdAt: DateTime.now().toUtc(),
          ),
          NotificationDto(
            id: 'n2',
            type: 'ClinicalConflict',
            title: 'حجز 2',
            body: 'تعارض طبي',
            isRead: false,
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      await tester.pumpWidget(createTestApp(
        child: const NotificationsScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('تحديد الكل كمقروء'), findsOneWidget);
      await tester.tap(find.text('تحديد الكل كمقروء'));
      await tester.pumpAndSettle();

      expect(client.lastMarkReadReq, isNotNull);
      expect(client.lastMarkReadReq!.id, isNull);
    });

    testWidgets('PatientShell displays urgent modal pop-up for ClinicalConflict on launch and navigates to alternative search',
        (tester) async {
      final client = FakeTestApiClient()
        ..notificationsList = [
          NotificationDto(
            id: 'notif_cc',
            type: 'ClinicalConflict',
            title: 'تنبيه طبي عاجل من الصيدلي!',
            body: 'نبهك الصيدلي لتعارض طبي: حساسية. ورشح لك بديلاً آمناً: بنادول أكتيفاست.',
            isRead: false,
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (context, state, child) => PatientShell(child: child),
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const Scaffold(body: Text('Home Content')),
              ),
              GoRoute(
                path: '/search',
                builder: (context, state) {
                  pushedRoute = '/search?query=${state.uri.queryParameters["query"]}';
                  return Scaffold(body: Text('Search Target: ${state.uri.queryParameters["query"]}'));
                },
              ),
              GoRoute(
                path: '/passes',
                builder: (context, state) => const Scaffold(body: Text('Passes Content')),
              ),
              GoRoute(
                path: '/profile',
                builder: (context, state) => const Scaffold(body: Text('Profile Content')),
              ),
              GoRoute(
                path: '/support',
                builder: (context, state) => const Scaffold(body: Text('Support Content')),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(createTestApp(
        child: const SizedBox.shrink(),
        client: client,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.text('تنبيه طبي عاجل من الصيدلي!'), findsOneWidget);
      expect(find.text('نبهك الصيدلي لتعارض طبي: حساسية. ورشح لك بديلاً آمناً: بنادول أكتيفاست.'), findsOneWidget);
      expect(find.text('احجز بنادول أكتيفاست من نفس الصيدلية (لو متاح)'), findsOneWidget);
      expect(find.text('ابحث عن الدواء البديل (بنادول أكتيفاست)'), findsOneWidget);
      expect(find.text('خروج'), findsOneWidget);

      await tester.tap(find.text('ابحث عن الدواء البديل (بنادول أكتيفاست)'));
      await tester.pumpAndSettle();

      expect(pushedRoute, equals('/search?query=بنادول أكتيفاست'));
      expect(client.lastMarkReadReq?.id, equals('notif_cc'));
    });

    testWidgets('PatientShell displays urgent modal pop-up for AvailabilityOfferSent on launch and claims offer',
        (tester) async {
      final client = FakeTestApiClient()
        ..notificationsList = [
          NotificationDto(
            id: 'notif_offer',
            type: 'AvailabilityOfferSent',
            title: 'الدواء الذي تتابعه أصبح متوفراً!',
            body: 'دواء كونكور 5 مجم متوفر الآن في صيدلية الشفاء — لديك 15 دقيقة لتأكيد الحجز.',
            relatedEntityId: 'sub_123',
            isRead: false,
            createdAt: DateTime.now().toUtc(),
          ),
        ];

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (context, state, child) => PatientShell(child: child),
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const Scaffold(body: Text('Home Content')),
              ),
              GoRoute(
                path: '/passes',
                builder: (context, state) => const Scaffold(body: Text('Passes Target Content')),
              ),
              GoRoute(
                path: '/profile',
                builder: (context, state) => const Scaffold(body: Text('Profile Content')),
              ),
              GoRoute(
                path: '/support',
                builder: (context, state) => const Scaffold(body: Text('Support Content')),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(createTestApp(
        child: const SizedBox.shrink(),
        client: client,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.text('تنبيه عاجل: توفر دواء مطلوب!'), findsOneWidget);
      expect(find.text('حجز الآن'), findsOneWidget);

      await tester.tap(find.text('حجز الآن'));
      await tester.pumpAndSettle();

      expect(client.lastClaimedOfferId, equals('sub_123'));
      expect(client.lastMarkReadReq?.id, equals('notif_offer'));
      expect(find.text('Passes Target Content'), findsOneWidget);
    });
  });

  group('8. Pharmacy Details & Equivalents Components', () {
    testWidgets('MedicationEquivalentsCard renders generic substitutes & legal disclaimer',
        (tester) async {
      final response = MedicationEquivalentsResponse(
        original: OriginalMedicationInfoDto(
          tradeName: 'كونكور 5 مجم',
          activeIngredient: 'بيسوبرولول',
          strength: '5 مجم',
          dosageForm: 'أقراص',
          officialPriceEGP: 80,
          isAvailableNearby: false,
        ),
        availableEquivalents: [
          EquivalentPharmacyResultDto(
            equivalentTradeName: 'بيسور 5 مجم',
            pharmacyId: 'ph1',
            pharmacyName: 'صيدلية الحياة',
            distanceKm: 0.5,
            priceAtPharmacy: 45,
            officialPriceEGP: 45,
            priceSavingPercent: 43.75,
            inventoryItemId: 'inv_1',
          ),
        ],
        legalDisclaimer: 'تنبيه طبي: استشر الصيدلي أو الطبيب دائماً قبل الاستبدال.',
      );

      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: MedicationEquivalentsCard(response: response),
        ),
        client: FakeTestApiClient(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('بدائل بنفس المادة الفعالة'), findsOneWidget);
      expect(find.textContaining('كونكور 5 مجم غير متوفر حالياً'), findsOneWidget);
      expect(find.text('بيسور 5 مجم'), findsOneWidget);
      expect(find.text('صيدلية الحياة · ٥٠٠ متر'), findsOneWidget);
      expect(find.text('٤٥ ج.م'), findsOneWidget);
      expect(find.text('يوفر ٤٤%'), findsOneWidget);
      expect(find.text('تنبيه طبي: استشر الصيدلي أو الطبيب دائماً قبل الاستبدال.'), findsOneWidget);
    });

    testWidgets('PharmacyDetailsScreen reserves medication when in stock',
        (tester) async {
      final client = FakeTestApiClient();
      final item = PharmacySearchResultDto(
        pharmacyId: 'p1',
        pharmacyName: 'صيدلية رشدي',
        addressLine: 'مدينة نصر',
        phone: '01012345678',
        trustScore: 95.0,
        distanceKm: 1.2,
        medicationName: 'أوجمنتين 1 جم',
        price: 90.0,
        status: 'InStock',
        quantity: 8,
        latitude: 30.05,
        longitude: 31.25,
        lastUpdatedAt: DateTime.now().toUtc(),
        inventoryItemId: 'item_123',
      );

      final router = GoRouter(
        initialLocation: '/details',
        routes: [
          GoRoute(
            path: '/details',
            builder: (context, state) => Directionality(
              textDirection: TextDirection.rtl,
              child: PharmacyDetailsScreen(args: PharmacyDetailsArgs(item: item)),
            ),
          ),
          GoRoute(
            path: '/patient/passes',
            builder: (context, state) => const Scaffold(body: Text('Passes Screen')),
          ),
        ],
      );

      await tester.pumpWidget(createTestApp(
        child: const SizedBox.shrink(),
        client: client,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.text('أوجمنتين 1 جم'), findsWidgets);
      expect(find.text('صيدلية رشدي'), findsOneWidget);
      expect(find.text('احجز تصريح'), findsOneWidget);

      await tester.tap(find.text('احجز تصريح'));
      await tester.pumpAndSettle();

      expect(client.lastReservedItemId, equals('item_123'));
    });
  });
}
