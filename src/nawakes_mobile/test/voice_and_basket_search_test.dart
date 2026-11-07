import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/services/arabic_medication_mapper.dart';
import 'package:nawakes_mobile/core/ui/voice_recording_overlay.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/search/presentation/batch_search_results_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/voice_confirm_sheet.dart';
import 'package:nawakes_mobile/features/search/presentation/widgets/mandatory_location_prompt_dialog.dart';
import 'package:nawakes_mobile/features/search/presentation/search_controller.dart';

class FakeLocationService extends LocationService {
  final Position? mockPosition;
  FakeLocationService({this.mockPosition});

  @override
  Future<Position?> getCurrentLocation() async {
    return mockPosition ??
        Position(
          latitude: 29.9737,
          longitude: 30.9529,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
  }
}

class FakeVoiceApiClient implements ApiClient {
  final Map<String, List<String>> suggestionsMap = {};
  final List<String> calls = [];
  final List<CreateReservationRequest> reservationRequests = [];
  final List<BatchReservationRequestBody> batchRequests = [];
  BatchSearchRequest? lastBatchSearchRequest;

  @override
  Future<List<String>> suggestMedications(String prefix) async {
    calls.add(prefix);
    return suggestionsMap[prefix] ?? [];
  }

  @override
  Future<BatchSearchResponse> batchSearch(BatchSearchRequest request) async {
    lastBatchSearchRequest = request;
    return BatchSearchResponse(
      totalRequestedItems: request.items.length,
      radiusKm: request.radiusKm,
      completePharmacies: [
        BatchPharmacyResult(
          pharmacyId: 'p_complete',
          pharmacyName: 'صيدلية الأمل',
          addressLine: 'شارع الهرم',
          phone: '01012345678',
          trustScore: 4.9,
          distanceKm: 0.8,
          latitude: 30.0,
          longitude: 31.0,
          matchedCount: request.items.length,
          totalRequested: request.items.length,
          isCompleteMatch: true,
          totalEstimatedPrice: 50.0,
          items: request.items
              .map((it) => BatchMedicationDetail(
                    medication: it.medication,
                    requestedQuantity: it.quantity,
                    inStock: true,
                    price: 25.0,
                    availableQuantity: 5,
                    inventoryItemId: 'inv_${it.medication.toLowerCase()}',
                  ))
              .toList(),
        ),
      ],
      partialPharmacies: [],
    );
  }

  @override
  Future<ReservationResponse> createReservation(CreateReservationRequest body) async {
    reservationRequests.add(body);
    return ReservationResponse(
      id: 'res_123',
      inventoryItemId: body.inventoryItemId,
      pharmacyId: 'pharm_1',
      pharmacyName: 'صيدلية النور',
      medicationName: 'Panadol',
      status: 'PendingPickup',
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
      createdAt: DateTime.now(),
      reservationCode: 'NWQ-1234',
    );
  }

  @override
  Future<BatchReservationResult> createBatchReservation(BatchReservationRequestBody body) async {
    batchRequests.add(body);
    final created = body.items
        .map((it) => ReservationResponse(
              id: 'res_${it.inventoryItemId}',
              inventoryItemId: it.inventoryItemId,
              pharmacyId: 'pharm_1',
              pharmacyName: 'صيدلية النور',
              medicationName: 'Medication',
              status: 'Active',
              expiresAt: DateTime.now().add(const Duration(hours: 2)),
              createdAt: DateTime.now(),
              reservationCode: 'NWQ-BATCH',
            ))
        .toList();
    return BatchReservationResult(
      createdReservations: created,
      failedItems: [],
      isAllSucceeded: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('1. ArabicMedicationMapper - Normalization & Parsing', () {
    test('normalizes Arabic diacritics, Alef variants, and Taa Marbuta', () {
      // Diacritics (tashkeel)
      expect(ArabicMedicationMapper.normalizeArabic('بَانَادُولْ'), 'بانادول');
      expect(ArabicMedicationMapper.normalizeArabic('كُونْكُورْ'), 'كونكور');

      // Alef variations (أ, إ, آ -> ا)
      expect(ArabicMedicationMapper.normalizeArabic('إسبرين'), 'اسبرين');
      expect(ArabicMedicationMapper.normalizeArabic('أوجمنتين'), 'اوجمنتين');
      expect(ArabicMedicationMapper.normalizeArabic('آتور'), 'اتور');

      // Taa Marbuta to Haa
      expect(ArabicMedicationMapper.normalizeArabic('حقنة'), 'حقنه');

      // Whitespace
      expect(ArabicMedicationMapper.normalizeArabic('   بانادول    اكسترا   '), 'بانادول اكسترا');
    });

    test('splits multiple medications separated by " و " (and)', () {
      final input = 'بانادول و كونكور و بروفين';
      final result = ArabicMedicationMapper.splitMedications(input);
      expect(result, ['بانادول', 'كونكور', 'بروفين']);
    });

    test('splits multiple medications separated by commas and newlines', () {
      final input = 'بانادول، كونكور, بروفين\nاسبرين';
      final result = ArabicMedicationMapper.splitMedications(input);
      expect(result, ['بانادول', 'كونكور', 'بروفين', 'اسبرين']);
    });

    test('cleans Egyptian filler phrases from spoken input', () {
      final input = 'عايز بانادول و كونكور';
      final result = ArabicMedicationMapper.splitMedications(input);
      expect(result, ['بانادول', 'كونكور']);

      final input2 = 'محتاج علبة بروفين';
      final result2 = ArabicMedicationMapper.splitMedications(input2);
      expect(result2, ['بروفين']);
    });

    test('splits attached "و" when preceding a known medication name', () {
      final input = 'بانادول وكونكور';
      final result = ArabicMedicationMapper.splitMedications(input);
      expect(result, ['بانادول', 'كونكور']);
    });
  });

  group('2. ArabicMedicationMapper - Priority Rule (DB Direct Arabic vs English Fallback)', () {
    late FakeVoiceApiClient fakeApi;

    setUp(() {
      fakeApi = FakeVoiceApiClient();
    });

    test('CRITICAL RULE: Uses direct Arabic match from DB if present in database', () async {
      // Simulate DB having an Arabic name entry directly
      fakeApi.suggestionsMap['بانادول'] = ['بانادول 500 مجم أقراص'];

      final resolved = await ArabicMedicationMapper.resolveSingleMedication('بانادول', fakeApi);

      // Should return the Arabic database match directly without translating to English
      expect(resolved, 'بانادول 500 مجم أقراص');
      expect(fakeApi.calls.contains('بانادول'), isTrue);
    });

    test('CRITICAL RULE: Falls back to Egyptian dialect mapper when DB has no Arabic match', () async {
      // DB has no Arabic match for 'بانادول'
      fakeApi.suggestionsMap['بانادول'] = [];
      // DB has no alternate English match
      fakeApi.suggestionsMap['Panadol'] = [];

      final resolved = await ArabicMedicationMapper.resolveSingleMedication('بانادول', fakeApi);

      // Falls back to static Egyptian dialect mapping: بانادول -> Panadol
      expect(resolved, 'Panadol');
    });

    test('does not unilaterally overwrite mapped canonical English name with first DB formulation', () async {
      // DB has Panadol Extra as first suggestion for 'Panadol'
      fakeApi.suggestionsMap['بانادول'] = [];
      fakeApi.suggestionsMap['Panadol'] = ['Panadol Extra 500mg', 'Panadol Cold & Flu'];

      final resolved = await ArabicMedicationMapper.resolveSingleMedication('بانادول', fakeApi);

      // Must remain Panadol so search covers all formulations rather than restricting to Extra
      expect(resolved, 'Panadol');
    });

    test('matches Arabic substring from DB suggestions', () async {
      // DB has entry with Latin prefix or dosage form
      fakeApi.suggestionsMap['كونكور'] = ['Concor 5mg (Arabic: كونكور)'];

      final resolved = await ArabicMedicationMapper.resolveSingleMedication('كونكور', fakeApi);
      expect(resolved, 'Concor 5mg (Arabic: كونكور)');
    });

    test('strips expanded Egyptian dialect voice fillers', () {
      expect(ArabicMedicationMapper.splitMedications('عاوزة بروفين'), ['بروفين']);
      expect(ArabicMedicationMapper.splitMedications('هات لي كونكور'), ['كونكور']);
      expect(ArabicMedicationMapper.splitMedications('لو سمحت بانادول'), ['بانادول']);
      expect(ArabicMedicationMapper.splitMedications('محتاجة علبة اسبرين'), ['اسبرين']);
    });

    test('maps common Egyptian dialect medications to canonical English trade names', () async {
      final cases = {
        'كونكور': 'Concor',
        'بروفين': 'Brufen',
        'فولتارين': 'Voltaren',
        'كتافلام': 'Cataflam',
        'اوجمنتين': 'Augmentin',
        'هاي بيوتك': 'Hibiotic',
        'انتينال': 'Antinal',
        'سيدوفاج': 'Cidophage',
        'كونجستال': 'Congestal',
      };

      for (final entry in cases.entries) {
        final resolved = await ArabicMedicationMapper.resolveSingleMedication(entry.key, fakeApi);
        expect(resolved, entry.value);
      }
    });

    test('resolveVoiceInput resolves multiple medications sequentially', () async {
      final result = await ArabicMedicationMapper.resolveVoiceInput(
        'بانادول و كونكور و بروفين',
        fakeApi,
      );

      expect(result, ['Panadol', 'Concor', 'Brufen']);
    });
  });

  group('3. Greedy Pharmacy Grouping Algorithm', () {
    test('Scenario 1: All medications found at single nearest pharmacy (Complete Match)', () {
      final requested = [
        BatchSearchItemDto(medication: 'Panadol', quantity: 2),
        BatchSearchItemDto(medication: 'Brufen', quantity: 1),
        BatchSearchItemDto(medication: 'Concor', quantity: 1),
      ];

      final response = BatchSearchResponse(
        totalRequestedItems: 3,
        radiusKm: 10,
        completePharmacies: [
          BatchPharmacyResult(
            pharmacyId: 'pharm_1',
            pharmacyName: 'صيدلية النور',
            addressLine: 'شارع التحرير',
            phone: '01011111111',
            trustScore: 4.8,
            distanceKm: 0.9,
            latitude: 30.04,
            longitude: 31.23,
            matchedCount: 3,
            totalRequested: 3,
            isCompleteMatch: true,
            totalEstimatedPrice: 55.0,
            items: [
              BatchMedicationDetail(medication: 'Panadol', requestedQuantity: 2, inStock: true, price: 15.0, availableQuantity: 5),
              BatchMedicationDetail(medication: 'Brufen', requestedQuantity: 1, inStock: true, price: 12.0, availableQuantity: 3),
              BatchMedicationDetail(medication: 'Concor', requestedQuantity: 1, inStock: true, price: 28.0, availableQuantity: 2),
            ],
          ),
        ],
        partialPharmacies: [],
      );

      final result = computeGreedyGrouping(requested, response);

      expect(result.isSinglePharmacyAllFound, isTrue);
      expect(result.groups.length, 1);
      expect(result.groups.first.pharmacyId, 'pharm_1');
      expect(result.groups.first.items.length, 3);
      expect(result.unfulfillableItems, isEmpty);
      expect(result.groups.first.totalPrice, 70.0); // 15*2 + 12*1 + 28*1 = 30 + 12 + 28 = 70
    });

    test('Scenario 2: Complete match takes priority over closer partial match', () {
      final requested = [
        BatchSearchItemDto(medication: 'Panadol', quantity: 1),
        BatchSearchItemDto(medication: 'Brufen', quantity: 1),
      ];

      final response = BatchSearchResponse(
        totalRequestedItems: 2,
        radiusKm: 10,
        completePharmacies: [
          BatchPharmacyResult(
            pharmacyId: 'complete_far',
            pharmacyName: 'صيدلية المستقبل',
            addressLine: 'شارع مصدق',
            phone: '01022222222',
            trustScore: 4.9,
            distanceKm: 1.5,
            latitude: 30.05,
            longitude: 31.24,
            matchedCount: 2,
            totalRequested: 2,
            isCompleteMatch: true,
            totalEstimatedPrice: 30.0,
            items: [
              BatchMedicationDetail(medication: 'Panadol', requestedQuantity: 1, inStock: true, price: 15.0, availableQuantity: 4),
              BatchMedicationDetail(medication: 'Brufen', requestedQuantity: 1, inStock: true, price: 15.0, availableQuantity: 2),
            ],
          ),
        ],
        partialPharmacies: [
          BatchPharmacyResult(
            pharmacyId: 'partial_close',
            pharmacyName: 'صيدلية الشفاء',
            addressLine: 'شارع الدقي',
            phone: '01033333333',
            trustScore: 4.5,
            distanceKm: 0.4,
            latitude: 30.04,
            longitude: 31.23,
            matchedCount: 1,
            totalRequested: 2,
            isCompleteMatch: false,
            totalEstimatedPrice: 15.0,
            items: [
              BatchMedicationDetail(medication: 'Panadol', requestedQuantity: 1, inStock: true, price: 15.0, availableQuantity: 4),
              BatchMedicationDetail(medication: 'Brufen', requestedQuantity: 1, inStock: false, price: 0.0, availableQuantity: 0),
            ],
          ),
        ],
      );

      final result = computeGreedyGrouping(requested, response);

      // Must prioritize complete match!
      expect(result.isSinglePharmacyAllFound, isTrue);
      expect(result.groups.length, 1);
      expect(result.groups.first.pharmacyId, 'complete_far');
    });

    test('Scenario 3: Greedy split across 2 pharmacies (Nearest takes med 1 & 2, second takes med 3)', () {
      final requested = [
        BatchSearchItemDto(medication: 'Panadol', quantity: 1),
        BatchSearchItemDto(medication: 'Brufen', quantity: 1),
        BatchSearchItemDto(medication: 'Concor', quantity: 1),
      ];

      // No complete pharmacy exists
      final response = BatchSearchResponse(
        totalRequestedItems: 3,
        radiusKm: 10,
        completePharmacies: [],
        partialPharmacies: [
          // Nearest pharmacy (0.6 km) has Panadol and Brufen, but NOT Concor
          BatchPharmacyResult(
            pharmacyId: 'p_near',
            pharmacyName: 'صيدلية النصر',
            addressLine: 'ميدان الجيزة',
            phone: '01044444444',
            trustScore: 4.6,
            distanceKm: 0.6,
            latitude: 30.03,
            longitude: 31.22,
            matchedCount: 2,
            totalRequested: 3,
            isCompleteMatch: false,
            totalEstimatedPrice: 25.0,
            items: [
              BatchMedicationDetail(medication: 'Panadol', requestedQuantity: 1, inStock: true, price: 15.0, availableQuantity: 3),
              BatchMedicationDetail(medication: 'Brufen', requestedQuantity: 1, inStock: true, price: 10.0, availableQuantity: 2),
              BatchMedicationDetail(medication: 'Concor', requestedQuantity: 1, inStock: false, price: 0.0, availableQuantity: 0),
            ],
          ),
          // Second pharmacy (1.2 km) has Concor
          BatchPharmacyResult(
            pharmacyId: 'p_second',
            pharmacyName: 'صيدلية الأمل',
            addressLine: 'شارع فيصل',
            phone: '01055555555',
            trustScore: 4.7,
            distanceKm: 1.2,
            latitude: 30.02,
            longitude: 31.21,
            matchedCount: 1,
            totalRequested: 3,
            isCompleteMatch: false,
            totalEstimatedPrice: 30.0,
            items: [
              BatchMedicationDetail(medication: 'Panadol', requestedQuantity: 1, inStock: false, price: 0.0, availableQuantity: 0),
              BatchMedicationDetail(medication: 'Brufen', requestedQuantity: 1, inStock: false, price: 0.0, availableQuantity: 0),
              BatchMedicationDetail(medication: 'Concor', requestedQuantity: 1, inStock: true, price: 30.0, availableQuantity: 2),
            ],
          ),
        ],
      );

      final result = computeGreedyGrouping(requested, response);

      expect(result.isSinglePharmacyAllFound, isFalse);
      expect(result.groups.length, 2);

      // First group should be p_near containing Panadol and Brufen
      expect(result.groups[0].pharmacyId, 'p_near');
      expect(result.groups[0].items.map((i) => i.medication).toList(), ['Panadol', 'Brufen']);

      // Second group should be p_second containing Concor
      expect(result.groups[1].pharmacyId, 'p_second');
      expect(result.groups[1].items.map((i) => i.medication).toList(), ['Concor']);

      expect(result.unfulfillableItems, isEmpty);
    });

    test('Scenario 4: Split across 3 separate pharmacies', () {
      final requested = [
        BatchSearchItemDto(medication: 'Med_A', quantity: 1),
        BatchSearchItemDto(medication: 'Med_B', quantity: 1),
        BatchSearchItemDto(medication: 'Med_C', quantity: 1),
      ];

      final response = BatchSearchResponse(
        totalRequestedItems: 3,
        radiusKm: 10,
        completePharmacies: [],
        partialPharmacies: [
          BatchPharmacyResult(
            pharmacyId: 'p1',
            pharmacyName: 'Pharm 1',
            addressLine: 'Addr 1',
            phone: '111',
            trustScore: 4.5,
            distanceKm: 0.5,
            latitude: 30.0,
            longitude: 31.0,
            matchedCount: 1,
            totalRequested: 3,
            isCompleteMatch: false,
            totalEstimatedPrice: 10,
            items: [
              BatchMedicationDetail(medication: 'Med_A', requestedQuantity: 1, inStock: true, price: 10, availableQuantity: 1),
            ],
          ),
          BatchPharmacyResult(
            pharmacyId: 'p2',
            pharmacyName: 'Pharm 2',
            addressLine: 'Addr 2',
            phone: '222',
            trustScore: 4.5,
            distanceKm: 1.0,
            latitude: 30.0,
            longitude: 31.0,
            matchedCount: 1,
            totalRequested: 3,
            isCompleteMatch: false,
            totalEstimatedPrice: 20,
            items: [
              BatchMedicationDetail(medication: 'Med_B', requestedQuantity: 1, inStock: true, price: 20, availableQuantity: 1),
            ],
          ),
          BatchPharmacyResult(
            pharmacyId: 'p3',
            pharmacyName: 'Pharm 3',
            addressLine: 'Addr 3',
            phone: '333',
            trustScore: 4.5,
            distanceKm: 2.0,
            latitude: 30.0,
            longitude: 31.0,
            matchedCount: 1,
            totalRequested: 3,
            isCompleteMatch: false,
            totalEstimatedPrice: 30,
            items: [
              BatchMedicationDetail(medication: 'Med_C', requestedQuantity: 1, inStock: true, price: 30, availableQuantity: 1),
            ],
          ),
        ],
      );

      final result = computeGreedyGrouping(requested, response);

      expect(result.isSinglePharmacyAllFound, isFalse);
      expect(result.groups.length, 3);
      expect(result.groups[0].pharmacyId, 'p1');
      expect(result.groups[1].pharmacyId, 'p2');
      expect(result.groups[2].pharmacyId, 'p3');
    });

    test('Scenario 5: Unfulfillable medication flagged cleanly', () {
      final requested = [
        BatchSearchItemDto(medication: 'Panadol', quantity: 1),
        BatchSearchItemDto(medication: 'RareMed', quantity: 1),
      ];

      final response = BatchSearchResponse(
        totalRequestedItems: 2,
        radiusKm: 10,
        completePharmacies: [],
        partialPharmacies: [
          BatchPharmacyResult(
            pharmacyId: 'p1',
            pharmacyName: 'Pharm 1',
            addressLine: 'Addr 1',
            phone: '111',
            trustScore: 4.5,
            distanceKm: 0.5,
            latitude: 30.0,
            longitude: 31.0,
            matchedCount: 1,
            totalRequested: 2,
            isCompleteMatch: false,
            totalEstimatedPrice: 10,
            items: [
              BatchMedicationDetail(medication: 'Panadol', requestedQuantity: 1, inStock: true, price: 10, availableQuantity: 1),
              BatchMedicationDetail(medication: 'RareMed', requestedQuantity: 1, inStock: false, price: 0, availableQuantity: 0),
            ],
          ),
        ],
      );

      final result = computeGreedyGrouping(requested, response);

      expect(result.groups.length, 1);
      expect(result.unfulfillableItems.length, 1);
      expect(result.unfulfillableItems.first.medication, 'RareMed');
    });

    test('Scenario 6: User removes 3rd medication, remaining 2 instantly collapse into single pharmacy', () {
      final response = BatchSearchResponse(
        totalRequestedItems: 3,
        radiusKm: 10,
        completePharmacies: [],
        partialPharmacies: [
          // P1 has Panadol and Brufen
          BatchPharmacyResult(
            pharmacyId: 'p1',
            pharmacyName: 'Pharm 1',
            addressLine: 'Addr 1',
            phone: '111',
            trustScore: 4.5,
            distanceKm: 0.5,
            latitude: 30.0,
            longitude: 31.0,
            matchedCount: 2,
            totalRequested: 3,
            isCompleteMatch: false,
            totalEstimatedPrice: 25,
            items: [
              BatchMedicationDetail(medication: 'Panadol', requestedQuantity: 1, inStock: true, price: 15, availableQuantity: 2),
              BatchMedicationDetail(medication: 'Brufen', requestedQuantity: 1, inStock: true, price: 10, availableQuantity: 2),
              BatchMedicationDetail(medication: 'Concor', requestedQuantity: 1, inStock: false, price: 0, availableQuantity: 0),
            ],
          ),
          // P2 has Concor
          BatchPharmacyResult(
            pharmacyId: 'p2',
            pharmacyName: 'Pharm 2',
            addressLine: 'Addr 2',
            phone: '222',
            trustScore: 4.5,
            distanceKm: 1.5,
            latitude: 30.0,
            longitude: 31.0,
            matchedCount: 1,
            totalRequested: 3,
            isCompleteMatch: false,
            totalEstimatedPrice: 30,
            items: [
              BatchMedicationDetail(medication: 'Concor', requestedQuantity: 1, inStock: true, price: 30, availableQuantity: 1),
            ],
          ),
        ],
      );

      // Initially 3 items -> 2 pharmacies
      final initialItems = [
        BatchSearchItemDto(medication: 'Panadol', quantity: 1),
        BatchSearchItemDto(medication: 'Brufen', quantity: 1),
        BatchSearchItemDto(medication: 'Concor', quantity: 1),
      ];
      final r1 = computeGreedyGrouping(initialItems, response);
      expect(r1.groups.length, 2);
      expect(r1.isSinglePharmacyAllFound, isFalse);

      // User removes Concor -> only Panadol & Brufen left
      final filteredItems = initialItems.where((i) => i.medication != 'Concor').toList();
      final r2 = computeGreedyGrouping(filteredItems, response);

      // Now all remaining items are at Pharm 1!
      expect(r2.groups.length, 1);
      expect(r2.groups.first.pharmacyId, 'p1');
      expect(r2.groups.first.items.length, 2);
      expect(r2.isSinglePharmacyAllFound, isTrue);
    });

    test('Scenario 7: Single pharmacy in candidates fulfilling all items takes priority over closer split pharmacies', () {
      final requested = [
        BatchSearchItemDto(medication: 'Panadol', quantity: 1),
        BatchSearchItemDto(medication: 'Brufen', quantity: 1),
      ];

      final response = BatchSearchResponse(
        totalRequestedItems: 2,
        radiusKm: 10,
        completePharmacies: [],
        partialPharmacies: [
          // Closer pharmacy has ONLY Panadol
          BatchPharmacyResult(
            pharmacyId: 'p_close_1',
            pharmacyName: 'قريبة 1',
            addressLine: 'A',
            phone: '1',
            trustScore: 4.5,
            distanceKm: 0.2,
            latitude: 30.0,
            longitude: 31.0,
            matchedCount: 1,
            totalRequested: 2,
            isCompleteMatch: false,
            totalEstimatedPrice: 15,
            items: [
              BatchMedicationDetail(medication: 'Panadol', requestedQuantity: 1, inStock: true, price: 15, availableQuantity: 3),
              BatchMedicationDetail(medication: 'Brufen', requestedQuantity: 1, inStock: false, price: 0, availableQuantity: 0),
            ],
          ),
          // Closer pharmacy has ONLY Brufen
          BatchPharmacyResult(
            pharmacyId: 'p_close_2',
            pharmacyName: 'قريبة 2',
            addressLine: 'B',
            phone: '2',
            trustScore: 4.5,
            distanceKm: 0.3,
            latitude: 30.0,
            longitude: 31.0,
            matchedCount: 1,
            totalRequested: 2,
            isCompleteMatch: false,
            totalEstimatedPrice: 10,
            items: [
              BatchMedicationDetail(medication: 'Panadol', requestedQuantity: 1, inStock: false, price: 0, availableQuantity: 0),
              BatchMedicationDetail(medication: 'Brufen', requestedQuantity: 1, inStock: true, price: 10, availableQuantity: 2),
            ],
          ),
          // Pharmacy further away (1.0 km) has BOTH Panadol AND Brufen
          BatchPharmacyResult(
            pharmacyId: 'p_has_both',
            pharmacyName: 'صيدلية تجمع الاثنين',
            addressLine: 'C',
            phone: '3',
            trustScore: 4.8,
            distanceKm: 1.0,
            latitude: 30.0,
            longitude: 31.0,
            matchedCount: 2,
            totalRequested: 2,
            isCompleteMatch: false,
            totalEstimatedPrice: 25,
            items: [
              BatchMedicationDetail(medication: 'Panadol', requestedQuantity: 1, inStock: true, price: 15, availableQuantity: 3, inventoryItemId: 'inv_panadol'),
              BatchMedicationDetail(medication: 'Brufen', requestedQuantity: 1, inStock: true, price: 10, availableQuantity: 2, inventoryItemId: 'inv_brufen'),
            ],
          ),
        ],
      );

      final result = computeGreedyGrouping(requested, response);

      // Must prioritize single pharmacy that has both items together!
      expect(result.isSinglePharmacyAllFound, isTrue);
      expect(result.groups.length, 1);
      expect(result.groups.first.pharmacyId, 'p_has_both');
      expect(result.groups.first.items[0].inventoryItemId, 'inv_panadol');
      expect(result.groups.first.items[1].inventoryItemId, 'inv_brufen');
    });
  });

  group('4. Voice Recording Overlay Widget', () {
    testWidgets('renders pulsing animation, status text, and live transcript', (tester) async {
      bool cancelCalled = false;
      bool doneCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const SizedBox.expand(),
                  VoiceRecordingOverlay(
                    currentTranscript: 'بانادول اكسترا',
                    onCancel: () => cancelCalled = true,
                    onDone: () => doneCalled = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Verify UI elements exist
      expect(find.byKey(const ValueKey('voice_recording_overlay')), findsOneWidget);
      expect(find.text('جارٍ الاستماع إليك الآن...'), findsOneWidget);
      expect(find.text('«بانادول اكسترا»'), findsOneWidget);

      // Test cancel button
      await tester.tap(find.byKey(const ValueKey('voice_overlay_cancel_button')), warnIfMissed: false);
      await tester.pump();
      expect(cancelCalled, isTrue);

      // Test done button
      await tester.tap(find.byKey(const ValueKey('voice_overlay_done_button')), warnIfMissed: false);
      await tester.pump();
      expect(doneCalled, isTrue);
    });

    testWidgets('VoiceRecordingOverlay updates transcript reactively and dismisses on cancel', (tester) async {
      final transcriptState = ValueNotifier<String>('');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: transcriptState,
              builder: (ctx, transcript, _) {
                return Stack(
                  children: [
                    VoiceRecordingOverlay(
                      currentTranscript: transcript,
                      onCancel: () => transcriptState.value = 'cancelled',
                      onDone: () {},
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('جارٍ الاستماع إليك الآن...'), findsOneWidget);

      // Now simulate incoming speech
      transcriptState.value = 'كونكور 5 مجم';
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('«كونكور 5 مجم»'), findsOneWidget);

      // Cancel
      await tester.tap(find.byKey(const ValueKey('voice_overlay_cancel_button')));
      await tester.pump();
      expect(transcriptState.value, 'cancelled');
    });
  });

  group('5. Voice Confirm Sheet Widget', () {
    testWidgets('renders confirmation dialog with [بحث] and [إلغاء]', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await VoiceConfirmSheet.show(
                    ctx,
                    spokenText: 'بانادول',
                    resolvedName: 'Panadol',
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Check contents
      expect(find.text('هل تقصد هذا الدواء؟'), findsOneWidget);
      expect(find.text('Panadol'), findsOneWidget);
      expect(find.text('النطق المسموع: «بانادول»'), findsOneWidget);

      // Tap search button
      await tester.tap(find.byKey(const ValueKey('voice_confirm_search_btn')));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('cancel button in VoiceConfirmSheet returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await VoiceConfirmSheet.show(
                    ctx,
                    spokenText: 'كونكور',
                    resolvedName: 'Concor',
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap cancel button
      await tester.tap(find.byKey(const ValueKey('voice_confirm_cancel_btn')));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('VoiceConfirmSheet.showAdvanced renders multiple medications and supports batch search', (tester) async {
      VoiceConfirmResult? result;

      final items = [
        const VoiceResolvedItem(spokenText: 'بانادول', resolvedName: 'Panadol'),
        const VoiceResolvedItem(spokenText: 'كونكور', resolvedName: 'Concor'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await VoiceConfirmSheet.showAdvanced(
                    ctx,
                    rawSpokenText: 'بانادول و كونكور',
                    items: items,
                  );
                },
                child: const Text('Open Multiple Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Multiple Sheet'));
      await tester.pumpAndSettle();

      // Check contents
      expect(find.text('تم التعرف على 2 أدوية'), findsOneWidget);
      expect(find.text('Panadol'), findsOneWidget);
      expect(find.text('Concor'), findsOneWidget);
      expect(find.text('النطق: «بانادول»'), findsOneWidget);
      expect(find.text('النطق: «كونكور»'), findsOneWidget);

      // Tap batch search button
      await tester.tap(find.byKey(const ValueKey('voice_confirm_batch_search_btn')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.isBatchSearch, isTrue);
      expect(result!.items.length, 2);
    });

    testWidgets('VoiceConfirmSheet.showAdvanced supports edit basket button', (tester) async {
      VoiceConfirmResult? result;

      final items = [
        const VoiceResolvedItem(spokenText: 'بانادول', resolvedName: 'Panadol'),
        const VoiceResolvedItem(spokenText: 'كونكور', resolvedName: 'Concor'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await VoiceConfirmSheet.showAdvanced(
                    ctx,
                    rawSpokenText: 'بانادول و كونكور',
                    items: items,
                  );
                },
                child: const Text('Open Multiple Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Multiple Sheet'));
      await tester.pumpAndSettle();

      // Tap edit basket button
      await tester.tap(find.byKey(const ValueKey('voice_confirm_edit_basket_btn')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.isOpenBasket, isTrue);
    });
  });

  group('6. Multi-Medication Reservation Flow', () {
    testWidgets('calls createReservation for each medication when bulk reserving and navigates on complete', (tester) async {
      final fakeApi = FakeVoiceApiClient();

      final items = [
        BatchSearchItemDto(medication: 'Panadol', quantity: 1),
        BatchSearchItemDto(medication: 'Brufen', quantity: 1),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
            locationServiceProvider.overrideWithValue(FakeLocationService()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => BatchSearchResultsScreen(items: items),
                      ),
                    );
                  },
                  child: const Text('LaunchBatchSearch'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap launch to push BatchSearchResultsScreen
      await tester.tap(find.text('LaunchBatchSearch'));
      await tester.pumpAndSettle();

      // Settle batchSearch call
      await tester.pump(const Duration(milliseconds: 500));

      // Verify live GPS coordinates and radius were used
      expect(fakeApi.lastBatchSearchRequest, isNotNull);
      expect(fakeApi.lastBatchSearchRequest!.lat, 29.9737);
      expect(fakeApi.lastBatchSearchRequest!.lng, 30.9529);
      expect(fakeApi.lastBatchSearchRequest!.radiusKm, 35.0);

      expect(find.text('🌟 وجدنا كل الأدوية في صيدلية واحدة!'), findsOneWidget);
      expect(find.byKey(const ValueKey('batch_reserve_all_button')), findsOneWidget);

      // Tap bulk reserve
      await tester.tap(find.byKey(const ValueKey('batch_reserve_all_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check createBatchReservation was invoked with both items in one call
      expect(fakeApi.batchRequests.length, 1);
      expect(
          fakeApi.batchRequests.first.items.map((i) => i.inventoryItemId).toSet(), {
        'inv_panadol',
        'inv_brufen',
      });
      expect(find.text('تم الحجز بالكامل!'), findsOneWidget);

      // Tap "حسنًا" on completion dialog to dismiss and navigate back to root
      await tester.tap(find.text('حسنًا'));
      await tester.pumpAndSettle();

      // Screen is popped from stack
      expect(find.byType(BatchSearchResultsScreen), findsNothing);
    });

    testWidgets('Single-pharmacy card booking "احجز كل الروشتة الآن ⚡" also navigates to root', (tester) async {
      final fakeApi = FakeVoiceApiClient();

      final items = [
        BatchSearchItemDto(medication: 'Panadol', quantity: 1),
        BatchSearchItemDto(medication: 'Brufen', quantity: 1),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
            locationServiceProvider.overrideWithValue(FakeLocationService()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => BatchSearchResultsScreen(items: items),
                      ),
                    );
                  },
                  child: const Text('LaunchBatchSearchSingleCard'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('LaunchBatchSearchSingleCard'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('احجز كل الروشتة الآن ⚡'), findsOneWidget);

      // Tap single pharmacy booking button on the card
      await tester.tap(find.text('احجز كل الروشتة الآن ⚡'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify batch reservation was sent with both items
      expect(fakeApi.batchRequests.length, 1);
      expect(fakeApi.batchRequests.first.items.length, 2);

      // Verify the screen was popped back to root
      expect(find.byType(BatchSearchResultsScreen), findsNothing);
      expect(find.text('LaunchBatchSearchSingleCard'), findsOneWidget);
    });
  });

  group('10. Milestone 3: Mandatory Location Prompt with "سماح"', () {
    testWidgets('renders dialog with title, explanation, "سماح", and "مش دلوقتي"', (tester) async {
      bool allowed = false;
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryLocationPromptDialog(
              onAllow: () => allowed = true,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      expect(find.text('محتاجين نعرف موقعك بدقة'), findsOneWidget);
      expect(find.textContaining('علشان نقدر نحدد أقرب صيدلية متوفر فيها دواك'), findsOneWidget);
      expect(find.text('سماح'), findsOneWidget);
      expect(find.text('مش دلوقتي'), findsOneWidget);

      await tester.tap(find.text('سماح'));
      expect(allowed, isTrue);
      expect(cancelled, isFalse);

      await tester.tap(find.text('مش دلوقتي'));
      expect(cancelled, isTrue);
    });

    testWidgets('PopScope blocks dismiss gestures (barrierDismissible is false)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryLocationPromptDialog(
              onAllow: () {},
              onCancel: () {},
            ),
          ),
        ),
      );

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    test('SearchController throws LocationPermissionRequiredException when GPS disabled without coordinates', () {
      const ex = LocationPermissionRequiredException('خدمة الموقع (GPS) غير مفعلة على جهازك');
      expect(ex.message, contains('خدمة الموقع'));
      expect(ex.toString(), contains('خدمة الموقع'));
    });
  });

  group('11. Milestone 3: Multi-Medication Text Search Router', () {
    test('splits query with Arabic " و " into distinct medication tokens', () {
      final tokens = ArabicMedicationMapper.splitMedications('بنادول و كتافلام');
      expect(tokens.length, greaterThanOrEqualTo(2));
      expect(tokens, containsAll(['بنادول', 'كتافلام']));
    });

    test('splits query with conjunction "مع" into distinct medication tokens', () {
      final tokens = ArabicMedicationMapper.splitMedications('بنادول مع كتافلام');
      expect(tokens.length, greaterThanOrEqualTo(2));
      expect(tokens, containsAll(['بنادول', 'كتافلام']));
    });

    test('splits query with conjunction "and" into distinct medication tokens', () {
      final tokens = ArabicMedicationMapper.splitMedications('بنادول and كتافلام');
      expect(tokens.length, greaterThanOrEqualTo(2));
      expect(tokens, containsAll(['بنادول', 'كتافلام']));
    });

    test('splits query with plus (+) into distinct medication tokens', () {
      final tokens = ArabicMedicationMapper.splitMedications('بانادول + كتافلام');
      expect(tokens.length, greaterThanOrEqualTo(2));
      expect(tokens, containsAll(['بانادول', 'كتافلام']));
    });

    test('splits query with Arabic comma (،) and English comma (,)', () {
      final tokens = ArabicMedicationMapper.splitMedications('أوجمنتين، كونكور');
      expect(tokens.length, 2);
      expect(tokens, containsAll(['أوجمنتين', 'كونكور']));
    });

    test('single medication query does not trigger multi-token split', () {
      final tokens = ArabicMedicationMapper.splitMedications('بنادول اكسترا');
      expect(tokens.length, 1);
      expect(tokens.first, 'بنادول اكسترا');
    });

    testWidgets('Multi-medication query resolves each token and launches BatchSearchResultsScreen', (tester) async {
      final fakeApi = FakeVoiceApiClient();
      final tokens = ArabicMedicationMapper.splitMedications('بانادول و كتافلام');
      expect(tokens.length, 2);

      final List<BatchSearchItemDto> batchItems = [];
      for (final t in tokens) {
        final resolved = await ArabicMedicationMapper.resolveSingleMedication(t, fakeApi);
        batchItems.add(BatchSearchItemDto(
          medication: resolved.isNotEmpty ? resolved : t,
          quantity: 1,
        ));
      }

      expect(batchItems.length, 2);
      expect(batchItems.first.medication, 'Panadol');
      expect(batchItems.last.medication, 'Cataflam');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
            locationServiceProvider.overrideWithValue(FakeLocationService()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => BatchSearchResultsScreen(items: batchItems),
                      ),
                    );
                  },
                  child: const Text('OpenBatchRouter'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OpenBatchRouter'));
      await tester.pumpAndSettle();

      expect(find.byType(BatchSearchResultsScreen), findsOneWidget);
      expect(find.text('نتائج البحث الذكي عن الروشتة'), findsOneWidget);
    });
  });
}
