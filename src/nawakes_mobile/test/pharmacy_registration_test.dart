import 'package:flutter_test/flutter_test.dart';
import 'package:nawakes_mobile/features/auth/data/auth_models.dart';

void main() {
  group('Pharmacy and Patient registration serialization', () {
    test('Patient registration serializes role and health questionnaire', () {
      final req = RegisterRequest(
        email: 'patient@test.com',
        password: 'Password123',
        fullName: 'Ahmed Ali',
        role: 'Patient',
        knownAllergies: ['Penicillin'],
        chronicIllnesses: ['Diabetes'],
      );

      final json = req.toJson();
      expect(json['email'], 'patient@test.com');
      expect(json['role'], 'Patient');
      expect(json['healthQuestionnaire'], isNotNull);
      expect(json['healthQuestionnaire']['knownAllergies'], ['Penicillin']);
      expect(json['pharmacy'], isNull);
    });

    test('Pharmacy registration serializes role PharmacyOwner and pharmacy payload', () {
      final req = RegisterRequest(
        email: 'pharmacist@test.com',
        password: 'Password123',
        fullName: 'Dr. Mahmoud',
        role: 'PharmacyOwner',
        pharmacy: const PharmacyRegistrationDto(
          name: 'صيدلية النور',
          addressLine: '15 شارع التحرير',
          city: 'القاهرة',
          phone: '01012345678',
          licenseDocUrl: 'LIC-998877',
        ),
      );

      final json = req.toJson();
      expect(json['email'], 'pharmacist@test.com');
      expect(json['role'], 'PharmacyOwner');
      expect(json['healthQuestionnaire'], isNull);
      expect(json['pharmacy'], isNotNull);
      expect(json['pharmacy']['name'], 'صيدلية النور');
      expect(json['pharmacy']['addressLine'], '15 شارع التحرير');
      expect(json['pharmacy']['city'], 'القاهرة');
      expect(json['pharmacy']['phone'], '01012345678');
      expect(json['pharmacy']['licenseDocUrl'], 'LIC-998877');
    });
  });
}
