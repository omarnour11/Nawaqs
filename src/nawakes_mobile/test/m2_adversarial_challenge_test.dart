import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_basket_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_scanner_hud_screen.dart';

final Uint8List kAdversarialTestImage = Uint8List.fromList(
  img.encodeJpg(img.Image(width: 100, height: 100)),
);

class MockAdversarialApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Completer<ParsedMedicationResponse>? parseCompleter;

  @override
  Future<ParsedMedicationResponse> parsePrescriptionImage(
    dynamic file,
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 2 Adversarial Challenge — Viewports & Form Factors', () {
    const testViewports = <String, Size>{
      '320x480 (Small Phone)': Size(320, 480),
      '360x640 (Standard Compact)': Size(360, 640),
      '412x732 (Modern Standard)': Size(412, 732),
      '800x1280 (Tablet)': Size(800, 1280),
    };

    for (final entry in testViewports.entries) {
      testWidgets('PrescriptionScannerHudScreen zero RenderFlex overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockApi = MockAdversarialApiClient();
        mockApi.parseCompleter = Completer<ParsedMedicationResponse>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(mockApi),
            ],
            child: MaterialApp(
              home: PrescriptionScannerHudScreen(
                imageBytes: kAdversarialTestImage,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull, reason: 'Scanner HUD threw overflow on ${entry.key}');
        expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FuturisticRadarSweepHudPainter), findsOneWidget);
        expect(find.text('مسح الروشتة الذكي'), findsOneWidget);
      });

      testWidgets('PrescriptionBasketScreen zero RenderFlex overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
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
                  PrescriptionBasketItem(
                    tradeName: 'Concor 5mg',
                    strength: '5mg',
                    dosageForm: 'قرص',
                    quantity: 1,
                    confidence: 0.94,
                    priceEgp: 35.0,
                  ),
                  PrescriptionBasketItem(
                    tradeName: 'Augmentin 1g',
                    strength: '1000mg',
                    dosageForm: 'قرص مضاد حيوي',
                    quantity: 2,
                    confidence: 0.98,
                    priceEgp: 95.5,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'Basket screen threw overflow on ${entry.key}');
        expect(find.byKey(const ValueKey('prescription_privacy_assurance_banner')), findsOneWidget);
        expect(find.text('Concor 5mg'), findsOneWidget);
        expect(find.text('Augmentin 1g'), findsOneWidget);
      });
    }
  });

  group('Milestone 2 Adversarial Challenge — showAddDialog Virtual Keyboard Insets', () {
    testWidgets('Soft keyboard simulation (290px inset) on 360x640 does not trigger RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PrescriptionBasketScreen(
              initialItems: [
                PrescriptionBasketItem(tradeName: 'Panadol', strength: '500mg', quantity: 1),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Open add dialog
      final addBtn = find.byTooltip('إضافة دواء يدوي');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Simulate soft keyboard opening taking 290px bottom inset
      tester.view.viewInsets = const FakeViewPadding(bottom: 290.0);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Virtual keyboard open caused RenderFlex overflow');
      expect(find.text('إضافة دواء للروشتة'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);

      // Verify canceling closes dialog cleanly
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('إضافة دواء للروشتة'), findsNothing);
    });

    testWidgets('Soft keyboard simulation (260px inset) on 320x480 extreme compact does not trigger RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PrescriptionBasketScreen(
              initialItems: [
                PrescriptionBasketItem(tradeName: 'Panadol', strength: '500mg', quantity: 1),
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

      // Simulate soft keyboard on small screen
      tester.view.viewInsets = const FakeViewPadding(bottom: 240.0);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Virtual keyboard open caused overflow on 320x480');
      expect(find.text('إضافة دواء للروشتة'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });
  });

  group('Milestone 2 Adversarial Challenge — Multiline Names, Long Tickers & Empty States', () {
    testWidgets('Extremely long multiline medication name wraps without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const longMedName = 'Amoxicillin Trihydrate Clavulanate Potassium Extended Release Film-Coated Long Medical Formulation 1000mg';
      const longSig = 'قرص واحد مرتين يومياً بعد الأكل مع كوب ماء كامل لمدة أسبوعين متواصلين';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PrescriptionBasketScreen(
              initialItems: [
                PrescriptionBasketItem(
                  tradeName: longMedName,
                  strength: '1000mg / 62.5mg',
                  dosageForm: 'Extended Release Tablet',
                  activeIngredient: 'Amoxicillin + Clavulanic Acid',
                  quantity: 3,
                  arabicSig: longSig,
                  rawSig: '1 tab BID PO PC x14d',
                  priceEgp: 185.75,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'Long medication name caused RenderFlex overflow');
      expect(find.text(longMedName), findsOneWidget);
      expect(find.text(longSig), findsOneWidget);
    });

    testWidgets('Empty medication list state renders center prompt and addition button cleanly', (tester) async {
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
                PrescriptionBasketItem(tradeName: 'Single Item', quantity: 1),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Remove the single item to enter empty state
      final deleteBtn = find.byTooltip('إزالة من السلة');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pump();

      expect(find.text('تمت إزالة جميع الأدوية'), findsOneWidget);
      expect(find.text('إضافة دواء جديد'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify batch search button is disabled when empty
      final searchBtn = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('prescription_basket_batch_search_btn')),
      );
      expect(searchBtn.onPressed, isNull, reason: 'Batch search button must be disabled when basket is empty');
    });

    testWidgets('Privacy banner height is strictly 36px and renders single-line ticker', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PrescriptionBasketScreen(
              initialItems: [
                PrescriptionBasketItem(tradeName: 'Concor', quantity: 1),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final bannerFinder = find.byKey(const ValueKey('prescription_privacy_assurance_banner'));
      expect(bannerFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(bannerFinder);
      expect(renderBox.size.height, equals(36.0));
      expect(find.text('🔒 الاسم والرقم اتحجبوا · خصوصية مشفرة بقانون 151'), findsOneWidget);
    });
  });
}
