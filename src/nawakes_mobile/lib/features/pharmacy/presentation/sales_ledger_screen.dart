import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accentBlue,
          onRefresh: () async => ref.invalidate(salesLedgerProvider),
          child: state.when(
            data: (ledger) {
              final entries = ledger.entries
                  .where((e) =>
                      searchQuery.value.isEmpty ||
                      e.medicationName
                          .toLowerCase()
                          .contains(searchQuery.value.toLowerCase()) ||
                      e.reservationCode
                          .toUpperCase()
                          .contains(searchQuery.value.toUpperCase()))
                  .toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const NawaqsTopBar(
                      eyebrow: 'نواقص / الصيدلية', title: 'سجل المبيعات', back: true),
                  const ScreenSubtitle(
                      'كل طلب خرج من الصيدلية — للمتابعة واكتشاف المشاكل مبكرًا'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Stats ───────────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _LedgerStat(
                                  label: 'طلبات اليوم',
                                  value: '${ledger.todayCount}',
                                  color: AppColors.accentBlue),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _LedgerStat(
                                  label: 'إجمالي الإيراد',
                                  value:
                                      'EGP ${ledger.totalRevenue.toStringAsFixed(0)}',
                                  color: AppColors.successText),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _LedgerStat(
                                  label: 'كل الطلبات',
                                  value: '${ledger.totalCompleted}',
                                  color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Search ──────────────────────────────────────────
                        TextField(
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
                child: CircularProgressIndicator(color: AppColors.accentBlue)),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تعذر تحميل السجل',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
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
    );
  }
}

class _LedgerStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _LedgerStat(
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
                  letterSpacing: 0.3,
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
    return Container(
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
                              letterSpacing: 0.5,
                              color: AppColors.textMuted)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('EGP ${entry.price.toStringAsFixed(2)}',
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
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 6),
          // بيانات تواصل المريض (للمتابعة عند المشاكل)
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
    );
  }
}
