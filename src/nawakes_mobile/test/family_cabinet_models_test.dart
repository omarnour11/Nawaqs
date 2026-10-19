import 'package:flutter_test/flutter_test.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';

void main() {
  group('Family cabinet JSON contracts', () {
    test('parses the GET /family-cabinets payload', () {
      final response = FamilyCabinetResponseModel.fromJson({
        'profiles': [
          {
            'id': '11111111-1111-1111-1111-111111111111',
            'nickname': 'والدي',
            'homeLatitude': 30.0444,
            'homeLongitude': 31.2357,
            'medications': [
              {
                'id': '22222222-2222-2222-2222-222222222222',
                'medicationName': 'Glucophage',
                'strength': '1000mg',
                'stripsCount': 2,
                'unitsPerStrip': 30,
                'dailyDoseUnits': 4,
                'daysRemaining': 15,
                'alertThresholdDays': 7,
                'lastRefillDate': '2026-10-01T10:00:00Z',
              },
            ],
          },
        ],
      });

      expect(response.profiles, hasLength(1));
      final profile = response.profiles.single;
      expect(profile.nickname, 'والدي');
      expect(profile.medications.single.medicationName, 'Glucophage');
      expect(profile.medications.single.daysRemaining, 15);
      expect(profile.medications.single.lastRefillDate, isNotNull);
    });

    test('tolerates a null strength and a null lastRefillDate', () {
      final medication = FamilyMedicationModel.fromJson({
        'id': '22222222-2222-2222-2222-222222222222',
        'medicationName': 'Concor',
        'strength': null,
        'stripsCount': 0,
        'unitsPerStrip': 30,
        'dailyDoseUnits': 1,
        'daysRemaining': 0,
        'alertThresholdDays': 7,
        'lastRefillDate': null,
      });

      expect(medication.strength, isNull);
      expect(medication.lastRefillDate, isNull);
      expect(medication.daysRemaining, 0);
    });

    test('parses the pending-invites payload', () {
      final invite = PendingCaregiverInviteModel.fromJson({
        'linkId': '33333333-3333-3333-3333-333333333333',
        'familyProfileId': '11111111-1111-1111-1111-111111111111',
        'familyProfileNickname': 'والدتي',
        'invitedAt': '2026-10-18T12:00:00Z',
      });

      expect(invite.familyProfileNickname, 'والدتي');
      expect(invite.invitedAt.isUtc, isTrue);
    });

    test('serialises the invite request with the phone number', () {
      final json = InviteCaregiverRequest(invitedPhoneNumber: '01000000000').toJson();

      expect(json['invitedPhoneNumber'], '01000000000');
    });

    test('serialises the refill request', () {
      final json = RefillFamilyMedicationRequest(stripsAdded: 2).toJson();

      expect(json['stripsAdded'], 2);
    });
  });
}
