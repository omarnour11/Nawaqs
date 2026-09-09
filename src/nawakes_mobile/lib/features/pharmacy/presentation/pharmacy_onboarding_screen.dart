import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart'
    show describeApiError;
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_profile_models.dart';

part 'pharmacy_onboarding_screen.g.dart';

@riverpod
Future<MyPharmacyDto?> myPharmacy(Ref ref) async {
  try {
    return await ref.read(apiClientProvider).getMyPharmacy();
  } catch (_) {
    return null;
  }
}

/// Pharmacist onboarding wizard: pharmacy profile + exact pin-dropped location.
/// Also used to edit/resubmit a rejected registration.
class PharmacyOnboardingScreen extends HookConsumerWidget {
  const PharmacyOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final nameCtrl = useTextEditingController();
    final addressCtrl = useTextEditingController();
    final cityCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();
    final licenseCtrl = useTextEditingController();
    final nationalIdCtrl = useTextEditingController();
    final submitting = useState(false);
    final existing = ref.watch(myPharmacyProvider).value;

    final marker = useState<LatLng?>(const LatLng(30.0444, 31.2357)); // Cairo default
    final mapReady = useState(false);

    // Prefill when resubmitting
    useEffect(() {
      if (existing != null) {
        nameCtrl.text = existing.name;
        addressCtrl.text = existing.addressLine;
        cityCtrl.text = existing.city;
        phoneCtrl.text = existing.phone;
        licenseCtrl.text = existing.licenseDocUrl ?? '';
        nationalIdCtrl.text = existing.nationalIdDocUrl ?? '';
        marker.value = LatLng(existing.latitude, existing.longitude);
      } else {
        // Try to start the pin at the pharmacist's current location
        () async {
          try {
            if (await Geolocator.isLocationServiceEnabled()) {
              var perm = await Geolocator.checkPermission();
              if (perm == LocationPermission.denied) {
                perm = await Geolocator.requestPermission();
              }
              if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
                final pos = await Geolocator.getCurrentPosition(
                    locationSettings:
                        const LocationSettings(timeLimit: Duration(seconds: 8)));
                marker.value = LatLng(pos.latitude, pos.longitude);
              }
            }
          } catch (_) {}
        }();
      }
      return null;
    }, [existing]);

    Future<void> submit() async {
      if (!formKey.currentState!.validate()) return;
      if (marker.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drop a pin on the map to set your location.')),
        );
        return;
      }
      submitting.value = true;
      try {
        await ref.read(apiClientProvider).registerPharmacy(RegisterPharmacyRequest(
              name: nameCtrl.text.trim(),
              addressLine: addressCtrl.text.trim(),
              city: cityCtrl.text.trim(),
              phone: phoneCtrl.text.trim(),
              latitude: marker.value!.latitude,
              longitude: marker.value!.longitude,
              licenseDocUrl: licenseCtrl.text.trim().isEmpty ? null : licenseCtrl.text.trim(),
              nationalIdDocUrl:
                  nationalIdCtrl.text.trim().isEmpty ? null : nationalIdCtrl.text.trim(),
            ));
        ref.invalidate(myPharmacyProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Submitted! Your pharmacy is pending admin review — usually within 24 hours.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      } finally {
        submitting.value = false;
      }
    }

    final isRejected = existing != null && existing.verificationStatus == 'Rejected';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Register Your Pharmacy'),
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (isRejected)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Card(
                  color: AppColors.dangerSurface,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Registration rejected: ${existing.rejectionReason ?? "no reason given"}. Update the details below and resubmit.',
                            style: const TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Text('Pharmacy details',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Pharmacy name',
                prefixIcon: Icon(Icons.local_pharmacy_rounded, size: 20),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: addressCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Address line',
                prefixIcon: Icon(Icons.home_outlined, size: 20),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cityCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city_rounded, size: 20),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
              ),
              validator: (v) =>
                  v == null || v.trim().length < 7 ? 'Enter a valid phone' : null,
            ),

            const SizedBox(height: 22),
            Text('Location — drop a pin on your exact position',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Patients search by distance, so an accurate pin matters.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: marker.value ?? const LatLng(30.0444, 31.2357),
                        zoom: 14,
                      ),
                      onTap: (pos) => marker.value = pos,
                      markers: {
                        if (marker.value != null)
                          Marker(
                            markerId: const MarkerId('pharmacy-pin'),
                            position: marker.value!,
                            draggable: true,
                            onDragEnd: (pos) => marker.value = pos,
                          ),
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      onMapCreated: (_) => mapReady.value = true,
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: FloatingActionButton.small(
                        heroTag: 'onboard_locate',
                        onPressed: () async {
                          try {
                            final pos = await Geolocator.getCurrentPosition(
                                locationSettings: const LocationSettings(
                                    timeLimit: Duration(seconds: 8)));
                            marker.value = LatLng(pos.latitude, pos.longitude);
                          } catch (_) {}
                        },
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.primary,
                        child: const Icon(Icons.my_location_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),
            Text('Verification documents',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Upload links for your Ministry of Health license and national ID. An admin reviews these before approval.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: licenseCtrl,
              decoration: const InputDecoration(
                labelText: 'MoH license document (URL)',
                prefixIcon: Icon(Icons.workspace_premium_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nationalIdCtrl,
              decoration: const InputDecoration(
                labelText: 'National ID document (URL)',
                prefixIcon: Icon(Icons.badge_outlined, size: 20),
              ),
            ),

            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: submitting.value ? null : submit,
              icon: submitting.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(existing == null
                  ? 'Submit for Verification'
                  : isRejected
                      ? 'Resubmit for Verification'
                      : 'Update & Resubmit'),
              style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md))),
            ),
          ],
        ),
      ),
    );
  }
}
