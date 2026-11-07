import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  // ==========================================================================
  // ADVERSARIAL GROUP 1: Tight Parent Containers (50px, 80px, 120px)
  // & Extreme Label / Emoji / Newline Injection
  // ==========================================================================
  group('Adversarial Group 1: Tight Parent Containers & Label Injection', () {
    const tightWidths = [50.0, 80.0, 120.0];

    for (final width in tightWidths) {
      testWidgets('NawaqssFoundSticker with massive 150-char label in width ${width}px renders with zero overflow', (tester) async {
        const extremeLabel = 'لقيناه في صيدلية العزبي فرع المهندسين شارع جامعة الدول العربية بجوار محطة المترو ومتاح فوراً';
        await tester.pumpWidget(
          wrapWidget(
            SizedBox(
              width: width,
              child: const NawaqssFoundSticker(label: extremeLabel),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(NawaqssFoundSticker), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      });

      testWidgets('NawaqssShortageSticker with dense emoji sequence in width ${width}px renders with zero overflow', (tester) async {
        const emojiLabel = '🚨🔥⚡️💊🔒💉🩺🎉🥳💯🚀⚠️';
        await tester.pumpWidget(
          wrapWidget(
            SizedBox(
              width: width,
              child: const NawaqssShortageSticker(label: emojiLabel),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(NawaqssShortageSticker), findsOneWidget);
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      });

      testWidgets('NawaqssPrivacySticker with multiline newline injection in width ${width}px ellipsizes safely', (tester) async {
        const multilineLabel = 'الاسم والرقم اتحجبوا 🔒\nسطر جديد مسرب\nمحاولة كسر التنسيق بالأسطر\nقانون 151';
        await tester.pumpWidget(
          wrapWidget(
            SizedBox(
              width: width,
              child: const NawaqssPrivacySticker(label: multilineLabel),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(NawaqssPrivacySticker), findsOneWidget);
        expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      });

      testWidgets('NawaqssSingleMedSticker with mixed RTL/LTR and ZWJ in width ${width}px renders with zero overflow', (tester) async {
        const mixedLabel = 'دوا واحد بس: Panadol® Extra 500mg 👨‍⚕️ \u200E(30 Tablets)';
        await tester.pumpWidget(
          wrapWidget(
            SizedBox(
              width: width,
              child: const NawaqssSingleMedSticker(label: mixedLabel),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(NawaqssSingleMedSticker), findsOneWidget);
        expect(find.byIcon(Icons.medication_outlined), findsOneWidget);
      });

      testWidgets('NawaqssCounterSticker with extreme values (999999, negative, large suffix) in width ${width}px', (tester) async {
        await tester.pumpWidget(
          wrapWidget(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: width,
                  child: const NawaqssCounterSticker(count: 999999, suffix: 'صيدليات معتمدة في القاهرة الكبرى'),
                ),
                SizedBox(
                  width: width,
                  child: const NawaqssCounterSticker(count: -42, suffix: 'عناصر ناقصة'),
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(NawaqssCounterSticker), findsNWidgets(2));
      });
    }

    testWidgets('Empty strings and whitespace-only labels gracefully fallback to canonical Egyptian defaults', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const Column(
            children: [
              NawaqssFoundSticker(label: ''),
              NawaqssFoundSticker(label: '   \t  \n  '),
              NawaqssShortageSticker(label: ''),
              NawaqssShortageSticker(label: '   '),
              NawaqssPrivacySticker(label: ''),
              NawaqssPrivacySticker(label: '   '),
              NawaqssSingleMedSticker(label: ''),
              NawaqssSingleMedSticker(label: '   '),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('لقيناه!'), findsNWidgets(2));
      expect(find.text('ناقص!'), findsNWidgets(2));
      expect(find.text('الاسم والرقم اتحجبوا 🔒'), findsNWidgets(2));
      expect(find.text('دوا واحد بس'), findsNWidgets(2));
    });

    testWidgets('Overlarge custom fontSize (36dp) in narrow 60px box does not cause RenderFlex overflow', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const SizedBox(
            width: 60,
            child: NawaqssFoundSticker(fontSize: 36),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // ==========================================================================
  // ADVERSARIAL GROUP 2: Rapid Tap Gestures & Tilt Transforms
  // ==========================================================================
  group('Adversarial Group 2: Rapid Tap Gestures & Tilt Transforms', () {
    testWidgets('NawaqssFoundSticker handles 50 rapid consecutive taps accurately without dropping events or crashing', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        wrapWidget(
          NawaqssFoundSticker(
            enableTilt: true,
            onTap: () => tapCount++,
          ),
        ),
      );
      await tester.pump();

      for (int i = 0; i < 50; i++) {
        await tester.tap(find.byType(NawaqssFoundSticker));
      }
      await tester.pump();

      expect(tapCount, equals(50));
      expect(tester.takeException(), isNull);
    });

    testWidgets('NawaqssShortageSticker handles rapid taps with tilt transform', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        wrapWidget(
          NawaqssShortageSticker(
            enableTilt: true,
            onTap: () => tapCount++,
          ),
        ),
      );
      await tester.pump();

      for (int i = 0; i < 25; i++) {
        await tester.tap(find.byType(NawaqssShortageSticker));
      }
      await tester.pump();

      expect(tapCount, equals(25));
      expect(tester.takeException(), isNull);
    });

    testWidgets('NawaqssPrivacySticker handles rapid taps with tilt transform', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        wrapWidget(
          NawaqssPrivacySticker(
            enableTilt: true,
            onTap: () => tapCount++,
          ),
        ),
      );
      await tester.pump();

      for (int i = 0; i < 25; i++) {
        await tester.tap(find.byType(NawaqssPrivacySticker));
      }
      await tester.pump();

      expect(tapCount, equals(25));
      expect(tester.takeException(), isNull);
    });

    testWidgets('NawaqssSingleMedSticker handles rapid taps with tilt transform', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        wrapWidget(
          NawaqssSingleMedSticker(
            enableTilt: true,
            onTap: () => tapCount++,
          ),
        ),
      );
      await tester.pump();

      for (int i = 0; i < 25; i++) {
        await tester.tap(find.byType(NawaqssSingleMedSticker));
      }
      await tester.pump();

      expect(tapCount, equals(25));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tilt transforms configure exact rotation angles per design token specification', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const Column(
            children: [
              NawaqssFoundSticker(enableTilt: true),
              NawaqssShortageSticker(enableTilt: true),
              NawaqssPrivacySticker(enableTilt: true),
              NawaqssSingleMedSticker(enableTilt: true),
              NawaqssFoundSticker(enableTilt: false),
            ],
          ),
        ),
      );
      await tester.pump();

      final transforms = tester.widgetList<Transform>(find.byType(Transform)).toList();
      // Exactly 4 tilted stickers have a Transform widget
      expect(transforms.length, equals(4));

      // Found sticker angle is -0.04 rad
      expect(transforms[0].transform.storage[1], closeTo(math.sin(-0.04), 1e-4));
      // Shortage sticker angle is +0.04 rad
      expect(transforms[1].transform.storage[1], closeTo(math.sin(0.04), 1e-4));
      // Privacy sticker angle is -0.03 rad
      expect(transforms[2].transform.storage[1], closeTo(math.sin(-0.03), 1e-4));
      // SingleMed sticker angle is +0.03 rad
      expect(transforms[3].transform.storage[1], closeTo(math.sin(0.03), 1e-4));
    });

    testWidgets('When onTap is null, no GestureDetector is mounted (zero overhead)', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const NawaqssFoundSticker(enableTilt: true),
        ),
      );
      await tester.pump();

      expect(find.descendant(of: find.byType(NawaqssFoundSticker), matching: find.byType(GestureDetector)), findsNothing);
    });
  });

  // ==========================================================================
  // ADVERSARIAL GROUP 3: NawaqssCounterSticker Extreme Boundaries
  // ==========================================================================
  group('Adversarial Group 3: NawaqssCounterSticker Extreme Boundaries', () {
    testWidgets('hideZero: true with count <= 0 renders SizedBox.shrink', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const Column(
            children: [
              NawaqssCounterSticker(count: 0, hideZero: true),
              NawaqssCounterSticker(count: -10, hideZero: true),
              NawaqssCounterSticker(count: 1, hideZero: true),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('count clamping: negative values clamp to 0 and values > 99 cap to 99+', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const Column(
            children: [
              NawaqssCounterSticker(count: -1),
              NawaqssCounterSticker(count: -999),
              NawaqssCounterSticker(count: 99),
              NawaqssCounterSticker(count: 100),
              NawaqssCounterSticker(count: 10000),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('99'), findsOneWidget);
      expect(find.text('99+'), findsNWidgets(2));
    });
  });
}
