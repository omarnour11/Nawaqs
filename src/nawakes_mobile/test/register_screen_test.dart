import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/auth/data/auth_models.dart';
import 'package:nawakes_mobile/features/auth/presentation/register_screen.dart';

class MockRegisterApiClient implements ApiClient {
  RegisterRequest? lastRegisterRequest;
  LoginRequest? lastLoginRequest;

  @override
  Future<AuthResponse> register(RegisterRequest body) async {
    lastRegisterRequest = body;
    return AuthResponse(
      accessToken: 'jwt_mock_token',
      refreshToken: 'refresh_mock_token',
      userId: 'user_123',
      role: body.role ?? 'Patient',
    );
  }

  @override
  Future<AuthResponse> login(LoginRequest body) async {
    lastLoginRequest = body;
    return AuthResponse(
      accessToken: 'jwt_mock_token',
      refreshToken: 'refresh_mock_token',
      userId: 'user_123',
      role: 'Patient',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createRegisterApp({
  required MockRegisterApiClient client,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
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
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: RegisterScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RegisterScreen patient clinical & demographic tests', () {
    testWidgets(
        'RegisterScreen registers patient with gender, age, condition & allergy chips, and custom text',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterSecureStorage.setMockInitialValues({});
      final client = MockRegisterApiClient();

      await tester.pumpWidget(createRegisterApp(client: client));
      await tester.pumpAndSettle();

      // Step 0: Fill account credentials
      await tester.enterText(
          find.byKey(const Key('register_name_field')), 'سارة أحمد');
      await tester.enterText(
          find.byKey(const Key('register_email_field')), 'sara@example.com');
      await tester.enterText(
          find.byKey(const Key('register_password_field')), 'Password123');
      await tester.enterText(
          find.byKey(const Key('register_confirm_password_field')), 'Password123');
      await tester.pumpAndSettle();

      // Next step
      await tester.tap(find.byKey(const Key('register_next_button')));
      await tester.pumpAndSettle();

      // Step 1: Verify presence of demographic and clinical fields
      expect(find.byKey(const Key('gender_male_chip')), findsOneWidget);
      expect(find.byKey(const Key('gender_female_chip')), findsOneWidget);
      expect(find.byKey(const Key('register_age_field')), findsOneWidget);
      expect(find.byKey(const Key('condition_chip_السكري')), findsOneWidget);
      expect(find.byKey(const Key('condition_chip_الربو')), findsOneWidget);
      expect(find.byKey(const Key('allergy_chip_بنسلين')), findsOneWidget);
      expect(find.byKey(const Key('allergy_chip_أسبرين')), findsOneWidget);

      // Select female gender
      await tester.tap(find.byKey(const Key('gender_female_chip')));
      await tester.pumpAndSettle();

      // Enter age
      await tester.enterText(
          find.byKey(const Key('register_age_field')), '28');
      await tester.pumpAndSettle();

      // Tap condition chips
      await tester.tap(find.byKey(const Key('condition_chip_السكري')));
      await tester.tap(find.byKey(const Key('condition_chip_الربو')));
      await tester.pumpAndSettle();

      // Enter custom condition
      await tester.enterText(
          find.byKey(const Key('register_conditions_field')), 'قرحة المعدة');
      await tester.pumpAndSettle();

      // Tap allergy chips
      await tester.tap(find.byKey(const Key('allergy_chip_بنسلين')));
      await tester.tap(find.byKey(const Key('allergy_chip_أسبرين')));
      await tester.pumpAndSettle();

      // Enter custom allergy
      await tester.enterText(
          find.byKey(const Key('register_allergies_field')), 'فراولة');
      await tester.pumpAndSettle();

      // Submit patient registration
      await tester.ensureVisible(find.byKey(const Key('submit_patient_button')));
      await tester.tap(find.byKey(const Key('submit_patient_button')));
      await tester.pumpAndSettle();

      // Verify request payload
      expect(client.lastRegisterRequest, isNotNull);
      final req = client.lastRegisterRequest!;
      expect(req.fullName, 'سارة أحمد');
      expect(req.email, 'sara@example.com');
      expect(req.role, 'Patient');
      expect(req.gender, 'أنثى');
      expect(req.age, 28);
      expect(req.chronicConditions, contains('السكري'));
      expect(req.chronicConditions, contains('الربو'));
      expect(req.chronicConditions, contains('قرحة المعدة'));
      expect(req.knownAllergies, contains('بنسلين'));
      expect(req.knownAllergies, contains('أسبرين'));
      expect(req.knownAllergies, contains('فراولة'));
      expect(req.chronicIllnesses, contains('السكري'));
      expect(req.chronicIllnesses, contains('الربو'));
      expect(req.chronicIllnesses, contains('قرحة المعدة'));
    });

    testWidgets(
        'RegisterScreen skip step button registers patient with minimal health attributes',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterSecureStorage.setMockInitialValues({});
      final client = MockRegisterApiClient();

      await tester.pumpWidget(createRegisterApp(client: client));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('register_name_field')), 'علي حسن');
      await tester.enterText(
          find.byKey(const Key('register_email_field')), 'ali@example.com');
      await tester.enterText(
          find.byKey(const Key('register_password_field')), 'Password123');
      await tester.enterText(
          find.byKey(const Key('register_confirm_password_field')), 'Password123');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('register_next_button')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('skip_patient_step_button')));
      await tester.tap(find.byKey(const Key('skip_patient_step_button')));
      await tester.pumpAndSettle();

      expect(client.lastRegisterRequest, isNotNull);
      final req = client.lastRegisterRequest!;
      expect(req.fullName, 'علي حسن');
      expect(req.email, 'ali@example.com');
      expect(req.role, 'Patient');
      expect(req.gender, 'ذكر');
      expect(req.age, isNull);
      expect(req.chronicConditions, isNull);
      expect(req.knownAllergies, isNull);
      expect(req.chronicIllnesses, isNull);
    });

    testWidgets('Tapping condition and allergy chips toggles selection',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterSecureStorage.setMockInitialValues({});
      final client = MockRegisterApiClient();

      await tester.pumpWidget(createRegisterApp(client: client));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('register_name_field')), 'محمود سامي');
      await tester.enterText(
          find.byKey(const Key('register_email_field')), 'mahmoud@example.com');
      await tester.enterText(
          find.byKey(const Key('register_password_field')), 'Password123');
      await tester.enterText(
          find.byKey(const Key('register_confirm_password_field')), 'Password123');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('register_next_button')));
      await tester.pumpAndSettle();

      final condFinder = find.byKey(const Key('condition_chip_السكري'));
      FilterChip condChip = tester.widget(condFinder);
      expect(condChip.selected, isFalse);

      await tester.tap(condFinder);
      await tester.pumpAndSettle();
      condChip = tester.widget(condFinder);
      expect(condChip.selected, isTrue);

      await tester.tap(condFinder);
      await tester.pumpAndSettle();
      condChip = tester.widget(condFinder);
      expect(condChip.selected, isFalse);

      final allergyFinder = find.byKey(const Key('allergy_chip_بنسلين'));
      FilterChip allergyChip = tester.widget(allergyFinder);
      expect(allergyChip.selected, isFalse);

      await tester.tap(allergyFinder);
      await tester.pumpAndSettle();
      allergyChip = tester.widget(allergyFinder);
      expect(allergyChip.selected, isTrue);

      await tester.tap(allergyFinder);
      await tester.pumpAndSettle();
      allergyChip = tester.widget(allergyFinder);
      expect(allergyChip.selected, isFalse);
    });
  });
}
