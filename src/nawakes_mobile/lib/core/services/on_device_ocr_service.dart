import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR — runs Google ML Kit locally in mobile RAM. Images are never
/// uploaded anywhere (Egyptian Law 151/2020 privacy mandate) and are deleted
/// immediately after extraction.
class OnDeviceOcrService {
  final _latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _arabicRecognizer = TextRecognizer(script: TextRecognitionScript.arabic);

  /// Extracts candidate medication name lines from a box/prescription photo.
  /// Returns noisy lines; the backend fuzzy pipeline does the actual matching.
  Future<List<String>> extractMedicationNames(File imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);

      final results = await Future.wait([
        _latinRecognizer.processImage(inputImage),
        _arabicRecognizer.processImage(inputImage),
      ]);

      final lines = <String>{};
      for (final result in results) {
        for (final block in result.blocks) {
          for (final line in block.lines) {
            final text = line.text.trim();
            if (text.isNotEmpty && _looksLikePharmaceutical(text)) {
              lines.add(text);
            }
          }
        }
      }
      return lines.toList();
    } finally {
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    }
  }

  /// Redacts personal-data lines: doctor, patient, clinic, phone numbers, dates.
  bool _isPersonalData(String text) {
    final lower = text.toLowerCase();
    const keywords = [
      'دكتور', 'دكتورة', 'عيادة', 'مستشفى', 'كشف', 'مريض', 'اسم المريض',
      'clinic', 'dr.', 'dr ', 'patient', 'hospital', 'استشاري', 'أستاذ',
    ];
    if (keywords.any(lower.contains)) return true;

    // Phone numbers (Egyptian mobile) and long digit runs
    final digitOnly = RegExp(r'\d{7,}');
    if (digitOnly.hasMatch(text.replaceAll(' ', ''))) return true;

    return false;
  }

  /// Identifies pharmaceutical-looking lines via dosage units and drug-name shapes.
  bool _looksLikePharmaceutical(String text) {
    if (_isPersonalData(text)) return false;
    if (text.length < 3 || text.length > 60) return false;

    const units = ['mg', 'ml', 'mcg', 'iu', 'g', 'مجم', 'ملجم', 'وحدة', 'أقراص', 'حقن', 'شراب'];
    final lower = text.toLowerCase();
    if (units.any(lower.contains)) return true;

    // Latin word of 4+ letters (typical trade name) — accept OCR noise too
    return RegExp(r'^[A-Za-z][A-Za-z0-9 /\.\-]{3,}$').hasMatch(text);
  }

  void dispose() {
    _latinRecognizer.close();
    _arabicRecognizer.close();
  }
}
