import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:nawakes_mobile/features/reservations/presentation/reservation_controller.dart';
import 'package:nawakes_mobile/features/reports/presentation/report_controller.dart';
import 'package:url_launcher/url_launcher.dart';

/// Args passed via go_router `extra`.
class PharmacyDetailsArgs {
  final PharmacySearchResultDto item;
  PharmacyDetailsArgs({required this.item});
}

class PharmacyDetailsScreen extends HookConsumerWidget {
  final PharmacyDetailsArgs args;

  const PharmacyDetailsScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = args.item;
    final reservationState = ref.watch(reservationControllerProvider);
    final isFavorite = useState(false);
    final favoriteLoading = useState(false);
    final selectedPharmacy = useState(true); // this pharmacy selected

    useEffect(() {
      Future(() async {
        try {
          final favorites = await ref.read(apiClientProvider).getMyFavorites();
          isFavorite.value = favorites.any((f) => f.pharmacyId == item.pharmacyId);
        } catch (_) {}
      });
      return null;
    }, const []);

    ref.listen<AsyncValue<void>>(reservationControllerProvider, (_, state) {
      if (!state.isLoading && state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeApiError(state.error!)),
              backgroundColor: AppColors.dangerText),
        );
      } else if (!state.isLoading && !state.hasError && state.hasValue) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الحجز اتعمل. التصريح صالح لمدة ساعتين.')),
        );
      }
    });

    ref.listen<AsyncValue<void>>(reportControllerProvider, (_, state) {
      if (!state.isLoading && state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeApiError(state.error!)),
              backgroundColor: AppColors.dangerText),
        );
      } else if (!state.isLoading && !state.hasError && state.hasValue) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('شكرًا، تقريرك بيساعد باقي المستخدمين.')),
        );
      }
    });

    final inStock = item.status == 'InStock';
    final (availLabel, availTone) = inStock
        ? (item.quantity <= 4
            ? 'مخزون محدود · ${item.quantity} وحدة'
            : 'متاح · ${item.quantity} وحدة', ChipTone.warning)
        : ('غير متاح حاليًا', ChipTone.danger);
    final trust = (item.trustScore / 100).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            NawaqsTopBar(
              eyebrow: 'نواقص',
              title: item.medicationName,
              back: true,
              showBell: true,
              onBell: () => context.push('/notifications'),
            ),
            ScreenSubtitle('EGP ${item.price.toStringAsFixed(2)} · تحديث لحظي من الصيدلية'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Availability confidence card ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              inStock
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.cancel_outlined,
                              size: 19,
                              color: inStock
                                  ? AppColors.successIcon
                                  : AppColors.dangerIcon,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                inStock
                                    ? '${item.quantity > 0 ? item.quantity : 5}+ وحدة مُبلّغ عنها قريبًا'
                                    : 'الصيدلية reporting إنه غير متاح',
                                style: const TextStyle(
                                    fontSize: 14.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text('منطقة البحث: موقعك الحالي',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: inStock ? (item.quantity <= 4 ? 0.35 : trust) : 0.05,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE9EAED),
                            color: inStock
                                ? (item.quantity <= 4
                                    ? AppColors.warningIcon
                                    : AppColors.successIcon)
                                : AppColors.dangerIcon,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('درجة توفر',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary)),
                            Text('حسب بلاغات حديثة',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Pickup section ────────────────────────────────────────
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SectionLabel('أقرب الصيدليات'),
                      Text('الأقرب أولاً',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentBlue)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text('اختار مكان الاستلام',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),

                  // ── Select card: this pharmacy ────────────────────────────
                  _SelectCard(
                    selected: selectedPharmacy.value,
                    onSelected: () => selectedPharmacy.value = true,
                    title: item.pharmacyName,
                    meta: '${item.addressLine} · ${_timeAgo(item.lastUpdatedAt)}',
                    trailing: _formatDistance(item.distanceKm),
                    availabilityLabel: availLabel,
                    availabilityTone: availTone,
                    note: item.patientNote,
                  ),

                  const SizedBox(height: 16),

                  // ── Actions ───────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: inStock && !reservationState.isLoading
                              ? () => ref
                                  .read(reservationControllerProvider.notifier)
                                  .reserveItem(item.inventoryItemId)
                              : null,
                          icon: reservationState.isLoading
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.qr_code_2_rounded, size: 18),
                          label: Text(reservationState.isLoading
                              ? 'جارٍ الحجز…'
                              : inStock
                                  ? 'احجز تصريح'
                                  : 'غير متاح'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: favoriteLoading.value ? null : () async {
                          favoriteLoading.value = true;
                          try {
                            final result = await ref
                                .read(apiClientProvider)
                                .toggleFavorite(item.pharmacyId);
                            isFavorite.value = result.isFavorite;
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(describeApiError(e))),
                              );
                            }
                          } finally {
                            favoriteLoading.value = false;
                          }
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isFavorite.value
                                ? AppColors.dangerBg
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Icon(
                            isFavorite.value
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite.value
                                ? AppColors.dangerIcon
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=${item.latitude},${item.longitude}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.near_me_rounded, size: 17),
                    label: const Text('الاتجاهات على الخريطة'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showReportSheet(context, ref),
                      icon: const Icon(Icons.campaign_outlined, size: 18),
                      label: const Text('بلّغ عن حالة التوفر'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} متر';
    return '${km.toStringAsFixed(1)} كم';
  }

  String _timeAgo(DateTime utc) {
    final diff = DateTime.now().toUtc().difference(utc);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'تحديث من ${diff.inMinutes} دقايق';
    return 'تحديث من ${diff.inHours} ساعة';
  }

  void _showReportSheet(BuildContext context, WidgetRef ref) {
    final item = args.item;
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20, right: 20, top: 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('تقرير مجتمعي'),
            const SizedBox(height: 6),
            const Text('ساعد بقية المرضى بتأكيد حالة التوفر',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'تقاريرك بتأثر مباشرة على درجة ثقة الصيدلية.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(reportControllerProvider.notifier).submitReport(
                      item.pharmacyId, 1, item.medicationName,
                      reportedPrice: item.price);
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('لقيت الدواء هنا'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.successText,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13))),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(reportControllerProvider.notifier).submitReport(
                      item.pharmacyId, 0, item.medicationName);
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('المعلومة مش دقيقة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dangerText,
                side: const BorderSide(color: AppColors.dangerIcon, width: 1.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Select card (radio pickup choice from mockup) ───────────────────────────
class _SelectCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onSelected;
  final String title;
  final String meta;
  final String trailing;
  final String availabilityLabel;
  final ChipTone availabilityTone;
  final String? note;

  const _SelectCard({
    required this.selected,
    required this.onSelected,
    required this.title,
    required this.meta,
    required this.trailing,
    required this.availabilityLabel,
    required this.availabilityTone,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final (fg, ic) = switch (availabilityTone) {
      ChipTone.success => (AppColors.successText, AppColors.successIcon),
      ChipTone.warning => (AppColors.warningText, AppColors.warningIcon),
      ChipTone.danger => (AppColors.dangerText, AppColors.dangerIcon),
      ChipTone.neutral => (AppColors.accentBlue, AppColors.accentBlue),
    };

    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accentBlue : AppColors.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(meta,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(trailing,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(width: 10),
                // radio
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accentBlue : Colors.transparent,
                    shape: BoxShape.circle,
                    border: selected
                        ? null
                        : Border.all(color: AppColors.textMuted, width: 1.6),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 13, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: ic, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(availabilityLabel,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
              ],
            ),
            if (note != null && note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(note!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
