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

    testWidgets('NuqousMascot renders in all mood states and defaults to height 110', (tester) async {
      const defaultMascot = NuqousMascot();
      expect(defaultMascot.height, 110);
      expect(defaultMascot.mood, NuqousMood.welcome);

      for (final mood in NuqousMood.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: NuqousMascot(height: 110, mood: mood),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(NuqousMascot), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('NuqousMascot clamps sub-16px heights (e.g. height: 0.5) to safe 16.0 dimensions and renders cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NuqousMascot(height: 0.5),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(NuqousMascot), findsOneWidget);

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(NuqousMascot),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.height, 16.0);
      expect(sizedBox.width, 12.8);

      final renderBox = tester.renderObject<RenderBox>(find.byType(NuqousMascot));
      expect(renderBox.size.height, 16.0);
      expect(renderBox.size.width, 12.8);

      for (final mood in NuqousMood.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: NuqousMascot(height: 0.5, mood: mood),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final moodSizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(NuqousMascot),
            matching: find.byType(SizedBox),
          ),
        );
        expect(moodSizedBox.height, 16.0);
        expect(moodSizedBox.width, 12.8);
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

  group('Brand Kit v3 Stickers Widget Tests', () {
    testWidgets('NawaqssFoundSticker renders default, custom label, and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NawaqssFoundSticker(),
                NawaqssFoundSticker(label: 'متوفر فوراً!'),
                NawaqssFoundSticker(label: '   '),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('لقيناه!'), findsNWidgets(2));
      expect(find.text('متوفر فوراً!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
    });

    testWidgets('NawaqssShortageSticker renders default, custom label, and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NawaqssShortageSticker(),
                NawaqssShortageSticker(label: 'غير متاح'),
                NawaqssShortageSticker(label: ''),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ناقص!'), findsNWidgets(2));
      expect(find.text('غير متاح'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsNWidgets(3));
    });

    testWidgets('NawaqssPrivacySticker renders Law 151 compliance copy and lock icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NawaqssPrivacySticker(),
                NawaqssPrivacySticker(label: 'خصوصية مشفرة بقانون 151 🔒'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('الاسم والرقم اتحجبوا 🔒'), findsOneWidget);
      expect(find.text('خصوصية مشفرة بقانون 151 🔒'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
    });

    testWidgets('NawaqssSingleMedSticker renders prompt and medication icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NawaqssSingleMedSticker(),
                NawaqssSingleMedSticker(label: 'صنف وحيد'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('دوا واحد بس'), findsOneWidget);
      expect(find.text('صنف وحيد'), findsOneWidget);
      expect(find.byIcon(Icons.medication_outlined), findsNWidgets(2));
    });

    testWidgets('NawaqssCounterSticker handles positive, zero, negative clamping, suffix, and 99+ cap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NawaqssCounterSticker(count: 3),
                NawaqssCounterSticker(count: 5, suffix: 'صيدليات'),
                NawaqssCounterSticker(count: 0),
                NawaqssCounterSticker(count: 0, hideZero: true),
                NawaqssCounterSticker(count: -4),
                NawaqssCounterSticker(count: 142),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('5 صيدليات'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(2)); // count: 0 and count: -4 clamped
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('Stickers support enableTilt, onTap callback, and constrained boundaries', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NawaqssFoundSticker(
                  enableTilt: true,
                  onTap: () => tapped = true,
                ),
                NawaqssShortageSticker(enableTilt: true),
                NawaqssPrivacySticker(enableTilt: true),
                NawaqssSingleMedSticker(enableTilt: true),
                const SizedBox(width: 50, child: NawaqssSingleMedSticker()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(NawaqssFoundSticker));
      await tester.pump();
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('NuqousMascot Named Constructors & Robustness Tests', () {
    testWidgets('Named constructors initialize correct moods', (tester) async {
      const welcome = NuqousMascot.welcome(height: 110);
      const searching = NuqousMascot.searching(height: 110);
      const celebrating = NuqousMascot.celebrating(height: 110);
      const worried = NuqousMascot.worried(height: 110);

      expect(welcome.mood, NuqousMood.welcome);
      expect(searching.mood, NuqousMood.searching);
      expect(celebrating.mood, NuqousMood.celebrating);
      expect(worried.mood, NuqousMood.worried);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [welcome, searching, celebrating, worried],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(NuqousMascot), findsNWidgets(4));
    });

    testWidgets('NuqousMascot paints safely at edge dimensions (0, negative, 16px, 500px)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NuqousMascot(height: 0),
                NuqousMascot(height: -20),
                NuqousMascot(height: 0.5),
                NuqousMascot(height: 16),
                NuqousMascot(height: 500),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
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
