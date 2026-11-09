import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the base64-encoded sanitized prescription crop from the latest prescription scan.
/// Attached to reservations & orders so the pharmacist can review it for clinical safety.
class ActivePrescriptionCropNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setCrop(String? crop) => state = crop;
  void clear() => state = null;
}

final activePrescriptionCropBase64Provider =
    NotifierProvider<ActivePrescriptionCropNotifier, String?>(
  ActivePrescriptionCropNotifier.new,
);
