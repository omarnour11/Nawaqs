import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/profile/data/medication_models.dart';

/// استغاثة نواقص — patient broadcasts a live request to nearby pharmacies
/// when the search returns nothing. First pharmacy to claim creates the pass.
class ShortageSosCard extends HookConsumerWidget {
  final String medicationName;

  const ShortageSosCard({super.key, required this.medicationName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState(false);
    final sent = useState(false);

    Future<void> broadcast() async {
      final messenger = ScaffoldMessenger.of(context);
      final client = ProviderScope.containerOf(context).read(apiClientProvider);
      if (medicationName.length < 2) {
        messenger.showSnackBar(
          const SnackBar(content: Text('اكتب اسم الدواء الأول في البحث.')),
        );
        return;
      }
      busy.value = true;
      try {
        double lat = 30.0444, lng = 31.2357;
        try {
          if (await Geolocator.isLocationServiceEnabled()) {
            var perm = await Geolocator.checkPermission();
            if (perm == LocationPermission.denied) {
              perm = await Geolocator.requestPermission();
            }
            if (perm == LocationPermission.always ||
                perm == LocationPermission.whileInUse) {
              final pos = await Geolocator.getCurrentPosition(
                  locationSettings:
                      const LocationSettings(timeLimit: Duration(seconds: 8)));
              lat = pos.latitude;
              lng = pos.longitude;
            }
          }
        } catch (_) {}

        await client
            .createShortageRequest(CreateShortageRequest(
              medicationName: medicationName,
              quantityNeeded: 1,
              latitude: lat,
              longitude: lng,
            ));
        sent.value = true;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      } finally {

        busy.value = false;
      }
    }

    if (sent.value) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: AppColors.successText, size: 19),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'استغاثتك اتبعتت للصيدليات الحوالينك — أول صيدلية عندها توفر هتحجزلك وتبعتلك تصريح.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.campaign_outlined,
                  color: AppColors.warningText, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('مش لاقي الدواء؟',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warningText)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'ابعت استغاثة لكل الصيدليات حوالينك — أول واحدة عندها توفر هتحجزلك فورًا.',
            style: TextStyle(fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy.value ? null : broadcast,
              icon: busy.value
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text('ابعت استغاثة نواقص'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warningText,
                side: const BorderSide(color: AppColors.warningIcon, width: 1.3),
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
