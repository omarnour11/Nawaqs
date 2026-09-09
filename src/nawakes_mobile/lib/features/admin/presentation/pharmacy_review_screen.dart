import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart'
    show describeApiError;
import 'package:nawakes_mobile/features/admin/data/admin_models.dart';

/// Full-screen pharmacy review sheet (approve / reject with reason).
class PharmacyReviewScreen extends HookConsumerWidget {
  final AdminPharmacyDto pharmacy;

  const PharmacyReviewScreen({super.key, required this.pharmacy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reasonCtrl = useTextEditingController();
    final reviewing = useState<String?>(null); // null | 'approve' | 'reject'

    Future<void> act(bool approve) async {
      if (!approve && reasonCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A rejection reason is required.')),
        );
        return;
      }
      reviewing.value = approve ? 'approve' : 'reject';
      try {
        await ref.read(apiClientProvider).reviewPharmacy(
              pharmacy.id,
              ReviewPharmacyRequest(
                approve: approve,
                rejectionReason: approve ? null : reasonCtrl.text.trim(),
              ),
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(approve
                    ? '${pharmacy.name} approved.'
                    : '${pharmacy.name} rejected.')),
          );
          context.go('/admin');
        }
      } catch (e) {
        reviewing.value = null;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Review Pharmacy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(Icons.local_pharmacy_rounded,
                              color: AppColors.primary, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pharmacy.name,
                                  style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(pharmacy.ownerEmail,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                        icon: Icons.home_outlined,
                        label: 'Address',
                        value: '${pharmacy.addressLine}, ${pharmacy.city}'),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Phone', value: pharmacy.phone),
                    const SizedBox(height: 8),
                    _DetailRow(
                        label: 'Location',
                        value:
                            '${pharmacy.latitude.toStringAsFixed(4)}, ${pharmacy.longitude.toStringAsFixed(4)}'),
                    const SizedBox(height: 8),
                    _DetailRow(
                        label: 'Inventory items',
                        value: '${pharmacy.inventoryCount}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Documents
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CREDENTIALS',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: AppColors.textHint)),
                    const SizedBox(height: 10),
                    _DocRow(label: 'MoH License', url: pharmacy.licenseDocUrl),
                    const SizedBox(height: 8),
                    _DocRow(label: 'National ID', url: pharmacy.nationalIdDocUrl),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (pharmacy.verificationStatus == 'Pending') ...[
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Rejection reason (required only when rejecting)',
                  hintText: 'e.g. License image is unreadable…',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: reviewing.value != null ? null : () => act(true),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: reviewing.value != null ? null : () => act(false),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger, width: 1.3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md))),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Card(
                color: pharmacy.verificationStatus == 'Approved'
                    ? AppColors.successSurface
                    : AppColors.dangerSurface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        pharmacy.verificationStatus == 'Approved'
                            ? Icons.verified_rounded
                            : Icons.cancel_rounded,
                        color: pharmacy.verificationStatus == 'Approved'
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pharmacy.verificationStatus == 'Approved'
                              ? 'This pharmacy has been approved.'
                              : 'Rejected: ${pharmacy.rejectionReason ?? "no reason recorded"}',
                          style: const TextStyle(fontSize: 13, height: 1.4),
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
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const _DetailRow({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textHint,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  final String label;
  final String? url;

  const _DocRow({required this.label, this.url});

  @override
  Widget build(BuildContext context) {
    final hasDoc = url != null && url!.isNotEmpty;
    return Row(
      children: [
        Icon(
          hasDoc ? Icons.picture_as_pdf_rounded : Icons.hide_image_rounded,
          size: 18,
          color: hasDoc ? AppColors.primary : AppColors.textHint,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              Text(
                hasDoc ? url! : 'Not uploaded',
                style: TextStyle(
                    fontSize: 11,
                    color: hasDoc ? AppColors.info : AppColors.textHint),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
