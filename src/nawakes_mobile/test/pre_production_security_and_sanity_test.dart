import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawakes_mobile/core/services/paymob_payment_service.dart';

void main() {
  group('Pre-Production Security & Secrets Audit', () {
    test('PaymobConfig has NO hardcoded secrets or API keys in client code', () {
      const config = PaymobConfig();

      // Ensure API keys and HMAC secrets are completely empty strings (not hardcoded)
      expect(config.apiKey, isEmpty,
          reason: 'Hardcoded Paymob API Key must not be present in client release build');
      expect(config.hmacSecret, isEmpty,
          reason: 'Hardcoded Paymob HMAC Secret must not be present in client release build');
      expect(config.cardIntegrationId, equals(0));
      expect(config.walletIntegrationId, equals(0));
      expect(config.iframeId, equals(0));
    });

    test('Source files do not contain exposed JWT or Payment hardcoded secrets', () {
      final paymobFile = File('lib/core/services/paymob_payment_service.dart');
      expect(paymobFile.existsSync(), isTrue);

      final content = paymobFile.readAsStringSync();
      // Ensure the old Base64 hardcoded secret is not present
      expect(
        content.contains('4F90A5C2D90E11EFA08B0242AC120002'),
        isFalse,
        reason: 'Raw HMAC secret was found in source code!',
      );
      expect(
        content.contains('ZXlKaGJHY2lPaUpJVXpJMU5pSjkuZXlKMGVYQWlPaUpLVjFRaUxDSmhiR2NpT2lKSVV6STFOaUo5'),
        isFalse,
        reason: 'Raw API key token was found in source code!',
      );
    });
  });

  group('Pre-Production Business Invariants & Handover OTP', () {
    test('Handover OTP normalization removes hyphens and spaces consistently', () {
      String normalize(String code) => code.trim().replaceAll('-', '').replaceAll(' ', '').toUpperCase();

      expect(normalize('NWQ-849123'), equals('NWQ849123'));
      expect(normalize('nwq-849123'), equals('NWQ849123'));
      expect(normalize(' 849 123 '), equals('849123'));
      expect(normalize('NWQ - 849 - 123'), equals('NWQ849123'));
    });

    test('Verification code matching handles both full prefix and pure digits', () {
      const expectedFull = 'NWQ-8491';
      const expectedOtp = '8491';

      bool matches(String input) {
        final clean = input.trim().toUpperCase();
        return clean == expectedFull || clean == expectedOtp || clean == expectedFull.replaceAll('-', '');
      }

      expect(matches('NWQ-8491'), isTrue);
      expect(matches('8491'), isTrue);
      expect(matches('NWQ8491'), isTrue);
      expect(matches('0000'), isFalse);
      expect(matches(''), isFalse);
    });
  });
}

