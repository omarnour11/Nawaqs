import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/services/image_picker_service.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/search/presentation/camera_scan_sheet.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_basket_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_source_sheet.dart';

class MockImagePickerService extends ImagePickerService {
  MockImagePickerService({this.resultToReturn});
  CameraScanResult? resultToReturn;
  bool pickFromGalleryCalled = false;

  @override
  Future<File?> pickFromGallery({
    double? maxWidth = 2048,
    double? maxHeight = 2048,
    int? imageQuality = 88,
  }) async {
    pickFromGalleryCalled = true;
    return File('mock_rx.jpg');
  }

  @override
  Future<CameraScanResult?> processImage(
    File imageFile, {
    dynamic ocrService,
  }) async {
    return resultToReturn;
  }
}

Widget createTestApp({
  required Widget child,
  ImagePickerService? pickerService,
}) {
  return ProviderScope(
    overrides: [
      if (pickerService != null)
        imagePickerServiceProvider.overrideWithValue(pickerService),
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
        child: Scaffold(
          body: Center(child: child),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Prescription OCR Overhaul - Mobile Requirements (R1)', () {
    testWidgets(
        'R1: Non-blocking on-device OCR delivers CameraScanResult even when ML Kit returns 0 lines',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      CameraScanResult? scannedResult;
      // Simulating a cursive handwritten prescription where ML Kit detected 0 lines,
      // but raw image bytes/file are preserved for Tier 1 Cloud AI Vision.
      final mockPicker = MockImagePickerService(
        resultToReturn: CameraScanResult(
          lines: const [],
          croppedImageBase64: 'raw_jpeg_base64_data',
          imageBytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
          imageFile: File('mock_rx.jpg'),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          pickerService: mockPicker,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => PrescriptionSourceSheet.show(
                ctx,
                onScanned: (res) => scannedResult = res,
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap gallery button
      await tester.tap(find.byKey(const ValueKey('source_gallery_button')));
      await tester.pumpAndSettle();

      // Non-blocking: Must NOT halt with error! Must deliver result to onScanned!
      expect(mockPicker.pickFromGalleryCalled, isTrue);
      expect(scannedResult, isNotNull);
      expect(scannedResult!.lines, isEmpty);
      expect(scannedResult!.imageBytes, isNotNull);
      expect(scannedResult!.imageFile, isNotNull);

      // Sheet should be dismissed cleanly
      expect(find.byType(PrescriptionSourceSheet), findsNothing);
    });

    testWidgets(
        'R1: PrescriptionBasketScreen renders trade name, strength, active ingredient, and confidence chip',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        PrescriptionBasketItem(
          tradeName: 'Concor',
          strength: '5mg',
          dosageForm: 'أقراص',
          activeIngredient: 'Bisoprolol Fumarate',
          quantity: 2,
          confidence: 0.94,
        ),
        PrescriptionBasketItem(
          tradeName: 'Catafast',
          strength: '50mg',
          dosageForm: 'فوار',
          activeIngredient: 'Diclofenac Potassium',
          quantity: 1,
          confidence: 0.88,
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          child: PrescriptionBasketScreen(initialItems: items),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('أدوية الروشتة المفروزة'), findsOneWidget);
      expect(find.text('تم استخراج 2 أدوية من الروشتة'), findsOneWidget);

      // Verify Concor details
      expect(find.text('Concor'), findsOneWidget);
      expect(find.text('5mg'), findsOneWidget);
      expect(find.text('أقراص'), findsOneWidget);
      expect(find.text('Bisoprolol Fumarate'), findsOneWidget);
      expect(find.text('دقة 94%'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // quantity

      // Verify Catafast details
      expect(find.text('Catafast'), findsOneWidget);
      expect(find.text('50mg'), findsOneWidget);
      expect(find.text('فوار'), findsOneWidget);
      expect(find.text('Diclofenac Potassium'), findsOneWidget);
      expect(find.text('دقة 88%'), findsOneWidget);

      // Verify Stepper functionality
      // Tap + button for Concor
      final addButtons = find.byIcon(Icons.add_rounded);
      expect(addButtons, findsNWidgets(2));
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget); // Concor quantity became 3
    });

    test('R1: ParsedMedicationResponse handles multi-tier OCR error codes and active ingredients', () {
      final json = {
        'resolvedName': 'Augmentin',
        'strength': '1g',
        'dosageForm': 'Tablets',
        'confidence': 0.96,
        'requiresDisambiguation': false,
        'activeIngredient': 'Amoxicillin / Clavulanic Acid',
        'isSuccess': true,
        'candidates': [
          {
            'tradeName': 'Augmentin',
            'strength': '1g',
            'dosageForm': 'Tablets',
            'confidence': 0.96,
            'quantity': 1,
            'activeIngredient': 'Amoxicillin / Clavulanic Acid',
            'requiresDisambiguation': false,
          }
        ]
      };

      final response = ParsedMedicationResponse.fromJson(json);
      expect(response.resolvedName, 'Augmentin');
      expect(response.activeIngredient, 'Amoxicillin / Clavulanic Acid');
      expect(response.isSuccess, isTrue);
      expect(response.candidates.first.tradeName, 'Augmentin');
      expect(response.candidates.first.activeIngredient, 'Amoxicillin / Clavulanic Acid');
    });

    test('R1: ParsedMedicationResponse parses rawSig, arabicSig, priceEgp, and safetyAlerts', () {
      final json = {
        'resolvedName': 'Concor',
        'strength': '5mg',
        'rawSig': '1x1',
        'arabicSig': 'قرص واحد - مرة واحدة يومياً',
        'priceEgp': 40.5,
        'confidence': 0.95,
        'requiresDisambiguation': false,
        'isSuccess': true,
        'safetyAlerts': [
          {
            'severity': 'Critical',
            'alertCode': 'CONTRAINDICATION_INTERACTION',
            'message': 'تفاعل دوائي خطير',
            'recommendation': 'تجنب الاستخدام المتزامن',
            'interactingSubstances': ['Tizanidine', 'Ciprofloxacin']
          }
        ],
        'candidates': [
          {
            'tradeName': 'Concor',
            'strength': '5mg',
            'rawSig': '1x1',
            'arabicSig': 'قرص واحد - مرة واحدة يومياً',
            'priceEgp': 40.5,
            'confidence': 0.95,
            'quantity': 1,
            'requiresDisambiguation': false,
          }
        ]
      };

      final response = ParsedMedicationResponse.fromJson(json);
      expect(response.rawSig, '1x1');
      expect(response.arabicSig, 'قرص واحد - مرة واحدة يومياً');
      expect(response.priceEgp, 40.5);
      expect(response.safetyAlerts, isNotNull);
      expect(response.safetyAlerts!.length, 1);
      expect(response.safetyAlerts!.first.severity, 'Critical');
      expect(response.safetyAlerts!.first.message, 'تفاعل دوائي خطير');
      expect(response.candidates.first.rawSig, '1x1');
      expect(response.candidates.first.priceEgp, 40.5);
    });

    testWidgets(
        'R1: PrescriptionBasketScreen renders teal Arabic dosage instruction badge, official EGP price, and safety alert HUD banner',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        PrescriptionBasketItem(
          tradeName: 'Concor',
          strength: '5mg',
          dosageForm: 'أقراص',
          activeIngredient: 'Bisoprolol Fumarate',
          quantity: 1,
          confidence: 0.95,
          rawSig: '1x1',
          arabicSig: 'قرص واحد - مرة واحدة يومياً',
          priceEgp: 40.5,
        ),
      ];

      final safetyAlerts = [
        const SafetyAlertResponse(
          severity: 'Critical',
          alertCode: 'CONTRAINDICATION_INTERACTION',
          message: 'تفاعل دوائي حرج: سيردالود وسيبروفلوكساسين',
          recommendation: 'يمنع الاستخدام المتزامن بسبب هبوط الضغط الحاد',
          interactingSubstances: ['Tizanidine', 'Ciprofloxacin'],
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          child: PrescriptionBasketScreen(
            initialItems: items,
            safetyAlerts: safetyAlerts,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Safety Alert HUD banner is rendered
      expect(find.text('تدقيق الأمان والجرعات الدوائية'), findsOneWidget);
      expect(find.text('تفاعل دوائي حرج: سيردالود وسيبروفلوكساسين'), findsOneWidget);
      expect(find.text('يمنع الاستخدام المتزامن بسبب هبوط الضغط الحاد'), findsOneWidget);

      // Verify Official Price EGP badge is rendered
      expect(find.text('السعر: 40.50 ج.م'), findsOneWidget);

      // Verify Teal Arabic Dosage Instruction badge is rendered
      expect(find.text('قرص واحد - مرة واحدة يومياً'), findsOneWidget);
    });
  });
}

