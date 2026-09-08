import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:nawakes_mobile/features/reservations/presentation/reservation_controller.dart';
import 'package:nawakes_mobile/features/reports/presentation/report_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class PharmacyDetailsScreen extends HookConsumerWidget {
  final PharmacySearchResultDto item;

  const PharmacyDetailsScreen({super.key, required this.item});

  Future<void> _launchMaps() async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${item.latitude},${item.longitude}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch Maps';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationState = ref.watch(reservationControllerProvider);

    ref.listen<AsyncValue<void>>(
      reservationControllerProvider,
      (_, state) {
        if (!state.isLoading && state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${state.error}'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (!state.isLoading && !state.hasError && state.hasValue) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Reservation successful! You have 2 hours to pick it up.'),
              ]),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    ref.listen<AsyncValue<void>>(
      reportControllerProvider,
      (_, state) {
        if (!state.isLoading && state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${state.error}'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (!state.isLoading && !state.hasError && state.hasValue) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Thank you! Your report helps the community.'),
              ]),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    final inStock = item.status == 'InStock';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pharmacy Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pharmacy Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_pharmacy_rounded,
                              color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.pharmacyName,
                                  style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text('${item.distanceKm.toStringAsFixed(1)} km away',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary, fontSize: 13)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text('${item.trustScore.toStringAsFixed(1)} Trust',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Medication Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Medication Details',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: inStock ? AppColors.successSurface : AppColors.dangerSurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.medication_rounded,
                              color: inStock ? AppColors.success : AppColors.danger, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.medicationName,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: inStock ? AppColors.successSurface : AppColors.dangerSurface,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  inStock ? '✓ In Stock' : '✕ Out of Stock',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: inStock ? AppColors.success : AppColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Price',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            Text('EGP ${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Primary Actions
            ElevatedButton.icon(
              onPressed: inStock && !reservationState.isLoading
                  ? () => ref
                      .read(reservationControllerProvider.notifier)
                      .reserveItem(item.inventoryItemId)
                  : null,
              icon: reservationState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.bookmark_add_rounded),
              label: Text(reservationState.isLoading ? 'Reserving...' : 'Reserve for 2 Hours'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _launchMaps,
              icon: const Icon(Icons.directions_rounded),
              label: const Text('Get Directions'),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Secondary Actions (Report)
            Center(
              child: TextButton.icon(
                onPressed: () => _showReportBottomSheet(context, ref),
                icon: const Icon(Icons.campaign_rounded),
                label: const Text('Report / Update Status'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            left: 24,
            right: 24,
            top: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.center,
              ),
              const Icon(Icons.campaign_rounded, size: 48, color: AppColors.accent),
              const SizedBox(height: 16),
              const Text(
                'Community Reporting',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Help the community by verifying the stock status. Your reports directly affect this pharmacy\'s Trust Score.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(reportControllerProvider.notifier).submitReport(
                        item.pharmacyId,
                        1, // 1 = Found
                        item.medicationName,
                        reportedPrice: item.price,
                      );
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Confirm Found It Here'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(reportControllerProvider.notifier).submitReport(
                        item.pharmacyId,
                        0, // 0 = Inaccurate
                        item.medicationName,
                      );
                },
                icon: const Icon(Icons.error_outline_rounded),
                label: const Text('Report Inaccurate Stock'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
