import 'package:flutter_test/flutter_test.dart';
import 'package:nawakes_mobile/core/services/on_device_ocr_service.dart';

void main() {
  test('does not treat hydrocortisone or drops as personal data', () {
    expect(OnDeviceOcrService.isPersonalData('Hydrocortisone 1%'), isFalse);
    expect(OnDeviceOcrService.isPersonalData('Panadol Extra'), isFalse);
    expect(OnDeviceOcrService.isPersonalData('Eye drops 10ml'), isFalse);
  });

  test('filters doctor and phone lines', () {
    expect(OnDeviceOcrService.isPersonalData('Dr. Ahmed Hassan'), isTrue);
    expect(OnDeviceOcrService.isPersonalData('دكتور أحمد'), isTrue);
    expect(OnDeviceOcrService.isPersonalData('01012345678'), isTrue);
  });

  test('pharmaceutical heuristic keeps brand names', () {
    expect(OnDeviceOcrService.looksLikePharmaceutical('Concor 5mg'), isTrue);
    expect(OnDeviceOcrService.looksLikePharmaceutical('Augmentin'), isTrue);
    expect(OnDeviceOcrService.looksLikePharmaceutical('Dr. Clinic'), isFalse);
  });
}
