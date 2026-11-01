import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/pharmacy/data/sales_ledger_models.dart';
import 'package:intl/intl.dart' show DateFormat;

part 'sales_ledger_screen.g.dart';

@riverpod
Future<SalesLedgerDto> salesLedger(Ref ref) async {
  return ref.read(apiClientProvider).getSalesLedger();
}

/// سجل المبيعات — كل طلب خرج من الصيدلية + إحصائيات + بيانات تواصل المريض.
class SalesLedgerScreen extends HookConsumerWidget {
  const SalesLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(salesLedgerProvider);
    final searchQuery = useState('');
    final searchCtrl = useTextEditingController();

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accentBlue,
          onRefresh: () async => ref.invalidate(salesLedgerProvider),
          child: state.when(
            data: (ledger) {
              final entries = ledger.entries.where((e) {
                final q = searchQuery.value.trim().toLowerCase();
                if (q.isEmpty) return true;
                return e.medicationName.toLowerCase().contains(q) ||
                    e.reservationCode.toLowerCase().contains(q);
              }).toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const NawaqsTopBar(
                    eyebrow: 'الصيدلية / السجلات',
                    title: 'سجل المبيعات',
                    back: true,
                    showBell: false,
                  ),
                  const ScreenSubtitle(
                      'أرشيف الطلبات المكتملة وإجمالي الإيرادات وبيانات التواصل'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Stats ───────────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                label: 'طلبات اليوم',
                                value: '${ledger.todayCount}',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricCard(
                                label: 'إجمالي الإيراد',
                                value: '${ledger.totalRevenue.toStringAsFixed(0)} ج.م',
                                color: AppColors.successText,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricCard(
                                label: 'كل الطلبات',
                                value: '${ledger.totalCompleted}',
                                color: AppColors.accentBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ── Search ──────────────────────────────────────────
                        TextField(
                          controller: searchCtrl,
                          onChanged: (v) => searchQuery.value = v,
                          decoration: const InputDecoration(
                            hintText: 'ابحث بدواء أو كود تصريح',
                            prefixIcon: Icon(Icons.search_rounded,
                                size: 19, color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Entries ─────────────────────────────────────────
                        const SectionLabel('الطلبات المكتملة'),
                        const SizedBox(height: 8),
                        if (entries.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                              border:
                                  Border.all(color: AppColors.hairline),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 42, color: AppColors.textMuted),
                                SizedBox(height: 10),
                                Text('لسه مفيش طلبات مكتملة',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5)),
                                SizedBox(height: 4),
                                Text(
                                    'أول طلب تتسلمه هيظهر هنا بسجل دائم.',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        else
                          ...entries.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _LedgerRow(entry: e),
                              )),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.accentBlue),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 40),
                    const SizedBox(height: 10),
                    const Text('تعذر تحميل سجل المبيعات'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(salesLedgerProvider),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.0,
                  color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final SalesLedgerEntryDto entry;
  const _LedgerRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _showOrderDetailsSheet(context, entry),
        child: Container(
          padding: const EdgeInsets.all(13),
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
                  const IconTile(Icons.check_circle_outline_rounded,
                      bg: AppColors.successBg, color: AppColors.successIcon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.medicationName,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(entry.reservationCode,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.0,
                                  color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${entry.price.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.successText)),
                      const SizedBox(height: 2),
                      Text(
                          DateFormat('d MMM · HH:mm')
                              .format(entry.completedAt.toLocal()),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_left_rounded,
                      color: AppColors.textMuted, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 6),
              // بيانات تواصل المريض
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 5),
                  const Text('المريض:',
                      style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(entry.patientContact,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 4),
                  Text('${entry.quantity} وحدة',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showOrderDetailsSheet(BuildContext context, SalesLedgerEntryDto entry) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final cleanPhone = entry.patientContact.replaceAll(RegExp(r'[^\d+]'), '');
      final hasPhone = cleanPhone.isNotEmpty && cleanPhone != '—';

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.medicationName,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      const Text('تفاصيل طلب الاستلام المكتمل',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('تم الاستلام',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.successText)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // كود التصريح
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_rounded,
                      size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  const Text('كود الاستلام:',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      entry.reservationCode,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'نسخ الكود',
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: entry.reservationCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ كود الاستلام.')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // بيانات العملية
            InfoCell(
              label: 'تاريخ الاستلام',
              value: DateFormat('d MMMM yyyy · HH:mm')
                  .format(entry.completedAt.toLocal()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InfoCell(
                    label: 'الكمية المستلمة',
                    value: '${entry.quantity} عبوة',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InfoCell(
                    label: 'المبلغ المدفوع',
                    value: '${entry.price.toStringAsFixed(2)} ج.م',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // بيانات تواصل المريض
            const SectionLabel('بيانات تواصل المريض'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        hasPhone ? entry.patientContact : 'غير متوفر',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  if (hasPhone) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.call_rounded, size: 17),
                            label: const Text('اتصال هاتفي'),
                            style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            onPressed: () async {
                              final uri = Uri.parse('tel:$cleanPhone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.chat_bubble_outline_rounded,
                                size: 17),
                            label: const Text('واتساب'),
                            style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            onPressed: () async {
                              final phone = cleanPhone.startsWith('0')
                                  ? '2$cleanPhone'
                                  : cleanPhone;
                              final uri = Uri.parse('https://wa.me/$phone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
