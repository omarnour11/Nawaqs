import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/location/location_service.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/services/payment_methods_service.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:url_launcher/url_launcher.dart';

class DeliveryDetailsSheet extends HookConsumerWidget {
  final String inventoryItemId;
  final String pharmacyName;
  final String pharmacyPhone;
  final String medicationName;
  final double medicationPrice;
  final double distanceKm;
  final double? latitude;
  final double? longitude;

  const DeliveryDetailsSheet({
    super.key,
    required this.inventoryItemId,
    required this.pharmacyName,
    this.pharmacyPhone = '01000000000',
    required this.medicationName,
    required this.medicationPrice,
    required this.distanceKm,
    this.latitude,
    this.longitude,
  });

  static Future<ReservationResponse?> show(
    BuildContext context, {
    required String inventoryItemId,
    required String pharmacyName,
    String pharmacyPhone = '01000000000',
    required String medicationName,
    required double medicationPrice,
    required double distanceKm,
    double? latitude,
    double? longitude,
  }) {
    return showModalBottomSheet<ReservationResponse>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeliveryDetailsSheet(
        inventoryItemId: inventoryItemId,
        pharmacyName: pharmacyName,
        pharmacyPhone: pharmacyPhone,
        medicationName: medicationName,
        medicationPrice: medicationPrice,
        distanceKm: distanceKm,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streetCtrl = useTextEditingController();
    final buildingCtrl = useTextEditingController();
    final aptCtrl = useTextEditingController();
    final landmarkCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();

    final currentLat = useState<double?>(latitude);
    final currentLng = useState<double?>(longitude);
    final isLocating = useState<bool>(false);
    final isSubmitting = useState<bool>(false);

    // Auto-fetch precise location & address on open
    useEffect(() {
      Future(() async {
        isLocating.value = true;
        try {
          final locService = ref.read(locationServiceProvider);
          double? lat = currentLat.value;
          double? lng = currentLng.value;

          if (lat == null || lng == null) {
            final pos = await locService.getCurrentPosition();
            if (pos != null) {
              lat = pos.latitude;
              lng = pos.longitude;
              currentLat.value = lat;
              currentLng.value = lng;
            }
          }

          if (lat != null && lng != null && streetCtrl.text.isEmpty) {
            final detailed = await locService.getDetailedEgyptianAddress(lat, lng);
            if (detailed != null && detailed.isNotEmpty) {
              streetCtrl.text = detailed;
            }
          }
        } catch (_) {
        } finally {
          isLocating.value = false;
        }
      });
      return null;
    }, const []);

    // Calculate Egyptian delivery fee (15 EGP base + 4 EGP per extra km)
    final deliveryFee = distanceKm <= 2.0
        ? 15.0
        : (15.0 + ((distanceKm - 2.0) * 4.0)).roundToDouble();
    final grandTotal = medicationPrice + deliveryFee;

    // Calculate motorcycle delivery ETA (~25 km/h + 12m prep)
    final etaMin = (12 + (distanceKm / 25.0 * 60.0)).round();
    final etaMax = etaMin + 12;

    // Driver Courier contact phone
    final courierPhone = pharmacyPhone.isNotEmpty && pharmacyPhone != '—'
        ? pharmacyPhone
        : '01029834112';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        top: 12,
        left: 20,
        right: 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NawaqsColors.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delivery_dining_rounded, color: NawaqsColors.tealDark, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'طلب توصيل منزلي فوري 🛵',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: NawaqsColors.ink,
                      ),
                    ),
                    Text(
                      pharmacyName,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Courier & ETA Banner (Motorcycle Delivery & Click-to-Call) ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.two_wheeler_rounded, color: Color(0xFF15803D), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'توصيل سريع بطيار موتوسيكل: $etaMin - $etaMax دقيقة',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse('tel:$courierPhone');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF15803D), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'اتصال مباشر بالطيار: $courierPhone 📞',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Address Fields (Mandatory Egyptian Address: Street, Building, Apt) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'تفاصيل عنوان التوصيل الإلزامية',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: NawaqsColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: isLocating.value
                    ? null
                    : () async {
                        isLocating.value = true;
                        try {
                          final locService = ref.read(locationServiceProvider);
                          final pos = await locService.getCurrentPosition();
                          if (pos != null) {
                            currentLat.value = pos.latitude;
                            currentLng.value = pos.longitude;
                            final detailed = await locService.getDetailedEgyptianAddress(pos.latitude, pos.longitude);
                            if (detailed != null && detailed.isNotEmpty) {
                              streetCtrl.text = detailed;
                            }
                          }
                        } catch (_) {
                        } finally {
                          isLocating.value = false;
                        }
                      },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLocating.value)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: NawaqsColors.tealDark),
                        )
                      else
                        const Icon(Icons.my_location_rounded, size: 15, color: NawaqsColors.tealDark),
                      const SizedBox(width: 4),
                      Text(
                        isLocating.value ? 'جارٍ تحديد موقعك…' : 'تحديد موقعي الدقيق 📍',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: NawaqsColors.tealDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          TextField(
            controller: streetCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم الشارع والحي والمركز (إجباري) *',
              hintText: 'مثال: شارع أحمد خضر، كفر منصور، مركز طوخ، القليوبية',
              prefixIcon: Icon(Icons.edit_road_rounded, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: buildingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم أو اسم العمارة (إجباري) *',
                    hintText: 'مثال: عمارة 14',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: aptCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم الشقة والدور (إجباري) *',
                    hintText: 'مثال: شقة 3، الدور 2',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          TextField(
            controller: landmarkCtrl,
            decoration: const InputDecoration(
              labelText: 'علامة مميزة (اختياري)',
              hintText: 'مثال: بجوار صيدلية أو أمام مسجد السلام',
              prefixIcon: Icon(Icons.pin_drop_outlined, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الموبايل للتواصل والتأكيد (إجباري) *',
              hintText: '010XXXXXXXX (11 رقم)',
              prefixIcon: Icon(Icons.phone_android_rounded, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 18),

          // ── Payment Method Section (Cash Only) ──
          Row(
            children: [
              const Text(
                'طريقة الدفع الرسمية',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: NawaqsColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'كاش عند الاستلام 💵',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.payments_rounded, color: Color(0xFF15803D), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'الدفع نقدًا لمندوب التوصيل (الطيار)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF166534),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'تسليم قيمة الدواء ومصاريف التوصيل نقداً عند استلام الشحنة أمام باب المنزل.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 20),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Note about online payment maintenance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'خدمات الدفع الإلكتروني (فيزا، فودافون كاش، إنستاباي) قيد الصيانة والربط البنكي الرسمي.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Order Cost Breakdown ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('سعر الدواء ($medicationName):', style: const TextStyle(fontSize: 12.5)),
                    Text('${medicationPrice.toStringAsFixed(1)} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('مصاريف التوصيل (${distanceKm.toStringAsFixed(1)} كم):',
                        style: const TextStyle(fontSize: 12.5)),
                    Text('${deliveryFee.toStringAsFixed(1)} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الإجمالي المطلوب نقدًا (كاش):',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      '${grandTotal.toStringAsFixed(1)} ج.م',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: NawaqsColors.tealDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Submit Order Button ──
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: NawaqsColors.tealDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: isSubmitting.value
                ? null
                : () async {
                    if (streetCtrl.text.trim().isEmpty ||
                        buildingCtrl.text.trim().isEmpty ||
                        aptCtrl.text.trim().isEmpty ||
                        phoneCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('برجاء كتابة تفاصيل العنوان بالكامل: الشارع، العمارة، رقم الشقة والدور، والموبايل'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    if (!EgyptianWalletValidator.isValidMobileNumber(phoneCtrl.text.trim())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('رقم الموبايل غير صالح. يرجى إدخال 11 رقماً تبدأ بـ 010 أو 011 أو 012 أو 015'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    isSubmitting.value = true;
                    try {
                      final fullAddress =
                          '${streetCtrl.text.trim()}، عمارة ${buildingCtrl.text.trim()}، شقة ${aptCtrl.text.trim()}${landmarkCtrl.text.trim().isNotEmpty ? " (علامة: ${landmarkCtrl.text.trim()})" : ""}';

                      final effectiveLat = currentLat.value ?? 30.0444;
                      final effectiveLng = currentLng.value ?? 31.2357;
                      final riderMapsUrl = 'https://maps.google.com/?q=$effectiveLat,$effectiveLng';

                      // ── Create reservation with Cash on Delivery ───────────────
                      final notes =
                          'طريقة الدفع: كاش عند الاستلام · إجمالي: ${grandTotal.toStringAsFixed(1)} ج.م شامل التوصيل (${deliveryFee.toStringAsFixed(1)} ج.م) · لوكيشن المريض: $riderMapsUrl';

                      final req = CreateReservationRequest(
                        inventoryItemId: inventoryItemId,
                        fulfillmentType: 'Delivery',
                        deliveryAddress: fullAddress,
                        deliveryLatitude: effectiveLat,
                        deliveryLongitude: effectiveLng,
                        deliveryContactPhone: phoneCtrl.text.trim(),
                        deliveryNotes: notes,
                      );

                      final resp = await ref.read(apiClientProvider).createReservation(req);

                      if (context.mounted) {
                        Navigator.of(context).pop(resp);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تعذر تأكيد طلب التوصيل: $e')),
                        );
                      }
                    } finally {
                      isSubmitting.value = false;
                    }
                  },
            icon: isSubmitting.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_rounded, color: Colors.white),
            label: Text(
              isSubmitting.value ? 'جارٍ إرسال الطلب…' : 'تأكيد طلب التوصيل كاش (${grandTotal.toStringAsFixed(1)} ج.م)',
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14.5),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
