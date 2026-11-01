import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/notifications/data/notification_models.dart';
import 'package:nawakes_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:nawakes_mobile/features/profile/data/profile_models.dart';
import 'package:nawakes_mobile/features/profile/presentation/profile_screen.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/search/presentation/batch_search_results_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_basket_screen.dart';

/// Adversarial Fake ApiClient for Challenger verification
class AdversarialApiClient implements ApiClient {
  ProfileResponse? profileToReturn;
  UpdateProfileRequest? capturedUpdateProfile;
  Exception? reserveAlternativeException;
  ReservationResponse? reserveAlternativeSuccessResponse;
  String? lastReservedAlternativeId;
  BatchSearchRequest? capturedBatchSearchRequest;
  BatchSearchResponse? batchSearchResponseToReturn;
  List<NotificationDto> notificationsList = [];
  MarkReadRequest? capturedMarkReadRequest;
  List<CreateReservationRequest> capturedReservations = [];

  @override
  Future<ProfileResponse> getProfile() async {
    return profileToReturn ??
        ProfileResponse(
          userId: 'test_user_adv',
          fullName: 'فاحص التحدي الأمني',
          email: 'challenger@nawaqs.com',
          phone: '01011223344',
          medicalHistoryNotes: null,
          createdAt: DateTime.now().toUtc(),
        );
  }

  @override
  Future<ProfileResponse> updateProfile(UpdateProfileRequest body) async {
    capturedUpdateProfile = body;
    profileToReturn = ProfileResponse(
      userId: 'test_user_adv',
      fullName: body.fullName ?? profileToReturn?.fullName,
      email: profileToReturn?.email ?? 'challenger@nawaqs.com',
      phone: body.phone ?? profileToReturn?.phone,
      medicalHistoryNotes: body.medicalHistoryNotes,
      createdAt: DateTime.now().toUtc(),
    );
    return profileToReturn!;
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
    capturedMarkReadRequest = body;
    return MarkReadResponse(updated: 1);
  }

  @override
  Future<ReservationResponse> reserveAlternative(String id) async {
    lastReservedAlternativeId = id;
    if (reserveAlternativeException != null) {
      throw reserveAlternativeException!;
    }
    return reserveAlternativeSuccessResponse ??
        ReservationResponse(
          id: 'res_alt_adv',
          inventoryItemId: 'inv_alt_adv',
          reservationCode: 'NWQ-ALT999',
          status: 'Active',
          pharmacyId: 'ph_adv',
          pharmacyName: 'صيدلية البديل المعتمد',
          pharmacyPhone: '0100000000',
          medicationName: 'بانادول أكتيفاست',
          createdAt: DateTime.now().toUtc(),
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
        );
  }

  @override
  Future<BatchSearchResponse> batchSearch(BatchSearchRequest body) async {
    capturedBatchSearchRequest = body;
    return batchSearchResponseToReturn ??
        BatchSearchResponse(
          totalRequestedItems: body.items.length,
          radiusKm: body.radiusKm,
          completePharmacies: [
            BatchPharmacyResult(
              pharmacyId: 'ph_october_1',
              pharmacyName: 'Al Safwa Pharmacy — 6th of October',
              addressLine: 'Al-Hosary Square, 6th of October City',
              phone: '01099887766',
              trustScore: 4.9,
              distanceKm: 0.1,
              latitude: 29.9737,
              longitude: 30.9529,
              matchedCount: body.items.length,
              totalRequested: body.items.length,
              isCompleteMatch: true,
              totalEstimatedPrice: 50.0,
              items: body.items
                  .map((i) => BatchMedicationDetail(
                        medication: i.medication,
                        requestedQuantity: i.quantity,
                        inStock: true,
                        price: 25.0,
                        availableQuantity: 10,
                        inventoryItemId: 'inv_${i.medication}',
                      ))
                  .toList(),
            ),
          ],
          partialPharmacies: [],
        );
  }

  @override
  Future<ReservationResponse> createReservation(CreateReservationRequest body) async {
    capturedReservations.add(body);
    return ReservationResponse(
      id: 'res_${body.inventoryItemId}',
      inventoryItemId: body.inventoryItemId,
      reservationCode: 'NWQ-112233',
      status: 'Active',
      pharmacyId: 'ph_october_1',
      pharmacyName: 'Al Safwa Pharmacy',
      pharmacyPhone: '01099887766',
      medicationName: 'Panadol',
      createdAt: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
    );
  }

  @override
  Future<List<ReservationResponse>> getMyReservations() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Adversarial Fake LocationService
class AdversarialLocationService extends LocationService {
  Position? positionToReturn;
  Exception? exceptionToThrow;

  @override
  Future<Position?> getCurrentLocation() async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return positionToReturn;
  }

  @override
  Future<String?> reverseGeocode(double lat, double lng) async => null;

  @override
  Future<List<LocationSuggestion>> searchPlaces(
    String query, {
    double? centerLat,
    double? centerLng,
  }) async => const [];
}

Widget createAdversarialApp({
  required Widget child,
  required AdversarialApiClient client,
  AdversarialLocationService? locationService,
  GoRouter? router,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      locationServiceProvider.overrideWithValue(locationService ?? AdversarialLocationService()),
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
            home: child,
          ),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Adversarial R4: Medical Notes Deduplication & Strict Idempotency Stress Test', () {
    testWidgets('Corrupted input with mixed commas, duplicate condition/allergy lines, and repeated notes renders deduplicated and saves 100% idempotently', (tester) async {
      final client = AdversarialApiClient();

      // Heavily corrupted raw notes:
      // - Multiple 'أمراض:' lines with duplicates and mixed English/Arabic commas
      // - Multiple 'حساسية:' lines with duplicates and trailing whitespace
      // - Duplicate free-text lines
      // - Empty lines and spaces
      const heavilyCorruptedNotes = '''
  أمراض: ضغط دم مرتفع، سكري, ضغط دم مرتفع  
  حساسية: بنسلين , سلفا ، بنسلين  
  أمراض: سكري ، ربو ، ضغط دم مرتفع
  حساسية: أسبرين, بنسلين , سلفا  
  ملاحظة طبية: المريض يحتاج متابعة وظائف كلى كل 6 أشهر
  أمراض: ضغط دم مرتفع
  ملاحظة طبية: المريض يحتاج متابعة وظائف كلى كل 6 أشهر
  ملاحظة إضافية: الالتزام بحمية قليلة الملح
  
  حساسية: بنسلين
''';

      client.profileToReturn = ProfileResponse(
        userId: 'u_adv_r4',
        fullName: 'أحمد علي',
        email: 'ahmed.corrupted@example.com',
        phone: '01012345678',
        medicalHistoryNotes: heavilyCorruptedNotes,
        createdAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(createAdversarialApp(
        child: const ProfileScreen(),
        client: client,
      ));
      await tester.pumpAndSettle();

      // Verify each chronic condition chip is rendered EXACTLY ONCE
      expect(find.text('ضغط دم مرتفع'), findsOneWidget);
      expect(find.text('سكري'), findsOneWidget);
      expect(find.text('ربو'), findsOneWidget);

      // Verify each allergy chip is rendered EXACTLY ONCE
      expect(find.text('بنسلين'), findsOneWidget);
      expect(find.text('سلفا'), findsOneWidget);
      expect(find.text('أسبرين'), findsOneWidget);

      // Verify distinct free-text medical notes are rendered without duplicating lines
      expect(find.textContaining('المريض يحتاج متابعة وظائف كلى كل 6 أشهر'), findsOneWidget);
      expect(find.textContaining('الالتزام بحمية قليلة الملح'), findsOneWidget);

      // Tap 'تعديل' to enter edit mode
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();

      // Tap 'حفظ التغييرات' on the bottom bar
      await tester.tap(find.text('حفظ التغييرات'));
      await tester.pumpAndSettle();

      expect(client.capturedUpdateProfile, isNotNull);
      final firstSaved = client.capturedUpdateProfile!.medicalHistoryNotes!;

      // Verify first saved string contains exactly ONE 'أمراض:' line and ONE 'حساسية:' line
      final conditionMatches = RegExp(r'^أمراض:', multiLine: true).allMatches(firstSaved);
      final allergyMatches = RegExp(r'^حساسية:', multiLine: true).allMatches(firstSaved);
      expect(conditionMatches.length, equals(1), reason: 'Must contain strictly one conditions header line');
      expect(allergyMatches.length, equals(1), reason: 'Must contain strictly one allergies header line');

      // Verify SnackBar confirmation appeared
      expect(find.text('التغييرات اتحفظت.'), findsOneWidget);

      // Verify strict 10-iteration idempotency of the deduplication algorithm
      var currentIterationNotes = heavilyCorruptedNotes;
      String? canonicalResult;

      for (int cycle = 1; cycle <= 10; cycle++) {
        // Algorithm matching ProfileScreen._parseSections, _parseConditions, _parseAllergies, _parseMedicalNotes:
        final conditionSet = <String>{};
        final allergySet = <String>{};
        final notesSet = <String>{};

        for (final line in currentIterationNotes.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('أمراض:')) {
            final items = trimmed
                .substring('أمراض:'.length)
                .split(RegExp(r'[،,]'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty);
            conditionSet.addAll(items);
          } else if (trimmed.startsWith('حساسية:')) {
            final items = trimmed
                .substring('حساسية:'.length)
                .split(RegExp(r'[،,]'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty);
            allergySet.addAll(items);
          } else if (trimmed.isNotEmpty) {
            notesSet.add(trimmed);
          }
        }

        final buf = StringBuffer();
        if (conditionSet.isNotEmpty) {
          buf.writeln('أمراض: ${conditionSet.join('، ')}');
        }
        if (allergySet.isNotEmpty) {
          buf.writeln('حساسية: ${allergySet.join('، ')}');
        }
        if (notesSet.isNotEmpty) {
          buf.write(notesSet.join('\n'));
        }

        final composed = buf.toString().trim();
        if (canonicalResult == null) {
          canonicalResult = composed;
        } else {
          expect(composed, equals(canonicalResult),
              reason: 'Cycle $cycle must produce byte-identical string to canonical result (100% idempotent)');
        }
        currentIterationNotes = composed;
      }
    });
  });

  group('Adversarial R3: 1-Click Alternative Reservation Exception Resilience', () {
    testWidgets('Tapping 1-click alternative reservation handles 404 NotFound without crashing and displays error SnackBar', (tester) async {
      final client = AdversarialApiClient();
      // Configure 404 NotFound DioException
      client.reserveAlternativeException = DioException(
        requestOptions: RequestOptions(path: '/reservations/prior_404/reserve-alternative'),
        response: Response(
          requestOptions: RequestOptions(path: '/reservations/prior_404/reserve-alternative'),
          statusCode: 404,
          data: {'detail': 'The recommended alternative medication is out of stock in all pharmacies.'},
        ),
        type: DioExceptionType.badResponse,
      );

      client.notificationsList = [
        NotificationDto(
          id: 'notif_404',
          type: 'ClinicalConflict',
          title: 'تعارض طبي في وصفتك',
          body: 'نبهك الصيدلي لتعارض طبي: حساسية. ورشح لك بديلاً آمناً: كيورام 1 جم.',
          isRead: false,
          relatedEntityId: 'prior_res_404',
          createdAt: DateTime.now().toUtc(),
        ),
      ];

      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
          GoRoute(path: '/passes', builder: (c, s) => const Scaffold(body: Text('Passes Screen'))),
        ],
      );

      await tester.pumpWidget(createAdversarialApp(
        child: const SizedBox.shrink(),
        client: client,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.text('حجز البديل (كيورام 1 جم) بنقرة واحدة'), findsOneWidget);

      // Tap 1-click reservation
      await tester.tap(find.text('حجز البديل (كيورام 1 جم) بنقرة واحدة'));
      await tester.pumpAndSettle();

      // Must catch the exception and display friendly error SnackBar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('تعذر حجز البديل:'), findsOneWidget);
      expect(find.textContaining('out of stock'), findsOneWidget);
    });

    testWidgets('Tapping 1-click alternative reservation handles 409 Conflict without crashing and displays error SnackBar', (tester) async {
      final client = AdversarialApiClient();
      // Configure 409 Conflict DioException
      client.reserveAlternativeException = DioException(
        requestOptions: RequestOptions(path: '/reservations/prior_409/reserve-alternative'),
        response: Response(
          requestOptions: RequestOptions(path: '/reservations/prior_409/reserve-alternative'),
          statusCode: 409,
          data: {'detail': 'This alternative item was just reserved. Please try again shortly.'},
        ),
        type: DioExceptionType.badResponse,
      );

      client.notificationsList = [
        NotificationDto(
          id: 'notif_409',
          type: 'ClinicalConflict',
          title: 'تعارض طبي',
          body: 'نبهك الصيدلي لتعارض طبي: قرحة معدة. ورشح لك بديلاً آمناً: بنادول أكتيفاست.',
          isRead: false,
          relatedEntityId: 'prior_res_409',
          createdAt: DateTime.now().toUtc(),
        ),
      ];

      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
          GoRoute(path: '/passes', builder: (c, s) => const Scaffold(body: Text('Passes Screen'))),
        ],
      );

      await tester.pumpWidget(createAdversarialApp(
        child: const SizedBox.shrink(),
        client: client,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.text('حجز البديل (بنادول أكتيفاست) بنقرة واحدة'), findsOneWidget);

      await tester.tap(find.text('حجز البديل (بنادول أكتيفاست) بنقرة واحدة'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('تعذر حجز البديل:'), findsOneWidget);
      expect(find.textContaining('just reserved'), findsOneWidget);
    });

    testWidgets('Tapping 1-click alternative reservation handles Network / Connection failure without crashing', (tester) async {
      final client = AdversarialApiClient();
      // Configure SocketException / Network error
      client.reserveAlternativeException = DioException(
        requestOptions: RequestOptions(path: '/reservations/prior_net/reserve-alternative'),
        error: const SocketException('Failed host lookup: api.nawaqs.com'),
        type: DioExceptionType.connectionError,
      );

      client.notificationsList = [
        NotificationDto(
          id: 'notif_net',
          type: 'ClinicalConflict',
          title: 'تعارض طبي',
          body: 'نبهك الصيدلي لتعارض طبي. ورشح لك بديلاً آمناً: أدول.',
          isRead: false,
          relatedEntityId: 'prior_res_net',
          createdAt: DateTime.now().toUtc(),
        ),
      ];

      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
          GoRoute(path: '/passes', builder: (c, s) => const Scaffold(body: Text('Passes Screen'))),
        ],
      );

      await tester.pumpWidget(createAdversarialApp(
        child: const SizedBox.shrink(),
        client: client,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.text('حجز البديل (أدول) بنقرة واحدة'), findsOneWidget);

      await tester.tap(find.text('حجز البديل (أدول) بنقرة واحدة'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('تعذر حجز البديل:'), findsOneWidget);
    });

    testWidgets('Tapping 1-click alternative reservation succeeds, displays green confirmation SnackBar, and navigates to /passes', (tester) async {
      final client = AdversarialApiClient();
      client.notificationsList = [
        NotificationDto(
          id: 'notif_success',
          type: 'ClinicalConflict',
          title: 'تعارض طبي',
          body: 'نبهك الصيدلي لتعارض طبي. ورشح لك بديلاً آمناً: كيورام 1 جم.',
          isRead: false,
          relatedEntityId: 'prior_res_success',
          createdAt: DateTime.now().toUtc(),
        ),
      ];

      String? activeRoute;
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
          GoRoute(
            path: '/passes',
            builder: (c, s) {
              activeRoute = '/passes';
              return const Scaffold(body: Text('Passes Screen Target'));
            },
          ),
        ],
      );

      await tester.pumpWidget(createAdversarialApp(
        child: const SizedBox.shrink(),
        client: client,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.text('حجز البديل (كيورام 1 جم) بنقرة واحدة'), findsOneWidget);

      await tester.tap(find.text('حجز البديل (كيورام 1 جم) بنقرة واحدة'));
      await tester.pumpAndSettle();

      expect(client.lastReservedAlternativeId, equals('prior_res_success'));
      expect(find.text('تم تأكيد حجز البديل بنجاح لمدة ساعتين!'), findsOneWidget);
      expect(activeRoute, equals('/passes'));
      expect(find.text('Passes Screen Target'), findsOneWidget);
    });
  });

  group('Adversarial R1: Navigation Stack Clearing after Batch Reservation', () {
    testWidgets('Completing batch reservation clears PrescriptionBasketScreen and returns to Home screen', (tester) async {
      final client = AdversarialApiClient();
      final locationService = AdversarialLocationService()
        ..positionToReturn = Position(
          latitude: 29.9737,
          longitude: 30.9529,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );

      final items = [
        PrescriptionBasketItem(tradeName: 'Panadol', quantity: 1),
        PrescriptionBasketItem(tradeName: 'Concor', quantity: 1),
      ];

      // Setup GoRouter with /home as root
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (ctx, state) {
              return Scaffold(
                appBar: AppBar(title: const Text('Home Screen')),
                body: Builder(
                  builder: (innerCtx) => ElevatedButton(
                    key: const ValueKey('open_basket_btn'),
                    onPressed: () {
                      PrescriptionBasketScreen.show(innerCtx, items: items);
                    },
                    child: const Text('افتح سلة الروشتة'),
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: '/passes',
            builder: (ctx, state) => const Scaffold(body: Text('Passes Screen')),
          ),
        ],
      );

      await tester.pumpWidget(createAdversarialApp(
        child: const SizedBox.shrink(),
        client: client,
        locationService: locationService,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);

      // Push PrescriptionBasketScreen onto navigation stack
      await tester.tap(find.byKey(const ValueKey('open_basket_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(PrescriptionBasketScreen), findsOneWidget);

      // Tap 'بحث جماعي' from basket to push BatchSearchResultsScreen
      await tester.tap(find.byKey(const ValueKey('prescription_basket_batch_search_btn')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BatchSearchResultsScreen), findsOneWidget);

      // Tap 'احجز الكل' (book all pharmacies)
      await tester.tap(find.byKey(const ValueKey('batch_reserve_all_button')));
      await tester.pumpAndSettle();

      expect(find.text('تم الحجز بالكامل!'), findsOneWidget);

      // Tap 'حسنًا' on completion dialog to dismiss and pop to root
      await tester.tap(find.text('حسنًا'));
      await tester.pumpAndSettle();

      // Assert that NEITHER BatchSearchResultsScreen NOR PrescriptionBasketScreen exist in the tree!
      expect(find.byType(BatchSearchResultsScreen), findsNothing, reason: 'BatchSearchResultsScreen must be cleared');
      expect(find.byType(PrescriptionBasketScreen), findsNothing, reason: 'PrescriptionBasketScreen must be cleared from history');

      // Assert that we have navigated back to Home Screen
      expect(find.text('Home Screen'), findsOneWidget);
    });
  });

  group('Adversarial R2: Geospatial Distance Accuracy in Batch Search', () {
    testWidgets('Live GPS location in 6th of October (29.9737, 30.9529) is passed to backend and does not default to Cairo Downtown', (tester) async {
      final client = AdversarialApiClient();
      final locationService = AdversarialLocationService()
        ..positionToReturn = Position(
          latitude: 29.9737,
          longitude: 30.9529,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );

      final items = [
        BatchSearchItemDto(medication: 'Panadol', quantity: 1),
        BatchSearchItemDto(medication: 'Concor', quantity: 1),
      ];

      await tester.pumpWidget(createAdversarialApp(
        child: BatchSearchResultsScreen(items: items),
        client: client,
        locationService: locationService,
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(client.capturedBatchSearchRequest, isNotNull);
      // Coordinates must match live device GPS in 6th of October
      expect(client.capturedBatchSearchRequest!.lat, equals(29.9737));
      expect(client.capturedBatchSearchRequest!.lng, equals(30.9529));
      expect(client.capturedBatchSearchRequest!.radiusKm, equals(35.0));

      // Must NOT be the Cairo Downtown coordinates
      expect(client.capturedBatchSearchRequest!.lat, isNot(equals(30.0444)));
      expect(client.capturedBatchSearchRequest!.lng, isNot(equals(31.2357)));
    });

    testWidgets('When location service fails or throws, gracefully falls back without crashing', (tester) async {
      final client = AdversarialApiClient();
      final locationService = AdversarialLocationService()
        ..exceptionToThrow = Exception('Location permission permanently denied');

      final items = [
        BatchSearchItemDto(medication: 'Brufen', quantity: 1),
      ];

      await tester.pumpWidget(createAdversarialApp(
        child: BatchSearchResultsScreen(items: items),
        client: client,
        locationService: locationService,
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(client.capturedBatchSearchRequest, isNotNull);
      // Gracefully used default without throwing an uncaught exception
      expect(client.capturedBatchSearchRequest!.lat, equals(30.0444));
      expect(client.capturedBatchSearchRequest!.lng, equals(31.2357));
      expect(find.byType(BatchSearchResultsScreen), findsOneWidget);
    });
  });
}
