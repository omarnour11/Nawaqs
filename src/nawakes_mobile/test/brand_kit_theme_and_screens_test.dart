import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/features/onboarding/presentation/patient_onboarding_sheet.dart';

void main() {
  group('Nawaqss Brand Kit v3 Design System & Theme Tests', () {
    test('NawaqsColors tokens match official Brand Kit values', () {
      expect(NawaqsColors.teal, const Color(0xFF0E7C6B));
      expect(NawaqsColors.tealDark, const Color(0xFF0A5A4E));
      expect(NawaqsColors.coral, const Color(0xFFFF5A4E));
      expect(NawaqsColors.coralSoft, const Color(0xFFFFE1DD));
      expect(NawaqsColors.cream, const Color(0xFFFBF7F0));
      expect(NawaqsColors.mint, const Color(0xFFD8F3EA));
      expect(NawaqsColors.mintDeep, const Color(0xFFA9DECB));
      expect(NawaqsColors.ink, const Color(0xFF12222B));
      expect(NawaqsColors.stickerYellow, const Color(0xFFFFD23F));
    });

    test('AppColors map accurately to Brand Tokens', () {
      expect(AppColors.page, NawaqsColors.cream);
      expect(AppColors.accentBlue, NawaqsColors.teal);
      expect(AppColors.accentBlueBg, NawaqsColors.mint);
      expect(AppColors.dangerText, NawaqsColors.coral);
      expect(AppColors.dangerBg, NawaqsColors.coralSoft);
      expect(AppColors.textPrimary, NawaqsColors.ink);
      expect(AppColors.warningIcon, NawaqsColors.stickerYellow);
    });

    test('AppRadius reflects 14px buttons, 16px cards, 22px sheets', () {
      expect(AppRadius.md, 14.0);
      expect(AppRadius.lg, 16.0);
      expect(AppRadius.xl, 22.0);
    });

    test('AppTheme.lightTheme initializes with Teal and Cream', () {
      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, NawaqsColors.cream);
      expect(theme.colorScheme.primary, NawaqsColors.teal);
      expect(theme.colorScheme.secondary, NawaqsColors.coral);
      expect(theme.colorScheme.surface, NawaqsColors.cream);
    });
  });

  group('Nawaqss Brand Kit Vector Widgets Tests', () {
    testWidgets('NawaqssLogo renders mark and typography cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NawaqssLogo(size: 40, showText: true),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('نواقص'), findsOneWidget);
      expect(find.text('Nawaqss'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('NuqousMascot renders in all mood states', (tester) async {
      for (final mood in NuqousMood.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: NuqousMascot(height: 100, mood: mood),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(NuqousMascot), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('NawaqssStatusPill displays correct status labels and colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NawaqssStatusPill(status: 'متاح'),
                NawaqssStatusPill(status: 'قريب'),
                NawaqssStatusPill(status: 'ناقص'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('متاح'), findsOneWidget);
      expect(find.text('قريب'), findsOneWidget);
      expect(find.text('ناقص'), findsOneWidget);
    });

    testWidgets('NawaqssClinicalDisclaimer displays mandatory doctor/pharmacist text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NawaqssClinicalDisclaimer(),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('القرار للدكتور والصيدلي. اسأل صيدلي قبل ما تبدّل.'),
        findsOneWidget,
      );
    });
  });

  group('Patient Onboarding Sheet (Page 14) Tests', () {
    testWidgets('PatientOnboardingSheet navigates from Intro to Permissions step', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PatientOnboardingSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('صوّر الروشتة وخلاص'), findsOneWidget);
      expect(find.text('التالي'), findsOneWidget);
      expect(find.text('تخطي'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      expect(find.text('محتاجين صلاحيتين'), findsOneWidget);
      expect(find.text('الكاميرا'), findsOneWidget);
      expect(find.text('الموقع (GPS)'), findsOneWidget);
      expect(find.text('اسمح بالصلاحيات'), findsOneWidget);
      expect(find.text('مش دلوقتي'), findsOneWidget);
    });
  });
}

