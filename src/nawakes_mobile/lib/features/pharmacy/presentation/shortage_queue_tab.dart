import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/profile/data/medication_models.dart';

part 'shortage_queue_tab.g.dart';

@riverpod
Future<List<ShortageRequestDto>> openShortageRequests(Ref ref) async {
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

  return ref.read(apiClientProvider).getOpenShortageRequests(lat, lng, 25);
}

/// طلبات النواقص القريبة — pharmacy claims patient broadcast requests.
class ShortageQueueTab extends HookConsumerWidget {
  const ShortageQueueTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(openShortageRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: RefreshIndicator(
        color: AppColors.accentBlue,
        onRefresh: () async => ref.invalidate(openShortageRequestsProvider),
        child: state.when(
          data: (requests) {
            if (requests.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 140),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.campaign_outlined,
                          size: 52, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text('مفيش استغاثات نواقص حوالينك',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      SizedBox(height: 4),
                      Text(
                        'لما مريض يعجز عن دواء مش موجود، طلبه هيظهر هنا الأول.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                for (final r in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ShortageCard(request: r),
                  ),
              ],
            );
          },
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر تحميل الطلبات',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(openShortageRequestsProvider),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortageCard extends HookConsumerWidget {
  final ShortageRequestDto request;
  const _ShortageCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState(false);

    Future<void> claim() async {
      busy.value = true;
      try {
        await ref.read(apiClientProvider).claimShortageRequest(request.id);
        ref.invalidate(openShortageRequestsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'طلبت ${request.medicationName} اتحجز للمريض — التصريح بقت عنده لمدة ساعتين.')),
          );
        }
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

    final hoursLeft = request.expiresAt.difference(DateTime.now()).inHours;

    return Container(
      padding: const EdgeInsets.all(14),
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
              const IconTile(
                Icons.medication_outlined,
                bg: AppColors.warningBg,
                color: AppColors.warningIcon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        request.strength != null && request.strength!.isNotEmpty
                            ? '${request.medicationName} · ${request.strength}'
                            : request.medicationName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        '${request.quantityNeeded} وحدة · ${request.distanceKm.toStringAsFixed(1)} كم · تطلب قبل $hoursLeft ساعة',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(request.notes!,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy.value ? null : claim,
              icon: busy.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.local_offer_outlined, size: 17),
              label: const Text('اطلب الحجز للمريض (ساعتين)'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13))),
            ),
          ),
        ],
      ),
    );
  }
}
