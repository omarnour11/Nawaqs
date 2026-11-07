import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';

void main() {
  group('Adversarial Challenge: NuqousMascot Extreme Dimensions & Constraints', () {
    testWidgets('NuqousMascot stress test with extreme dimensions (0, -50, 0.5, 5000)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  NuqousMascot(height: 0),
                  NuqousMascot(height: -50),
                  NuqousMascot(height: 0.5),
                  NuqousMascot(height: 5000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('NuqousMascot renders all 4 moods under tight constrained layout boxes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: NuqousMascot.welcome(height: 110),
                  ),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: NuqousMascot.searching(height: 110),
                  ),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: NuqousMascot.celebrating(height: 110),
                  ),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: NuqousMascot.worried(height: 110),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(NuqousMascot), findsNWidgets(4));
    });

    testWidgets('NuqousMascot zero and non-positive canvas bounds early-return safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 0,
              height: 0,
              child: NuqousMascot.searching(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Challenge: NawaqssCounterSticker Boundary & Unicode Tests', () {
    testWidgets('Extreme count values (-999999, 0, 999999) format correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NawaqssCounterSticker(count: -999999),
                NawaqssCounterSticker(count: 0),
                NawaqssCounterSticker(count: 0, hideZero: true),
                NawaqssCounterSticker(count: 999999),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Negative clamped to 0, zero displayed when hideZero=false, overflow capped at 99+
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('Empty and whitespace-only suffixes are ignored without trailing space', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NawaqssCounterSticker(count: 4, suffix: ''),
                NawaqssCounterSticker(count: 7, suffix: '   '),
                NawaqssCounterSticker(count: 12, suffix: null),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('4'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('Unicode RTL and emoji suffixes render cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NawaqssCounterSticker(count: 5, suffix: 'صيدليات'),
                NawaqssCounterSticker(count: 1, suffix: 'صيدلية (متاح) 🛵'),
                NawaqssCounterSticker(count: 2, suffix: '\u200Fصيدلية'),
                NawaqssCounterSticker(count: 150, suffix: 'بديل'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('5 صيدليات'), findsOneWidget);
      expect(find.text('1 صيدلية (متاح) 🛵'), findsOneWidget);
      expect(find.text('2 \u200Fصيدلية'), findsOneWidget);
      expect(find.text('99+ بديل'), findsOneWidget);
    });

    testWidgets('Counter sticker in narrow container does not throw RenderFlex error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 15,
              child: NawaqssCounterSticker(count: 8, suffix: 'صيدليات قريبة جدا'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
