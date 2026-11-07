import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

/// Mandatory blocking dialog that prompts the user for GPS permission.
/// Conforms to PROJECT.md interface contract:
/// - Blocking dialog (`barrierDismissible: false`).
/// - Title: "محتاجين نعرف موقعك بدقة".
/// - Body: "علشان نقدر نحدد أقرب صيدلية متوفر فيها دواك ونحسب المسافة الحقيقية ومصاريف التوصيل، التطبيق محتاج صلاحية الموقع (GPS)."
/// - Primary Action Button: Teal button labeled "سماح" that requests GPS permission.
/// - Secondary Button: Text button labeled "مش دلوقتي" that cancels and keeps search/delivery blocked.
class MandatoryLocationPromptDialog extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onCancel;

  const MandatoryLocationPromptDialog({
    super.key,
    required this.onAllow,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_on_rounded, color: NawaqsColors.teal),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'محتاجين نعرف موقعك بدقة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'علشان نقدر نحدد أقرب صيدلية متوفر فيها دواك ونحسب المسافة الحقيقية ومصاريف التوصيل، التطبيق محتاج صلاحية الموقع (GPS).',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            key: const ValueKey('location_prompt_cancel_button'),
            onPressed: onCancel,
            child: const Text(
              'مش دلوقتي',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
            ),
          ),
          ElevatedButton(
            key: const ValueKey('location_prompt_allow_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NawaqsColors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: onAllow,
            child: const Text(
              'سماح',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to ensure location permission before search or delivery flows.
/// Blocks with MandatoryLocationPromptDialog until GPS permission is granted via "سماح".
Future<bool> ensureLocationPermission(
  BuildContext context, [
  WidgetRef? ref,
]) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();
    if (serviceEnabled &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse)) {
      return true;
    }

    if (!context.mounted) return false;

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => MandatoryLocationPromptDialog(
        onAllow: () async {
          try {
            final isServiceOn = await Geolocator.isLocationServiceEnabled();
            if (!isServiceOn) {
              await Geolocator.openLocationSettings();
            }
            var perm = await Geolocator.checkPermission();
            if (perm == LocationPermission.denied) {
              perm = await Geolocator.requestPermission();
            }
            if (perm == LocationPermission.deniedForever) {
              await Geolocator.openAppSettings();
            }
            final isAllowed = perm == LocationPermission.always ||
                perm == LocationPermission.whileInUse;
            if (dialogCtx.mounted) {
              Navigator.of(dialogCtx).pop(isAllowed);
            }
          } catch (_) {
            if (dialogCtx.mounted) {
              Navigator.of(dialogCtx).pop(false);
            }
          }
        },
        onCancel: () {
          Navigator.of(dialogCtx).pop(false);
        },
      ),
    );

    return granted ?? false;
  } catch (_) {
    return false;
  }
}
