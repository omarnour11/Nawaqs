import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nawakes_mobile/core/services/search_history_service.dart';
import 'package:nawakes_mobile/core/services/payment_methods_service.dart';
import 'package:nawakes_mobile/features/profile/presentation/payment_methods_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/widgets/delivery_details_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. SearchHistoryService Tests', () {
    test('adds search query, deduplicates and keeps recent first', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(searchHistoryProvider.notifier);
      await notifier.addQuery('بانادول');
      await notifier.addQuery('كونكور 5');
      await notifier.addQuery('أوجمنتين 1 جم');

      var list = container.read(searchHistoryProvider);
      expect(list.first, 'أوجمنتين 1 جم');
      expect(list.length, 3);

      // Re-adding بانادول brings it to top
      await notifier.addQuery('بانادول');
      list = container.read(searchHistoryProvider);
      expect(list.first, 'بانادول');
      expect(list.length, 3);
    });

    test('removes query and clears history cleanly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(searchHistoryProvider.notifier);
      await notifier.addQuery('أسبوسيد');
      await notifier.addQuery('كتافلام');
      expect(container.read(searchHistoryProvider).length, 2);

      await notifier.removeQuery('أسبوسيد');
      expect(container.read(searchHistoryProvider), ['كتافلام']);

      await notifier.clearAll();
      expect(container.read(searchHistoryProvider), isEmpty);
    });
  });

  group('2. PaymentMethodsService & Screen Tests', () {
    test('updates default payment method, InstaPay and Vodafone Cash', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(paymentMethodsProvider.notifier);
      await notifier.setDefaultType(PaymentType.instapay);
      expect(container.read(paymentMethodsProvider).defaultType, PaymentType.instapay);

      await notifier.updateInstapay('omar@instapay');
      expect(container.read(paymentMethodsProvider).instapayHandle, 'omar@instapay');

      await notifier.updateVodafoneCash('01012345678');
      expect(container.read(paymentMethodsProvider).vodafoneCashNumber, '01012345678');
    });

    testWidgets('PaymentMethodsScreen renders all 4 payment options with Egyptian localization',
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

  group('3. Delivery Details Sheet & Motorcycle Calculation Tests', () {
    testWidgets('DeliveryDetailsSheet calculates ETA, delivery fee, and Egyptian address form',
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
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & pharmacy name
      expect(find.text('طلب توصيل منزلي فوري 🛵'), findsOneWidget);
      expect(find.text('صيدلية رشدي - الدقي'), findsOneWidget);

      // Verify motorcycle delivery banner with ETA & courier phone
      expect(find.textContaining('توصيل سريع بطيار موتوسيكل'), findsOneWidget);
      expect(find.textContaining('01029834112'), findsOneWidget);

      // Verify Talabat-style Egyptian address fields (no postal codes!)
      expect(find.text('اسم الشارع والمنطقة *'), findsOneWidget);
      expect(find.text('رقم أو اسم العمارة *'), findsOneWidget);
      expect(find.text('رقم الشقة والدور *'), findsOneWidget);
      expect(find.text('رقم الموبايل للتواصل *'), findsOneWidget);

      // Verify delivery calculation (using skipOffstage: false since it's scrolled in sheet):
      // 45 EGP + 21 EGP = 66 EGP
      expect(find.text('45.0 ج.م', skipOffstage: false), findsOneWidget);
      expect(find.text('21.0 ج.م', skipOffstage: false), findsOneWidget);
      expect(find.text('66.0 ج.م', skipOffstage: false), findsWidgets);
    });
  });
}
