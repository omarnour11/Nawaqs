import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:nawakes_mobile/features/search/presentation/medication_equivalents_card.dart';
import 'package:nawakes_mobile/features/search/presentation/medication_equivalents_sheet.dart';

void main() {
  final sampleResponse = MedicationEquivalentsResponse(
    original: OriginalMedicationInfoDto(
      tradeName: 'Concor 5mg',
      activeIngredient: 'Bisoprolol fumarate',
      strength: '5 mg',
      dosageForm: 'Film-Coated Tablets',
      officialPriceEGP: 45.0,
      isAvailableNearby: false,
      commercialNameAr: 'كونكور 5 مجم',
      manufacturer: 'Merck',
    ),
    availableEquivalents: [
      EquivalentPharmacyResultDto(
        equivalentTradeName: 'Bisor 5mg',
        commercialNameAr: 'بيسور 5 مجم',
        manufacturer: 'Amoun',
        officialPriceEGP: 30.0,
        priceAtPharmacy: 28.5,
        priceSavingPercent: 36.6,
        priceDifferenceEGP: 16.5,
        pharmacyId: '11111111-1111-1111-1111-111111111111',
        pharmacyName: 'صيدلية النصر بالدقي',
        distanceKm: 0.8,
        inventoryItemId: '22222222-2222-2222-2222-222222222222',
        strength: '5 mg',
        dosageForm: 'Tablets',
        isExactBioequivalent: true,
        matchCategory: 'ExactBioequivalent',
        inStock: true,
      ),
      EquivalentPharmacyResultDto(
        equivalentTradeName: 'Lodoz 5/6.25mg',
        commercialNameAr: 'لودوز 5/6.25 مجم',
        manufacturer: 'Merck',
        officialPriceEGP: 55.0,
        priceAtPharmacy: 55.0,
        priceSavingPercent: 0.0,
        priceDifferenceEGP: 0.0,
        pharmacyId: '33333333-3333-3333-3333-333333333333',
        pharmacyName: 'صيدلية العزبي المهندسين',
        distanceKm: 1.5,
        inventoryItemId: '44444444-4444-4444-4444-444444444444',
        strength: '5/6.25 mg',
        dosageForm: 'Film-Coated Tablets',
        isExactBioequivalent: false,
        matchCategory: 'DosageFormOrStrengthAlternative',
        inStock: true,
      ),
    ],
    legalDisclaimer: 'المثائل الحيوية تحتوي على نفس المادة الفعالة وتُصرف كبدائل نظامية متطابقة.',
    isActiveIngredientSearch: false,
    activeIngredient: 'Bisoprolol fumarate',
    activeIngredientAr: 'بيسوبرولول فومارات',
    totalRegisteredInEgypt: 14,
    bioequivalents: [
      EquivalentPharmacyResultDto(
        equivalentTradeName: 'Bisor 5mg',
        commercialNameAr: 'بيسور 5 مجم',
        manufacturer: 'Amoun',
        officialPriceEGP: 30.0,
        priceAtPharmacy: 28.5,
        priceSavingPercent: 36.6,
        priceDifferenceEGP: 16.5,
        pharmacyId: '11111111-1111-1111-1111-111111111111',
        pharmacyName: 'صيدلية النصر بالدقي',
        distanceKm: 0.8,
        inventoryItemId: '22222222-2222-2222-2222-222222222222',
        strength: '5 mg',
        dosageForm: 'Tablets',
        isExactBioequivalent: true,
        matchCategory: 'ExactBioequivalent',
        inStock: true,
      ),
    ],
    therapeuticAlternatives: [
      EquivalentPharmacyResultDto(
        equivalentTradeName: 'Lodoz 5/6.25mg',
        commercialNameAr: 'لودوز 5/6.25 مجم',
        manufacturer: 'Merck',
        officialPriceEGP: 55.0,
        priceAtPharmacy: 55.0,
        priceSavingPercent: 0.0,
        priceDifferenceEGP: 0.0,
        pharmacyId: '33333333-3333-3333-3333-333333333333',
        pharmacyName: 'صيدلية العزبي المهندسين',
        distanceKm: 1.5,
        inventoryItemId: '44444444-4444-4444-4444-444444444444',
        strength: '5/6.25 mg',
        dosageForm: 'Film-Coated Tablets',
        isExactBioequivalent: false,
        matchCategory: 'DosageFormOrStrengthAlternative',
        inStock: true,
      ),
    ],
  );

  group('Medication Equivalents Model Serialization', () {
    test('toJson and fromJson preserves all clinical and EDA fields', () {
      final json = sampleResponse.toJson();
      final parsed = MedicationEquivalentsResponse.fromJson(json);

      expect(parsed.totalRegisteredInEgypt, 14);
      expect(parsed.activeIngredientAr, 'بيسوبرولول فومارات');
      expect(parsed.bioequivalents, isNotNull);
      expect(parsed.bioequivalents!.length, 1);
      expect(parsed.therapeuticAlternatives!.length, 1);
      expect(parsed.availableEquivalents.length, 2);

      final firstBio = parsed.bioequivalents!.first;
      expect(firstBio.equivalentTradeName, 'Bisor 5mg');
      expect(firstBio.commercialNameAr, 'بيسور 5 مجم');
      expect(firstBio.isExactBioequivalent, isTrue);
      expect(firstBio.priceDifferenceEGP, 16.5);
      expect(firstBio.priceSavingPercent, 36.6);
    });
  });

  group('MedicationEquivalentsCard Widget Tests', () {
    testWidgets('renders active ingredient, savings badge and view all button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: MedicationEquivalentsCard(
                response: sampleResponse,
                medicationName: 'Concor 5mg',
              ),
            ),
          ),
        ),
      );

      // Verify Active Ingredient pill is rendered
      expect(find.textContaining('بيسوبرولول فومارات'), findsOneWidget);
      // Verify Bioequivalent drug name
      expect(find.text('Bisor 5mg'), findsOneWidget);
      // Verify pharmacy name
      expect(find.textContaining('صيدلية النصر بالدقي'), findsOneWidget);
      // Verify button to view all
      expect(find.textContaining('عرض جميع المثائل والبدائل'), findsOneWidget);
      // Verify disclaimer text
      expect(find.textContaining('المثائل الحيوية'), findsOneWidget);
    });
  });

  group('MedicationEquivalentsSheet Widget Tests', () {
    testWidgets('renders tabs, bioequivalents, alternatives, and EDA disclaimer', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: MedicationEquivalentsSheet(
                  medicationName: 'Concor 5mg',
                  preloadedResponse: sampleResponse,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clinical Title and Active INN
      expect(find.text('المثائل والبدائل بالاسم العلمي'), findsOneWidget);
      expect(find.textContaining('بيسوبرولول فومارات'), findsOneWidget);

      // Tabs: Bioequivalents, Alternatives, All
      expect(find.text('المثائل المتطابقة'), findsOneWidget);
      expect(find.text('البدائل والتركيزات'), findsOneWidget);
      expect(find.text('الكل'), findsOneWidget);

      // Tab 0 (Bioequivalents) selected by default -> Bisor 5mg should be visible
      expect(find.text('Bisor 5mg'), findsOneWidget);
      expect(find.text('بيسور 5 مجم'), findsOneWidget);
      expect(find.text('مثيل متطابق 100%'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.textContaining('٣٧%'), findsOneWidget);

      // Tap Tab 1: البدائل والتركيزات
      await tester.tap(find.text('البدائل والتركيزات'));
      await tester.pumpAndSettle();

      // Lodoz 5/6.25mg should now be visible in Alternatives tab
      expect(find.text('Lodoz 5/6.25mg'), findsOneWidget);
      expect(find.text('بديل / تركيز آخر'), findsOneWidget);

      // Tap Tab 2: الكل
      await tester.tap(find.text('الكل'));
      await tester.pumpAndSettle();

      // Both should be in the list
      expect(find.text('Bisor 5mg'), findsOneWidget);
      expect(find.text('Lodoz 5/6.25mg'), findsOneWidget);

      // Regulatory disclaimer
      expect(find.textContaining('إقرار هيئة الدواء المصرية'), findsOneWidget);
    });
  });
}
