import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/medication_image_view.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart'
    show describeApiError;
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/search/presentation/nearby_products_provider.dart'
    show deliveryLocationProvider;
import 'package:nawakes_mobile/features/search/presentation/widgets/safety_shield_dialog.dart';

/// Modal sheet that displays all nearby pharmacies (within 15km) stocking
/// a specific product, allowing one-tap direct reservation.
class NearbyPharmacyOptionsSheet extends ConsumerStatefulWidget {
  final NearbyProduct product;

  const NearbyPharmacyOptionsSheet({
    super.key,
    required this.product,
  });

  static Future<void> show(BuildContext context, NearbyProduct product) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NearbyPharmacyOptionsSheet(product: product),
    );
  }

  @override
  ConsumerState<NearbyPharmacyOptionsSheet> createState() =>
      _NearbyPharmacyOptionsSheetState();
}

class _NearbyPharmacyOptionsSheetState
    extends ConsumerState<NearbyPharmacyOptionsSheet> {
  String? _reservingPharmacyId;
  bool _isSubscribing = false;

  String _formatPharmacyCount(int count) {
    if (count == 1) return 'صيدلية واحدة';
    if (count == 2) return 'صيدليتين';
    if (count >= 3 && count <= 10) return '$count صيدليات';
    return '$count صيدلية';
  }

  Future<void> _handleSubscribeAlert() async {
    if (_isSubscribing) return;
    setState(() => _isSubscribing = true);
    try {
      final dio = ref.read(dioProvider);
      final p = widget.product;
      final currentLoc = ref.read(deliveryLocationProvider);
      final lat = currentLoc.latitude;
      final lng = currentLoc.longitude;

      await dio.post('/subscriptions', data: {
        'medicationName': p.commercialNameAr ?? p.tradeName,
        'radiusKm': 15.0,
        'latitude': lat,
        'longitude': lng,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تفعيل التنبيه بنجاح! سنرسل لك إشعاراً فور توفره في صيدلية قريبة منك.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } on DioException catch (dioEx) {
      if (!mounted) return;
      if (dioEx.response?.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('أنت مشترك بالفعل في قائمة التنبيه لهذا الدواء.'),
            backgroundColor: AppColors.accentBlue,
          ),
        );
      } else if (dioEx.response?.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تسجيل الدخول أولاً لتفعيل تنبيهات التوفر.'),
            backgroundColor: AppColors.warning,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تفعيل التنبيه: ${describeApiError(dioEx)}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تفعيل التنبيه حالياً. يرجى المحاولة لاحقاً.'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

  Future<void> _handleOneClickReserve(NearbyPharmacyOption opt) async {
    setState(() => _reservingPharmacyId = opt.pharmacyId);

    try {
      final targetItemId =
          opt.inventoryItemId.isNotEmpty ? opt.inventoryItemId : widget.product.id;

      // Clinical safety shield before confirming the reservation.
      final allowed = await guardReservationWithSafetyCheck(
        context,
        ref,
        inventoryItemId: targetItemId,
        medicationName: widget.product.commercialNameAr ?? widget.product.tradeName,
      );
      if (!allowed || !mounted) {
        if (mounted) setState(() => _reservingPharmacyId = null);
        return;
      }

      final req = CreateReservationRequest(
        inventoryItemId: targetItemId,
      );

      final resp = await ref.read(apiClientProvider).createReservation(req);
      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Text(
            'تم تأكيد حجزك بنجاح في ${opt.pharmacyName}! رمز الحجز: ${resp.reservationCode}',
          ),
          action: SnackBarAction(
            label: 'عرض الحجز',
            textColor: Colors.white,
            onPressed: () => context.push('/passes'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _reservingPharmacyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إتمام الحجز حالياً. يرجى المحاولة مرة أخرى.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Product Summary Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                MedicationImageView(
                  imageUrl: p.imageUrl,
                  dosageForm: p.dosageForm,
                  tradeName: p.tradeName,
                  width: 70,
                  height: 70,
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.commercialNameAr ?? p.tradeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.commercialNameAr != null &&
                          p.commercialNameAr != p.tradeName)
                        Text(
                          p.tradeName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.dosageForm ?? 'عبوة دوائية',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${p.price.toStringAsFixed(2)} ج.م',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Product Description Card (E-commerce style preview)
          if (p.description != null && p.description!.trim().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'نبذة عن المنتج:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 16),

          // Governorate distance warning & delivery support banner
          if (p.minDistanceKm > 15.0) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFEA580C), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ملاحظة: الدواء متوفر في صيدلية بعيدة عنك',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p.pharmacies.any((x) => x.supportsDelivery)
                              ? 'الدواء موجود بنطاق المحافظة على بُعد ${p.minDistanceKm.toStringAsFixed(1)} كم، ويمكنك طلبه عبر التوصيل المنزلي من الصيدليات المتاحة أدناه.'
                              : 'الدواء موجود في صيدلية بعيدة (${p.minDistanceKm.toStringAsFixed(1)} كم) ولا تدعم التوصيل إلى منطقتك. يمكنك تفعيل التنبيه وسنرسل لك إشعاراً فور توفره في صيدلية قريبة منك.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFC2410C),
                            height: 1.35,
                          ),
                        ),
                        if (!p.pharmacies.any((x) => x.supportsDelivery)) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _isSubscribing ? null : _handleSubscribeAlert,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isSubscribing)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                    )
                                  else ...[
                                    const Icon(Icons.notifications_active_rounded,
                                        size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                  ],
                                  const Text(
                                    'أشعرني عند توفره بصيدلية قريبة 🔔',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.minDistanceKm <= 15.0
                        ? 'متوفر في ${_formatPharmacyCount(p.availablePharmaciesCount)} قريبة منك (ضمن 15 كم)'
                        : 'متوفر في ${_formatPharmacyCount(p.availablePharmaciesCount)} (نطاق المحافظة - ${p.minDistanceKm.toStringAsFixed(1)} كم)',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List of Pharmacies
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              itemCount: p.pharmacies.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final opt = p.pharmacies[index];
                final isReserving = _reservingPharmacyId == opt.pharmacyId;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Pharmacy Icon / Badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_pharmacy_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt.pharmacyName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 13, color: AppColors.textMuted),
                                    const SizedBox(width: 2),
                                    Text(
                                      opt.distanceKm < 1
                                          ? '${(opt.distanceKm * 1000).round()} متر'
                                          : '${opt.distanceKm.toStringAsFixed(1)} كم',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'متوفر (${opt.inStockQuantity} علب)',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: opt.supportsDelivery
                                        ? const Color(0xFFE0F2FE)
                                        : const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        opt.supportsDelivery
                                            ? Icons.delivery_dining_rounded
                                            : Icons.storefront_rounded,
                                        size: 10,
                                        color: opt.supportsDelivery
                                            ? const Color(0xFF0284C7)
                                            : const Color(0xFFE65100),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        opt.supportsDelivery
                                            ? 'توصيل متاح'
                                            : 'استلام فقط',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: opt.supportsDelivery
                                              ? const Color(0xFF0284C7)
                                              : const Color(0xFFE65100),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (opt.address != null && opt.address!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  opt.address!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (opt.distanceKm > 15.0 && !opt.supportsDelivery)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'تم تفعيل الإشعار! سننبهك فور توفر الدواء بصيدلية أقرب إليك.',
                                        ),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'أشعرني عند توفره بصيدلية أقرب 🔔',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Action Button
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: isReserving
                            ? null
                            : () => _handleOneClickReserve(opt),
                        child: isReserving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'حجز',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
