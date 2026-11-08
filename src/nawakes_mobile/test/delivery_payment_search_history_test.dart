import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nawakes_mobile/core/services/search_history_service.dart';
import 'package:nawakes_mobile/core/services/payment_methods_service.dart';
import 'package:nawakes_mobile/core/services/paymob_payment_service.dart';
import 'package:nawakes_mobile/features/profile/presentation/payment_methods_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/widgets/delivery_details_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Isolated Search History Service Tests (Privacy & Multi-user)', () {
    test('isolates search history per authenticated user account', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(searchHistoryProvider.notifier);

      // User A searches
      await notifier.scopeToUser('user_alpha_123');
      expect(notifier.activeStorageKey, 'nawaqs_recent_search_history_user_user_alpha_123');
      await notifier.addQuery('بانادول أزرق');
      await notifier.addQuery('كونكور 5');
      expect(container.read(searchHistoryProvider), ['كونكور 5', 'بانادول أزرق']);

      // Switch to User B -> should NOT see User A's queries!
      await notifier.scopeToUser('user_beta_456');
      expect(notifier.activeStorageKey, 'nawaqs_recent_search_history_user_user_beta_456');
      expect(container.read(searchHistoryProvider), isEmpty);

      // User B adds their own query
      await notifier.addQuery('أسبوسيد أطفال');
      expect(container.read(searchHistoryProvider), ['أسبوسيد أطفال']);

      // Switch back to User A -> their queries remain isolated and intact
      await notifier.scopeToUser('user_alpha_123');
      expect(container.read(searchHistoryProvider), ['كونكور 5', 'بانادول أزرق']);
    });

    test('deduplicates and clears history cleanly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(searchHistoryProvider.notifier);
      await notifier.scopeToUser('test_user');
      await notifier.addQuery('أسبوسيد');
      await notifier.addQuery('كتافلام');
      expect(container.read(searchHistoryProvider).length, 2);

      await notifier.removeQuery('أسبوسيد');
      expect(container.read(searchHistoryProvider), ['كتافلام']);

      await notifier.clearAll();
      expect(container.read(searchHistoryProvider), isEmpty);
    });
  });

  group('2. Authentic Card Validation & Luhn Algorithm Tests', () {
    test('strictly rejects fake / dummy cards and validates authentic Luhn numbers', () {
      // 1. Obvious dummy / fake cards MUST fail:
      expect(CardValidator.isValidLuhn('0000000000000000'), isFalse);
      expect(CardValidator.isValidLuhn('1111111111111111'), isFalse);
      expect(CardValidator.isValidLuhn('1234567812345678'), isFalse);
      expect(CardValidator.isValidLuhn('123'), isFalse); // too short

      // 2. Real Luhn algorithm check:
      // Valid Visa test card (passes mod 10): 4532015112830366
      expect(CardValidator.isValidLuhn('4532 0151 1283 0366'), isTrue);

      // Detect card brands accurately
      expect(CardValidator.detectBrand('4532015112830366'), 'Visa');
      expect(CardValidator.detectBrand('5105105105105100'), 'Mastercard');
      expect(CardValidator.detectBrand('5078031234567890'), 'Meeza');

      // Expiry validation: past year MUST fail, valid future year MUST pass
      expect(CardValidator.isValidExpiry('12/20'), isFalse); // expired
      expect(CardValidator.isValidExpiry('15/28'), isFalse); // invalid month
      expect(CardValidator.isValidExpiry('08/29'), isTrue);

      // CVV validation
      expect(CardValidator.isValidCVV('000'), isFalse);
      expect(CardValidator.isValidCVV('12'), isFalse);
      expect(CardValidator.isValidCVV('382'), isTrue);

      // Cardholder validation: must be at least 2 words
      expect(CardValidator.isValidCardholder('Omar'), isFalse);
      expect(CardValidator.isValidCardholder('عمر نور'), isTrue);
    });
  });

  group('3. Paymob Egyptian E-Wallets Gateway Tests', () {
    test('validates Egyptian mobile wallets (Vodafone, Orange, Etisalat, WE)', () {
      // Valid Egyptian mobile wallets
      expect(EgyptianWalletValidator.isValidMobileNumber('01098765432'), isTrue);
      expect(EgyptianWalletValidator.isValidMobileNumber('01223456789'), isTrue);
      expect(EgyptianWalletValidator.isValidMobileNumber('01123456789'), isTrue);
      expect(EgyptianWalletValidator.isValidMobileNumber('01552345678'), isTrue);

      // Operator detection
      expect(EgyptianWalletValidator.detectOperator('01098765432'), 'فودافون كاش');
      expect(EgyptianWalletValidator.detectOperator('01223456789'), 'أورنج كاش');
      expect(EgyptianWalletValidator.detectOperator('01123456789'), 'اتصالات كاش');
      expect(EgyptianWalletValidator.detectOperator('01552345678'), 'وي باي (WE Pay)');

      // Invalid mobile numbers
      expect(EgyptianWalletValidator.isValidMobileNumber('01398765432'), isFalse); // Invalid prefix 013
      expect(EgyptianWalletValidator.isValidMobileNumber('01012345'), isFalse); // Too short
      expect(EgyptianWalletValidator.isValidMobileNumber('0101234567899'), isFalse); // Too long
    });

    test('generates Paymob payment intent and USSD code for Egyptian wallets', () async {
      final paymob = PaymobPaymentService();

      final intent = await paymob.payWithMobileWallet(
        walletNumber: '01098765432',
        amountEgp: 75.0,
        patientName: 'عمر نور',
      );

      expect(intent.providerName, 'فودافون كاش');
      expect(intent.amountEgp, 75.0);
      expect(intent.ussdCode, '*9*7#');
      expect(intent.referenceNumber, contains('PAYMOB-VF-'));
    });
  });

  group('4. PaymentMethodsScreen Tests', () {
    testWidgets('PaymentMethodsScreen renders all payment options including Paymob & Meeza',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: PaymentMethodsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('طرق الدفع ومحفظة الحساب'), findsWidgets);
      expect(find.text('خيارات الدفع المعتمدة في مصر'), findsOneWidget);
      expect(find.textContaining('كاش عند الاستلام'), findsOneWidget);
      expect(find.textContaining('إنستاباي (InstaPay IPN)'), findsOneWidget);
      expect(find.textContaining('فودافون كاش ومحافظ المحمول'), findsOneWidget);
      expect(find.textContaining('بطاقة بنكية (فيزا / ماستركارد / ميزة)'), findsOneWidget);
    });
  });

  group('5. Delivery Details Sheet Mandatory Address & Paymob Tests', () {
    testWidgets('mandates detailed Egyptian address fields and displays Paymob badge',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DeliveryDetailsSheet(
                inventoryItemId: 'item_test_99',
                pharmacyName: 'صيدلية رشدي - الدقي',
                pharmacyPhone: '01029834112',
                medicationName: 'كونكور 5 مجم',
                medicationPrice: 45.0,
                distanceKm: 3.5, // 3.5km -> base 15 + (1.5 * 4) = 21 EGP -> Total = 66 EGP
                latitude: 30.0444,
                longitude: 31.2357,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & pharmacy name
      expect(find.text('طلب توصيل منزلي فوري 🛵'), findsOneWidget);
      expect(find.text('صيدلية رشدي - الدقي'), findsOneWidget);

      // Verify Paymob official Egyptian badge
      expect(find.text('مدعوم عبر Paymob 🇪🇬'), findsOneWidget);

      // Verify mandatory Egyptian address fields
      expect(find.text('اسم الشارع والحي (إجباري) *'), findsOneWidget);
      expect(find.text('رقم أو اسم العمارة (إجباري) *'), findsOneWidget);
      expect(find.text('رقم الشقة والدور (إجباري) *'), findsOneWidget);
      expect(find.text('رقم الموبايل للتواصل والتأكيد (إجباري) *'), findsOneWidget);

      // Verify courier click-to-call banner
      expect(find.textContaining('اتصال مباشر بالطيار: 01029834112 📞'), findsOneWidget);

      // Verify delivery calculation: 45 EGP + 21 EGP = 66 EGP
      expect(find.text('45.0 ج.م', skipOffstage: false), findsOneWidget);
      expect(find.text('21.0 ج.م', skipOffstage: false), findsOneWidget);
      expect(find.text('66.0 ج.م', skipOffstage: false), findsWidgets);
    });
  });
}
