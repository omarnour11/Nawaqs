import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart'
    show describeApiError;
import 'package:nawakes_mobile/features/admin/data/admin_models.dart';
import 'package:nawakes_mobile/features/admin/presentation/admin_dashboard_screen.dart';

/// شاشة مراجعة واعتماد الصيدلية (قبول / رفض مع ذكر السبب).
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
          const SnackBar(content: Text('يرجى كتابة سبب الرفض أولاً.')),
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
        ref.invalidate(adminPharmaciesProvider);
        ref.invalidate(adminStatsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approve
                  ? 'تم اعتماد ${pharmacy.name} بنجاح.'
                  : 'تم رفض ${pharmacy.name}.'),
            ),
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
      appBar: AppBar(title: const Text('مراجعة واعتماد الصيدلية')),
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
                        label: 'العنوان',
                        value: '${pharmacy.addressLine}، ${pharmacy.city}'),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'رقم الهاتف', value: pharmacy.phone),
                    const SizedBox(height: 8),
                    _DetailRow(
                        label: 'الإحداثيات',
                        value:
                            '${pharmacy.latitude.toStringAsFixed(4)}، ${pharmacy.longitude.toStringAsFixed(4)}'),
                    const SizedBox(height: 8),
                    _DetailRow(
                        label: 'عناصر المخزون',
                        value: '${pharmacy.inventoryCount} صنف'),
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
                    const Text('مستندات التوثيق والتراخيص',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppColors.textHint)),
                    const SizedBox(height: 10),
                    _DocRow(label: 'ترخيص وزارة الصحة', url: pharmacy.licenseDocUrl),
                    const SizedBox(height: 8),
                    _DocRow(label: 'بطاقة الرقم القومي / السجل', url: pharmacy.nationalIdDocUrl),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),


            // ── Admin Operations (الاتصال، الواتساب، تعديل الحالة، الحذف) ──────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إجراءات وعمليات الإدارة العليا',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppColors.textHint)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pharmacy.phone.isEmpty
                                ? null
                                : () async {
                                    final url = Uri(scheme: 'tel', path: pharmacy.phone);
                                    if (await canLaunchUrl(url)) await launchUrl(url);
                                  },
                            icon: const Icon(Icons.phone_in_talk_rounded, size: 17),
                            label: const Text('اتصال'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pharmacy.phone.isEmpty
                                ? null
                                : () async {
                                    final cleanDigits = pharmacy.phone.replaceAll(RegExp(r'[^0-9]'), '');
                                    final phoneWithCode = cleanDigits.startsWith('0')
                                        ? '20${cleanDigits.substring(1)}'
                                        : cleanDigits;
                                    final url = Uri.parse('https://wa.me/$phoneWithCode');
                                    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                                  },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17, color: Color(0xFF25D366)),
                            label: const Text('واتساب', style: TextStyle(color: Color(0xFF1E7E34))),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              side: const BorderSide(color: Color(0xFF25D366)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Toggle Status (Suspend / Reactivate)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final isApproved = pharmacy.verificationStatus == 'Approved';
                              final targetStatus = isApproved ? 'Rejected' : 'Approved';
                              final promptTitle = isApproved ? 'تعليق / تجميد الصيدلية' : 'إعادة تفعيل واعتماد الصيدلية';
                              final noteCtrl = TextEditingController();

                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: Text(promptTitle),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isApproved
                                            ? 'سيتم حظر ظهور أدوية الصيدلية في نتائج بحث المرضى مؤقتاً.'
                                            : 'سيتم إعادة اعتماد وتوثيق الصيدلية وتفعيل ظهورها للمرضى.',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: noteCtrl,
                                        decoration: const InputDecoration(
                                          hintText: 'ملاحظة الإدارة (اختياري)',
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx, false),
                                      child: const Text('إلغاء'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      child: const Text('تأكيد التغيير'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                try {
                                  await ref.read(apiClientProvider).updatePharmacyStatus(
                                        pharmacy.id,
                                        UpdatePharmacyStatusRequest(
                                          status: targetStatus,
                                          reason: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                                        ),
                                      );
                                  ref.invalidate(adminPharmaciesProvider);
                                  ref.invalidate(adminStatsProvider);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('تم تعديل حالة الصيدلية إلى $targetStatus.')),
                                    );
                                    context.go('/admin');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(describeApiError(e))),
                                    );
                                  }
                                }
                              }
                            },
                            icon: Icon(
                              pharmacy.verificationStatus == 'Approved'
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 17,
                            ),
                            label: Text(
                              pharmacy.verificationStatus == 'Approved'
                                  ? 'تجميد الاعتماد'
                                  : 'تفعيل واعتماد',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Delete Pharmacy Permanently
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('حذف الصيدلية نهائياً'),
                                content: Text(
                                  'تحذير: سيتم حذف صيدلية "${pharmacy.name}" ومخزونها بالكامل وإلغاء أي حجوزات نشطة لها. هل أنت متأكد؟',
                                  style: const TextStyle(fontSize: 13, height: 1.4),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: const Text('تراجع'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.danger),
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    child: const Text('تأكيد الحذف'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              try {
                                await ref.read(apiClientProvider).deletePharmacy(pharmacy.id);
                                ref.invalidate(adminPharmaciesProvider);
                                ref.invalidate(adminStatsProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('تم حذف صيدلية ${pharmacy.name} بنجاح.')),
                                  );
                                  context.go('/admin');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(describeApiError(e))),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 17, color: AppColors.danger),
                          label: const Text('حذف الصيدلية',
                              style: TextStyle(color: AppColors.danger)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (pharmacy.verificationStatus == 'Pending') ...[
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'سبب الرفض (إلزامي في حالة الرفض فقط)',
                  hintText: 'مثال: صورة ترخيص وزارة الصحة غير واضحة أو منتهية…',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: reviewing.value != null ? null : () => act(true),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('اعتماد الصيدلية'),
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
                      label: const Text('رفض الطلب'),
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
                              ? 'تم اعتماد وتوثيق هذه الصيدلية رسمياً بنجاح.'
                              : 'تم الرفض: ${pharmacy.rejectionReason ?? "لم يُسجل سبب"}',
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
                hasDoc ? url! : 'لم يتم الرفع بعد',
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
