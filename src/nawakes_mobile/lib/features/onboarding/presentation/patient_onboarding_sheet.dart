import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/core/network/secure_storage_provider.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/features/search/presentation/nearby_products_provider.dart';

/// First-time onboarding & permission bottom sheet (Brand Kit Page 14)
class PatientOnboardingSheet extends ConsumerStatefulWidget {
  const PatientOnboardingSheet({super.key});

  static const _storageKey = 'nawaqss_has_seen_onboarding_v3';

  static Future<void> showIfFirstTime(BuildContext context, WidgetRef ref) async {
    try {
      final storage = ref.read(secureStorageProvider);
      final seen = await storage.read(key: _storageKey);
      if (seen == 'true') return;

      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => const PatientOnboardingSheet(),
      );
      await storage.write(key: _storageKey, value: 'true');
    } catch (_) {
      // Best-effort onboarding display
    }
  }

  @override
  ConsumerState<PatientOnboardingSheet> createState() =>
      _PatientOnboardingSheetState();
}

class _PatientOnboardingSheetState extends ConsumerState<PatientOnboardingSheet> {
  int _step = 0; // 0 = Intro, 1 = Permissions
  bool _cameraGranted = true;
  bool _locationGranted = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag handle
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: NawaqsColors.mintDeep.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),

            if (_step == 0) _buildIntroStep() else _buildPermissionsStep(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const NawaqssLogo(size: 28, showText: true),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('تخطي', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const NuqousMascot(height: 110, mood: NuqousMood.welcome),
        const SizedBox(height: 18),
        const Text(
          'صوّر الروشتة وخلاص',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: NawaqsColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'نقرأ خط الدكتور ونعرف الأدوية ونلاقيها في أقرب صيدلية.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => setState(() => _step = 1),
            style: FilledButton.styleFrom(
              backgroundColor: NawaqsColors.coral,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'التالي',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NuqousMascot(height: 80, mood: NuqousMood.searching),
        const SizedBox(height: 14),
        const Text(
          'محتاجين صلاحيتين',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: NawaqsColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        _buildPermissionItem(
          icon: Icons.camera_alt_outlined,
          title: 'الكاميرا',
          subtitle: 'عشان نصور الروشتة ونقراها بدقة',
          value: _cameraGranted,
          onChanged: (v) => setState(() => _cameraGranted = v),
        ),
        const SizedBox(height: 10),
        _buildPermissionItem(
          icon: Icons.location_on_outlined,
          title: 'الموقع (GPS)',
          subtitle: 'عشان نلاقي أقرب صيدلية عندها الأدوية',
          value: _locationGranted,
          onChanged: (v) => setState(() => _locationGranted = v),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () async {
              if (_cameraGranted) {
                try {
                  await Permission.camera.request();
                } catch (_) {}
              }
              if (_locationGranted) {
                try {
                  final perm = await Geolocator.requestPermission();
                  if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
                    final locService = ref.read(locationServiceProvider);
                    final pos = await locService.getCurrentPosition();
                    if (pos != null) {
                      final addr = await locService.getDetailedEgyptianAddress(pos.latitude, pos.longitude);
                      final gov = LocationService.detectGovernorate(pos.latitude, pos.longitude);
                      ref.read(deliveryLocationProvider.notifier).setLocation(
                        DeliveryLocation(
                          label: addr ?? 'موقعي الحالي',
                          latitude: pos.latitude,
                          longitude: pos.longitude,
                          governorate: gov,
                        ),
                      );
                    }
                  }
                } catch (_) {}
              }
              if (mounted) Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: NawaqsColors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'اسمح بالصلاحيات',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'مش دلوقتي',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NawaqsColors.mint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: NawaqsColors.tealDark, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: NawaqsColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: NawaqsColors.teal,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

