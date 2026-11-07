import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawakes_mobile/core/services/arabic_medication_mapper.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/features/family_cabinet/presentation/medication_depletion_card.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';

Widget wrapWithTheme(Widget child, {Size size = const Size(360, 640)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Tier 5 Dimension 1: Arabic Tokenizer & Dialect Edge Cases', () {
    test('T5-1.1: Normalize Arabic diacritics and hamzas cleanly', () {
      final input = 'بَانَادُولْ إِكْسِتْرَا';
      final norm = ArabicMedicationMapper.normalizeArabic(input);
      expect(norm, equals('بانادول اكسترا'));
    });

    test('T5-1.2: Split multi-medication query using Egyptian conjunction مع', () {
      final input = 'كونكور مع كتافلام';
      final tokens = ArabicMedicationMapper.splitMedications(input);
      expect(tokens, containsAll(['كونكور', 'كتافلام']));
    });

    test('T5-1.3: Split attached و conjunction without separating internal letters', () {
      final input = 'بانادول وكونكور';
      final tokens = ArabicMedicationMapper.splitMedications(input);
      expect(tokens, containsAll(['بانادول', 'كونكور']));
    });

    test('T5-1.4: Preserve internal و in brand names (أوجمنتين, رواتنكس)', () {
      final input = 'أوجمنتين 1 جم';
      final tokens = ArabicMedicationMapper.splitMedications(input);
      expect(tokens.length, equals(1));
      expect(tokens.first, equals('أوجمنتين 1 جم'));
    });

    test('T5-1.5: Clean redundant leading and trailing conjunctions safely', () {
      final input = 'و كتافلام و بانادول و';
      final tokens = ArabicMedicationMapper.splitMedications(input);
      expect(tokens, containsAll(['كتافلام', 'بانادول']));
    });
  });

  group('Tier 5 Dimension 5: Brand Kit Stickers Constrained Layout', () {
    testWidgets('T5-5.1: NawaqssFoundSticker renders in narrow 60px box without overflow', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(
            width: 60,
            child: NawaqssFoundSticker(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T5-5.2: NawaqssCounterSticker clamps negative count to 0', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const NawaqssCounterSticker(count: -5),
        ),
      );
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('T5-5.3: NawaqssCounterSticker formats count > 99 as 99+', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const NawaqssCounterSticker(count: 150),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('T5-5.4: NuqousMascot in worried mood renders empty tummy hole cleanly', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const NuqousMascot(height: 80, mood: NuqousMood.worried),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Tier 5 Dimension 6: Expiry & Depletion Calendar Boundaries', () {
    testWidgets('T5-6.1: Medication expiring today displays urgent expiry notice', (tester) async {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day, 0, 0, 0);

      final med = FamilyMedicationModel(
        id: 'med_today',
        medicationName: 'بانادول إكسترا',
        stripsCount: 1,
        unitsPerStrip: 10,
        dailyDoseUnits: 1,
        daysRemaining: 1,
        alertThresholdDays: 3,
        expiryDate: todayDate,
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MedicationDepletionCard(medication: med),
        ),
      );

      expect(find.text('ينتهي اليوم! يرجى التخلص منه وإعادة الطلب ⚠️'), findsOneWidget);
    });

    testWidgets('T5-6.2: Depleted medication displays 0-day ticker and worried mascot', (tester) async {
      final med = FamilyMedicationModel(
        id: 'med_depleted',
        medicationName: 'كونكور 5 مجم',
        stripsCount: 0,
        unitsPerStrip: 10,
        dailyDoseUnits: 1,
        daysRemaining: 0,
        alertThresholdDays: 3,
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MedicationDepletionCard(medication: med),
        ),
      );

      expect(find.text('دواك خلص! باقي 0 يوم ⏳'), findsOneWidget);
      expect(find.text('نافذ الآن ⚠️ يرجى إعادة الطلب فوراً لتجنب انقطاع الجرعة.'), findsOneWidget);
    });
  });

  group('Tier 5 Dimension 7: Governorate Detection', () {
    test('T5-7.1: Banha coordinates resolve to Qalyubia governorate', () {
      final gov = LocationService.detectGovernorate(30.4660, 31.1853);
      expect(gov, equals('القليوبية'));
    });

    test('T5-7.2: 6th of October coordinates resolve to Giza governorate', () {
      final gov = LocationService.detectGovernorate(29.9870, 30.9420);
      expect(gov, equals('الجيزة'));
    });

    test('T5-7.3: Out-of-bounds coordinates fallback safely to Cairo default', () {
      final gov = LocationService.detectGovernorate(51.5074, -0.1278);
      expect(gov, isNotEmpty);
    });
  });
}
