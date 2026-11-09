import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the base64-encoded sanitized prescription crop from the latest prescription scan.
/// Attached to reservations & orders so the pharmacist can review it for clinical safety.
final activePrescriptionCropBase64Provider = StateProvider<String?>((ref) => null);

