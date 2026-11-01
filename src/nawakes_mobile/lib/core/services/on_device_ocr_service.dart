import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR — Google ML Kit runs locally. Images are never uploaded.
class OnDeviceOcrService {
  OnDeviceOcrService();

  // Brand names on Egyptian boxes are Latin. Handwritten Arabic still yields
  // Latin fragments (Panadol, Concor) which is what the matcher needs.
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extracts candidate medication lines from a box/prescription photo.
  ///
  /// Returns an empty list only when ML Kit finds no usable text. Callers must
  /// show that to the user — swallowing it looks like "0% accuracy".
  Future<List<String>> extractMedicationNames(File imageFile) async {
    if (!await imageFile.exists()) return [];
    return extractFromFile(imageFile);
  }

  /// OCR on in-memory JPEG (e.g. cropped framing region only).
  Future<List<String>> extractFromJpegBytes(Uint8List jpegBytes) async {
    if (jpegBytes.isEmpty) return [];
    final temp = File(
      '${Directory.systemTemp.path}/nawaqs_crop_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await temp.writeAsBytes(jpegBytes, flush: true);
    try {
      return extractFromFile(temp);
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }

  Future<List<String>> extractFromFile(File imageFile) async {
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(imageFile.path),
    );
    return _linesFromResult(result);
  }

  List<String> _linesFromResult(RecognizedText result) {
    final scored = <_ScoredLine>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        for (final piece in _splitLine(line.text)) {
          if (piece.length < 2) continue;
          if (isPersonalData(piece)) continue;
          scored.add(_ScoredLine(piece, _score(piece)));
        }
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    final seen = <String>{};
    final lines = <String>[];
    for (final item in scored) {
      final key = item.text.toLowerCase();
      if (seen.add(key)) lines.add(item.text);
    }

    // If the filter was too aggressive, fall back to raw lines so a scan
    // never returns nothing when ML Kit actually read text.
    if (lines.isEmpty) {
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.length >= 2) lines.add(text);
        }
      }
    }

    return lines;
  }

  static List<String> _splitLine(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    final parts = <String>[trimmed];
    for (final part in trimmed.split(RegExp(r'[|,;•·\n]+'))) {
      final p = part.trim();
      if (p.length >= 2 && p != trimmed) parts.add(p);
    }
    return parts;
  }

  /// Doctor / clinic / phone lines. Uses word boundaries so "dr" does not
  /// wipe "hydrocortisone", "drops", or "androl".
  static bool isPersonalData(String text) {
    final lower = text.toLowerCase();

    const phrases = [
      'دكتور',
      'دكتورة',
      'عيادة',
      'مستشفى',
      'كشف',
      'مريض',
      'اسم المريض',
      'clinic',
      'doctor',
      'patient',
      'hospital',
      'استشاري',
      'أستاذ',
      'consultant',
      'specialist',
      'العنوان',
      'تليفون',
      'هاتف',
      'موبايل',
    ];
    if (phrases.any(lower.contains)) return true;

    if (RegExp(r'(^|[^a-z\u0600-\u06FF])(dr\.?|prof\.?)([^a-z\u0600-\u06FF]|$)')
        .hasMatch(lower)) {
      return true;
    }

    final digits = text.replaceAll(RegExp(r'[\s\-]'), '');
    if (RegExp(r'\d{8,}').hasMatch(digits)) return true;

    return false;
  }

  static int _score(String text) {
    var score = 0;
    if (looksLikePharmaceutical(text)) score += 5;
    if (RegExp(r'[A-Za-z]{4,}').hasMatch(text)) score += 3;
    if (RegExp(r'\d').hasMatch(text)) score += 1;
    if (text.length > 40) score -= 2;
    return score;
  }

  static bool looksLikePharmaceutical(String text) {
    if (isPersonalData(text)) return false;
    if (text.length < 3 || text.length > 80) return false;

    const units = [
      'mg',
      'ml',
      'mcg',
      'iu',
      'tab',
      'cap',
      'مجم',
      'ملجم',
      'وحدة',
      'أقراص',
      'حقن',
      'شراب',
    ];
    final lower = text.toLowerCase();
    if (units.any(lower.contains)) return true;

    return RegExp(r'[A-Za-z\u0600-\u06FF]{3,}').hasMatch(text);
  }

  Future<void> dispose() => _recognizer.close();
}

class _ScoredLine {
  const _ScoredLine(this.text, this.score);
  final String text;
  final int score;
}
