import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:nawakes_mobile/core/config.dart';
import 'package:nawakes_mobile/core/map/nawaqs_map.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nawakes_mobile/core/services/image_picker_service.dart';
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
/// Also used to edit/resubmit a rejected or approved registration.
class PharmacyOnboardingScreen extends HookConsumerWidget {
  const PharmacyOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final mapController = useMemoized(() => MapController());
    final nameCtrl = useTextEditingController();
    final addressCtrl = useTextEditingController();
    final cityCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();
    final searchCtrl = useTextEditingController();

    final licenseDocUrl = useState<String?>(null);
    final nationalIdDocUrl = useState<String?>(null);
    final isUploadingLicense = useState(false);
    final isUploadingNationalId = useState(false);

    final submitting = useState(false);
    final isLocating = useState(false);
    final isSearchingLocation = useState(false);
    final searchResults = useState<List<Map<String, dynamic>>>([]);
    final locationConfirmed = useState(false);

    final existing = ref.watch(myPharmacyProvider).value;
    final marker = useState<LatLng?>(null);

    Future<void> reverseGeocode(LatLng pos) async {
      try {
        final dio = Dio();
        final url =
            'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json&accept-language=ar';
        final resp = await dio.get(
          url,
          options: Options(headers: {'User-Agent': 'NawaqsEgypt/1.0'}),
        );
        if (resp.data is Map<String, dynamic>) {
          final data = resp.data as Map<String, dynamic>;
          final displayName = data['display_name'] as String? ?? '';
          final addr = data['address'] as Map<String, dynamic>?;
          if (displayName.isNotEmpty) {
            final parts = displayName.split(',');
            addressCtrl.text = parts.take(3).join('، ').trim();
            if (nameCtrl.text.trim().isEmpty && parts.isNotEmpty) {
              final first = parts.first.trim();
              if (first.contains('صيدلية') || first.toLowerCase().contains('pharmacy')) {
                nameCtrl.text = first;
              }
            }
          }
          if (addr != null) {
            final city = addr['city'] ?? addr['state'] ?? addr['governorate'] ?? addr['town'] ?? addr['suburb'];
            if (city != null) cityCtrl.text = city.toString();
          }
        }
      } catch (_) {}
    }

    Future<void> locateCurrentPosition({bool showFeedback = false}) async {
      isLocating.value = true;
      try {
        final locService = ref.read(locationServiceProvider);
        final pos = await locService.getCurrentLocation();
        if (pos != null) {
          final target = LatLng(pos.latitude, pos.longitude);
          marker.value = target;
          locationConfirmed.value = false;
          try {
            mapController.move(target, 15);
          } catch (_) {}
          if (addressCtrl.text.trim().isEmpty) {
            reverseGeocode(target);
          }

          if (showFeedback && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تحديد موقع الصيدلية من موقعك الحالي')),
            );
          }
        }
      } catch (e) {
        if (showFeedback && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تعذر جلب موقعك الحالي — يرجى تفعيل الـ GPS والضغط مجدداً'),
              action: SnackBarAction(
                label: 'الإعدادات',
                textColor: Colors.white,
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
      } finally {
        isLocating.value = false;
      }
    }

    Future<void> searchLocation(String query) async {
      if (query.trim().isEmpty) return;
      isSearchingLocation.value = true;
      try {
        final center = marker.value ?? const LatLng(30.0444, 31.2357);
        final minLon = center.longitude - 0.35;
        final maxLon = center.longitude + 0.35;
        final minLat = center.latitude - 0.35;
        final maxLat = center.latitude + 0.35;

        final dio = Dio();
        final url =
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&countrycodes=eg&limit=6&viewbox=$minLon,$maxLat,$maxLon,$minLat';
        var resp = await dio.get(
          url,
          options: Options(headers: {'User-Agent': 'NawaqsEgypt/1.0'}),
        );
        List<Map<String, dynamic>> res = [];
        if (resp.data is List && (resp.data as List).isNotEmpty) {
          res = (resp.data as List).cast<Map<String, dynamic>>();
        } else {
          final fallbackUrl =
              'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&countrycodes=eg&limit=6';
          final fallbackResp = await dio.get(
            fallbackUrl,
            options: Options(headers: {'User-Agent': 'NawaqsEgypt/1.0'}),
          );
          if (fallbackResp.data is List) {
            res = (fallbackResp.data as List).cast<Map<String, dynamic>>();
          }
        }
        searchResults.value = res;
      } catch (_) {
        searchResults.value = [];
      } finally {
        isSearchingLocation.value = false;
      }
    }

    Future<void> uploadDocument(bool isLicense) async {
      final picker = ref.read(imagePickerServiceProvider);
      final file = await picker.pickFromGallery(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
      if (file == null) return;

      if (isLicense) {
        isUploadingLicense.value = true;
      } else {
        isUploadingNationalId.value = true;
      }

      try {
        final url = await ref.read(apiClientProvider).uploadFilePath(file.path);
        if (isLicense) {
          licenseDocUrl.value = url;
        } else {
          nationalIdDocUrl.value = url;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isLicense
                  ? 'تم رفع ترخيص وزارة الصحة بنجاح.'
                  : 'تم رفع بطاقة الرقم القومي بنجاح.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الرفع: ${describeApiError(e)}')),
          );
        }
      } finally {
        if (isLicense) {
          isUploadingLicense.value = false;
        } else {
          isUploadingNationalId.value = false;
        }
      }
    }

    // Prefill when resubmitting or editing
    useEffect(() {
      final isNewOrPlaceholder = existing == null ||
          ((existing.latitude - 30.0444).abs() < 0.001 &&
              (existing.longitude - 31.2357).abs() < 0.001);

      if (existing != null) {
        nameCtrl.text = existing.name;
        addressCtrl.text = existing.addressLine;
        cityCtrl.text = existing.city;
        phoneCtrl.text = existing.phone;
        licenseDocUrl.value = existing.licenseDocUrl;
        nationalIdDocUrl.value = existing.nationalIdDocUrl;

        if (!isNewOrPlaceholder) {
          final savedPos = LatLng(existing.latitude, existing.longitude);
          marker.value = savedPos;
          locationConfirmed.value = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              mapController.move(savedPos, 15);
            } catch (_) {}
          });
          return null;
        }
      }

      locateCurrentPosition();
      return null;
    }, [existing]);

    Future<void> submit() async {
      if (!formKey.currentState!.validate()) return;
      if (marker.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تحديد موقع الصيدلية على الخريطة')),
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
              licenseDocUrl: licenseDocUrl.value,
              nationalIdDocUrl: nationalIdDocUrl.value,
            ));
        ref.invalidate(myPharmacyProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'تم إرسال الطلب بنجاح! صيدليتك قيد مراجعة الإدارة (خلال 24 ساعة عادة).')),
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
    final isApproved = existing != null && existing.verificationStatus == 'Approved';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تسجيل بيانات الصيدلية'),
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          cacheExtent: 3000,
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
                            'تم رفض التسجيل: ${existing.rejectionReason ?? "لم يُحدد سبب"}. يُرجى تحديث البيانات أدناه ثم إعادة الإرسال.',
                            style: const TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (isApproved)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Card(
                  color: AppColors.accentBlueBg,
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.accentBlue, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'تنبيه: تعديل اسم الصيدلية، الموقع الجغرافي، أو مستندات التراخيص سيعيد الصيدلية إلى مرحلة المراجعة والاعتماد تلقائياً لضمان موثوقية المنصة.',
                            style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.accentBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Text('بيانات الصيدلية',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'اسم الصيدلية',
                prefixIcon: Icon(Icons.local_pharmacy_rounded, size: 20),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: addressCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'العنوان بالتفصيل',
                prefixIcon: Icon(Icons.home_outlined, size: 20),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cityCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'المدينة / المحافظة',
                prefixIcon: Icon(Icons.location_city_rounded, size: 20),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
              ),
              validator: (v) =>
                  v == null || v.trim().length < 7 ? 'يرجى إدخال رقم هاتف صحيح' : null,
            ),

            const SizedBox(height: 24),
            Text('الموقع — حدد موقع الصيدلية بدقة على الخريطة',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'نسحب موقعك الحالي تلقائياً. يمكنك تأكيد الدقة أو البحث بالاسم والشارع لضبط الدبوس بدقة.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),

            // ── GPS Prompt / Confirmation Banner ───────────────────────
            if (isLocating.value)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'جاري فتح الـ GPS وسحب موقع الصيدلية الجغرافي…',
                        style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else if (marker.value != null && !locationConfirmed.value)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_searching_rounded, size: 18, color: Color(0xFFE65100)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تم سحب موقعك الحالي (${marker.value!.latitude.toStringAsFixed(4)}, ${marker.value!.longitude.toStringAsFixed(4)}): هل هذا موقع صيدليتك بدقة؟',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFE65100)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => locationConfirmed.value = true,
                            icon: const Icon(Icons.check_rounded, size: 15),
                            label: const Text('نعم، دقيق تماماً', style: TextStyle(fontSize: 12)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.successText,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => locationConfirmed.value = false,
                            icon: const Icon(Icons.search_rounded, size: 15),
                            label: const Text('ابحث بالاسم', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else if (marker.value != null && locationConfirmed.value)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: AppColors.successIcon),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'موقع الصيدلية مؤكد ومضبوط بدقة. يمكنك السحب على الخريطة لتعديل الدبوس عند الحاجة.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.successText, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Localized Pharmacy Search Bar ──────────────────────────
            TextField(
              controller: searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: searchLocation,
              decoration: InputDecoration(
                hintText: 'ابحث باسم صيدليتك أو فرعك في منطقتك (مثال: العزبي، رشدي)…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: isSearchingLocation.value
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        onPressed: () => searchLocation(searchCtrl.text),
                      ),
              ),
            ),

            if (searchResults.value.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: searchResults.value.map((res) {
                    final displayName = res['display_name'] as String? ?? '';
                    final lat = double.tryParse(res['lat']?.toString() ?? '');
                    final lon = double.tryParse(res['lon']?.toString() ?? '');
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                      title: Text(displayName, maxLines: 2, style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        if (lat != null && lon != null) {
                          final newPos = LatLng(lat, lon);
                          marker.value = newPos;
                          mapController.move(newPos, 16);
                          locationConfirmed.value = true;
                          searchResults.value = [];
                          final parts = displayName.split(',');
                          if (parts.isNotEmpty) {
                            if (nameCtrl.text.trim().isEmpty) {
                              nameCtrl.text = parts.first.trim();
                            }
                            addressCtrl.text = parts.take(3).join('، ').trim();
                          }
                          final addr = res['address'] as Map<String, dynamic>?;
                          final city = addr?['city'] ?? addr?['state'] ?? addr?['governorate'] ?? addr?['town'];
                          if (city != null) cityCtrl.text = city.toString();
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Interactive Map ────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    NawaqsMap(
                      controller: mapController,
                      center: marker.value ?? const LatLng(30.0444, 31.2357),
                      zoom: 15,
                      onTap: (_, pos) {
                        marker.value = pos;
                        locationConfirmed.value = true;
                        reverseGeocode(pos);
                      },
                      pins: [
                        if (marker.value != null)
                          NawaqsMapPin(
                            id: 'pharmacy-pin',
                            point: marker.value!,
                            label: 'ص',
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: FloatingActionButton.small(
                        heroTag: 'onboard_locate',
                        onPressed: isLocating.value
                            ? null
                            : () => locateCurrentPosition(showFeedback: true),
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.primary,
                        child: isLocating.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text('مستندات التحقق والتراخيص',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'ارفع صور واضحة لترخيص وزارة الصحة وبطاقة الرقم القومي لمالك الصيدلية لاعتماد حسابك.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),

            // ── Document 1: Ministry of Health License ─────────────────
            _DocUploadCard(
              title: 'ترخيص مزاولة المهنة / ترخيص وزارة الصحة',
              subtitle: 'صورة واضحة لترخيص الصيدلية الصادر من وزارة الصحة',
              icon: Icons.workspace_premium_outlined,
              url: licenseDocUrl.value,
              isUploading: isUploadingLicense.value,
              onPick: () => uploadDocument(true),
              onRemove: () => licenseDocUrl.value = null,
            ),
            const SizedBox(height: 12),

            // ── Document 2: National ID ────────────────────────────────
            _DocUploadCard(
              title: 'بطاقة الرقم القومي لصاحب الصيدلية / السجل التجاري',
              subtitle: 'صورة واضحة للوجهين أو السجل التجاري الرسمي',
              icon: Icons.badge_outlined,
              url: nationalIdDocUrl.value,
              isUploading: isUploadingNationalId.value,
              onPick: () => uploadDocument(false),
              onRemove: () => nationalIdDocUrl.value = null,
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
                  ? 'إرسال للتحقق والاعتماد'
                  : isRejected
                      ? 'إعادة إرسال للتحقق'
                      : 'تحديث البيانات وإعادة الإرسال'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md))),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocUploadCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? url;
  final bool isUploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _DocUploadCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.url,
    required this.isUploading,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = url != null && url!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasFile ? AppColors.successBg : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: hasFile ? AppColors.successIcon.withValues(alpha: 0.5) : AppColors.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: hasFile ? Colors.white : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: hasFile ? AppColors.successText : AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasFile) ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    url!.startsWith('http')
                        ? url!
                        : '${AppConfig.apiBaseUrl.replaceAll('/api/v1', '')}$url',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => const Icon(Icons.description_outlined, size: 30),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: AppColors.successText),
                      SizedBox(width: 4),
                      Text('تم رفع المستند بنجاح',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.successText)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.dangerText),
                  label: const Text('حذف', style: TextStyle(color: AppColors.dangerText, fontSize: 12)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: isUploading ? null : onPick,
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(isUploading ? 'جاري رفع المستند…' : 'رفع صورة المستند من الجهاز'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
