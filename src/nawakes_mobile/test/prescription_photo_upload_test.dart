import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawakes_mobile/core/services/image_picker_service.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/search/presentation/camera_scan_sheet.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_source_sheet.dart';

/// Test double for [ImagePickerService] to simulate photo selection and OCR processing.
class FakeImagePickerService extends ImagePickerService {
  FakeImagePickerService({
    this.fileToReturn,
    this.resultToReturn,
  });

  File? fileToReturn;
  CameraScanResult? resultToReturn;
  bool pickFromGalleryCalled = false;
  bool pickFromCameraCalled = false;
  bool processImageCalled = false;

  @override
  Future<File?> pickFromGallery({
    double? maxWidth = 2048,
    double? maxHeight = 2048,
    int? imageQuality = 88,
  }) async {
    pickFromGalleryCalled = true;
    return fileToReturn;
  }

  @override
  Future<File?> pickFromCamera({
    double? maxWidth = 2048,
    double? maxHeight = 2048,
    int? imageQuality = 88,
  }) async {
    pickFromCameraCalled = true;
    return fileToReturn;
  }

  @override
  Future<CameraScanResult?> processImage(
    File imageFile, {
    dynamic ocrService,
  }) async {
    processImageCalled = true;
    return resultToReturn;
  }
}

Widget createTestSourceApp({
  required Widget child,
  required FakeImagePickerService pickerService,
}) {
  return ProviderScope(
    overrides: [
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

  group('Prescription Photo & Gallery Upload Tests', () {
    testWidgets('PrescriptionSourceSheet displays both camera and gallery options with privacy notice',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakePicker = FakeImagePickerService();

      await tester.pumpWidget(
        createTestSourceApp(
          pickerService: fakePicker,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => PrescriptionSourceSheet.show(
                ctx,
                onScanned: (_) {},
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify Header and Options
      expect(find.text('البحث بصورة الروشتة أو الدواء'), findsOneWidget);
      expect(find.text('التقاط صورة بالكاميرا'), findsOneWidget);
      expect(find.text('اختيار صورة من المعرض'), findsOneWidget);
      expect(
        find.textContaining('تتم معالجة الصور وقراءتها بأمان'),
        findsOneWidget,
      );
    });

    testWidgets('Selecting Gallery with recognized medication delivers CameraScanResult and dismisses sheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      CameraScanResult? capturedResult;
      final fakePicker = FakeImagePickerService(
        fileToReturn: File('test_prescription.jpg'),
        resultToReturn: const CameraScanResult(
          lines: ['Concor 5mg', 'Panadol Extra'],
          croppedImageBase64: 'fake_base64_data',
        ),
      );

      await tester.pumpWidget(
        createTestSourceApp(
          pickerService: fakePicker,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => PrescriptionSourceSheet.show(
                ctx,
                onScanned: (res) => capturedResult = res,
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap gallery option
      await tester.tap(find.byKey(const ValueKey('source_gallery_button')));
      await tester.pumpAndSettle();

      // Verify pickFromGallery and processImage were called
      expect(fakePicker.pickFromGalleryCalled, isTrue);
      expect(fakePicker.processImageCalled, isTrue);

      // Verify result delivered
      expect(capturedResult, isNotNull);
      expect(capturedResult!.lines, contains('Concor 5mg'));
      expect(capturedResult!.lines, contains('Panadol Extra'));
      expect(capturedResult!.croppedImageBase64, 'fake_base64_data');

      // Verify bottom sheet is dismissed
      expect(find.byType(PrescriptionSourceSheet), findsNothing);
    });

    testWidgets('Selecting Gallery and cancelling does not throw error and keeps sheet available',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      CameraScanResult? capturedResult;
      final fakePicker = FakeImagePickerService(fileToReturn: null);

      await tester.pumpWidget(
        createTestSourceApp(
          pickerService: fakePicker,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => PrescriptionSourceSheet.show(
                ctx,
                onScanned: (res) => capturedResult = res,
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap gallery option
      await tester.tap(find.byKey(const ValueKey('source_gallery_button')));
      await tester.pumpAndSettle();

      expect(fakePicker.pickFromGalleryCalled, isTrue);
      expect(capturedResult, isNull);
      // Sheet stays open
      expect(find.byType(PrescriptionSourceSheet), findsOneWidget);
    });

    testWidgets('Selecting Gallery with unreadable photo shows friendly Arabic error message',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakePicker = FakeImagePickerService(
        fileToReturn: File('blurry_rx.jpg'),
        resultToReturn: const CameraScanResult(lines: []),
      );

      await tester.pumpWidget(
        createTestSourceApp(
          pickerService: fakePicker,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => PrescriptionSourceSheet.show(
                ctx,
                onScanned: (_) {},
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap gallery option
      await tester.tap(find.byKey(const ValueKey('source_gallery_button')));
      await tester.pumpAndSettle();

      // Verify error message is rendered
      expect(
        find.textContaining('لم نتمكن من قراءة اسم الدواء من الصورة'),
        findsOneWidget,
      );
      // Options remain accessible so user can try again
      expect(find.byKey(const ValueKey('source_gallery_button')), findsOneWidget);
    });

    testWidgets('Tapping Camera in PrescriptionSourceSheet transitions to camera scan',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakePicker = FakeImagePickerService();

      await tester.pumpWidget(
        createTestSourceApp(
          pickerService: fakePicker,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => PrescriptionSourceSheet.show(
                ctx,
                onScanned: (_) {},
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap camera option
      await tester.tap(find.byKey(const ValueKey('source_camera_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Source sheet popped, CameraScanSheet opened
      expect(find.byType(PrescriptionSourceSheet), findsNothing);
      expect(find.byType(CameraScanSheet), findsOneWidget);
    });

    testWidgets('Gallery button inside CameraScanSheet allows choosing photo and triggers onScanned',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      CameraScanResult? scannedResult;
      final fakePicker = FakeImagePickerService(
        fileToReturn: File('rx_photo.jpg'),
        resultToReturn: const CameraScanResult(
          lines: ['Augmentin 1g'],
          croppedImageBase64: 'augmentin_base64',
        ),
      );

      await tester.pumpWidget(
        createTestSourceApp(
          pickerService: fakePicker,
          child: CameraScanSheet(
            onScanned: (res) => scannedResult = res,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify gallery button exists in CameraScanSheet
      final galleryBtn = find.byKey(const ValueKey('camera_sheet_gallery_button'));
      expect(galleryBtn, findsOneWidget);

      // Tap gallery button
      await tester.tap(galleryBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify gallery picker called and result forwarded
      expect(fakePicker.pickFromGalleryCalled, isTrue);
      expect(scannedResult, isNotNull);
      expect(scannedResult!.lines, contains('Augmentin 1g'));
    });

    test('ImagePickerService returns null if image file does not exist', () async {
      final service = ImagePickerService();
      final result = await service.processImage(File('does_not_exist_xyz.jpg'));
      expect(result, isNull);
    });
  });
}
