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

    Future<bool> ensureLocationServiceEnabled() async {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.location_off_rounded, color: AppColors.dangerIcon, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تفعيل الـ GPS إجباري',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'لتعديل أو تحديد موقع الصيدلية، يلزم تفعيل خدمة الموقع (GPS) بهاتفك أولاً لضمان دقة إحداثيات الصيدلية على الخريطة وظهورها للمرضى في نطاقها الفعلي.',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: NawaqsColors.tealDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop(true);
                    await Geolocator.openLocationSettings();
                  },
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text(
                    'فتح إعدادات الموقع الآن',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          );
        }
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('إذن الموقع مطلوب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              content: const Text(
                'تم حظر إذن الوصول للموقع. يرجى تفعيله من إعدادات الهاتف لتحديد إحداثيات الصيدلية.',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Geolocator.openAppSettings();
                  },
                  child: const Text('فتح الإعدادات', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          );
        }
        return false;
      }
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    }

    Future<void> locateCurrentPosition({bool showFeedback = false}) async {
      final ready = await ensureLocationServiceEnabled();
      if (!ready) return;

      isLocating.value = true;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        final target = LatLng(pos.latitude, pos.longitude);
        marker.value = target;
        locationConfirmed.value = true;
        try {
          mapController.move(target, 16);
        } catch (_) {}
        await reverseGeocode(target);

        if (showFeedback && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديد موقع الصيدلية وعنوانها من موقعك الحالي بنجاح 📍')),
          );
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
      backgroundColor: NawaqsColors.cream,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تسجيل بيانات الصيدلية',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: NawaqsColors.tealDark,
              ),
            ),
            Text(
              'بيانات المنشأة والموقع الجغرافي الدقيق والتراخيص',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        backgroundColor: NawaqsColors.cream,
        foregroundColor: NawaqsColors.tealDark,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          cacheExtent: 3000,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
          children: [
            if (isRejected)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'تم رفض التسجيل: ${existing.rejectionReason ?? "لم يُحدد سبب"}. يُرجى مراجعة وتحديث البيانات أدناه ثم إعادة الإرسال.',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, height: 1.4, color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),

            if (isApproved)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accentBlueBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: AppColors.accentBlue, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'صيدليتك معتمدة حالياً. في حال قمت بتعديل الاسم أو الموقع أو مستندات التراخيص، ستعود الصيدلية للمراجعة لضمان السلامة الدوائية.',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12, height: 1.4, color: AppColors.accentBlue),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Section 1: Basic Information ─────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NawaqsColors.mintDeep),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_pharmacy_rounded, color: NawaqsColors.tealDark, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'بيانات الصيدلية',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w800, color: NawaqsColors.tealDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'اسم الصيدلية',
                      hintText: 'مثال: صيدلية الأمل، صيدليات العزبي',
                      prefixIcon: Icon(Icons.storefront_rounded, size: 20),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'اسم الصيدلية مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText: 'مثال: 01012345678 أو 0233445566',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'رقم الهاتف مطلوب';
                      final digits = v.trim().replaceAll(RegExp(r'\s+'), '');
                      if (!RegExp(r'^(01[0125][0-9]{8}|0[2-9][0-9]{7,8})$').hasMatch(digits)) {
                        return 'يرجى إدخال رقم هاتف محمول (11 رقم) أو أرضي مصري صحيح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'المدينة / المحافظة',
                            hintText: 'مثال: القاهرة، الجيزة',
                            prefixIcon: Icon(Icons.location_city_rounded, size: 20),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'المدينة مطلوبة' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'العنوان بالتفصيل',
                      hintText: 'الشارع، رقم العقار، أقرب معلم شهير',
                      prefixIcon: Icon(Icons.home_outlined, size: 20),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null,
                  ),
                ],
              ),
            ),

            // ── Section 2: Precise Geolocation & Map ──────────────────
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NawaqsColors.mintDeep),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pin_drop_rounded, color: NawaqsColors.tealDark, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الموقع — حدد موقع الصيدلية بدقة على الخريطة',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w800, color: NawaqsColors.tealDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'تحديد موقع الصيدلية الجغرافي بدقة يضمن وصول المرضى الأقرب إليك وصرف الروشتات الفورية.',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // ── PROMINENT ONE-TAP GPS BUTTON ───────────────────
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: isLocating.value ? null : () => locateCurrentPosition(showFeedback: true),
                        child: Center(
                          child: isLocating.value
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'جاري سحب موقعك الجغرافي بدقة...',
                                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '📍 استخدام موقع الصيدلية الحالي (GPS)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),

                  if (marker.value != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.successIcon.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.successIcon, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تم تثبيت الإحداثيات: ${marker.value!.latitude.toStringAsFixed(4)}، ${marker.value!.longitude.toStringAsFixed(4)} (يمكنك السحب أو النقر على الخريطة لتعديل الدبوس بدقة).',
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.successText, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Localized search input
                  TextField(
                    controller: searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: searchLocation,
                    decoration: InputDecoration(
                      hintText: 'أو ابحث باسم الشارع أو المعلم الشهير في منطقتك…',
                      hintStyle: const TextStyle(fontSize: 12),
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
                            onTap: () async {
                              if (lat != null && lon != null) {
                                final ready = await ensureLocationServiceEnabled();
                                if (!ready) return;
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

                  const SizedBox(height: 12),

                  // Map Container
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 240,
                      child: Stack(
                        children: [
                          NawaqsMap(
                            controller: mapController,
                            center: marker.value ?? const LatLng(30.0444, 31.2357),
                            zoom: 15,
                            onTap: (_, pos) async {
                              final ready = await ensureLocationServiceEnabled();
                              if (!ready) return;
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
                              backgroundColor: Colors.white,
                              foregroundColor: NawaqsColors.tealDark,
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
                ],
              ),
            ),

            // ── Section 3: Official Verification Documents ────────────
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NawaqsColors.mintDeep),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: NawaqsColors.tealDark, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'مستندات التحقق والتراخيص',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w800, color: NawaqsColors.tealDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ارفع صور واضحة لمستندات الصيدلية الرسمية لاعتماد حسابك والبدء في تلقي طلبات النواقص.',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // Document 1: Ministry of Health License
                  _DocUploadCard(
                    title: 'ترخيص مزاولة المهنة / ترخيص وزارة الصحة',
                    subtitle: 'صورة واضحة لترخيص الصيدلية الرسمي الصادر من وزارة الصحة',
                    icon: Icons.workspace_premium_outlined,
                    url: licenseDocUrl.value,
                    isUploading: isUploadingLicense.value,
                    onPick: () => uploadDocument(true),
                    onRemove: () => licenseDocUrl.value = null,
                  ),
                  const SizedBox(height: 12),

                  // Document 2: National ID
                  _DocUploadCard(
                    title: 'بطاقة الرقم القومي للصيدلي المسؤول / السجل التجاري',
                    subtitle: 'صورة واضحة للوجهين أو صورة السجل التجاري الساري',
                    icon: Icons.badge_outlined,
                    url: nationalIdDocUrl.value,
                    isUploading: isUploadingNationalId.value,
                    onPick: () => uploadDocument(false),
                    onRemove: () => nationalIdDocUrl.value = null,
                  ),
                ],
              ),
            ),

            // ── Submit Button ─────────────────────────────────────────
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: submitting.value ? null : submit,
                icon: submitting.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  existing == null
                      ? 'إرسال بيانات الصيدلية للمراجعة والاعتماد'
                      : isRejected
                          ? 'إعادة إرسال البيانات للتحقق'
                          : 'تحديث البيانات وإعادة الإرسال',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: NawaqsColors.tealDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
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

  void _previewImage(BuildContext context, String fullUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      fullUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('تعذر تحميل الصورة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = url != null && url!.isNotEmpty;
    final fullUrl = hasFile
        ? (url!.startsWith('http')
            ? url!
            : '${AppConfig.apiBaseUrl.replaceAll('/api/v1', '')}$url')
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasFile ? AppColors.successBg.withValues(alpha: 0.5) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
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
                  color: hasFile ? AppColors.successBg : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: hasFile ? AppColors.successText : AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasFile && fullUrl != null) ...[
            Row(
              children: [
                GestureDetector(
                  onTap: () => _previewImage(context, fullUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      fullUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => const ContainerFallback(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 16, color: AppColors.successText),
                          SizedBox(width: 4),
                          Text(
                            'تم رفع المستند بنجاح',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.successText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _previewImage(context, fullUrl),
                        child: const Text(
                          'اضغط للمعاينة بالتكبير 🔍',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: NawaqsColors.tealDark, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.dangerText),
                  tooltip: 'حذف',
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
              label: Text(
                isUploading ? 'جاري رفع المستند...' : 'رفع صورة المستند من الهاتف',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ContainerFallback extends StatelessWidget {
  const ContainerFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      color: Colors.grey.shade200,
      child: const Icon(Icons.description_outlined, size: 26, color: Colors.grey),
    );
  }
}
