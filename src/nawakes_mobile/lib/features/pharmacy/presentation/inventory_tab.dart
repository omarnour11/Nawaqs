import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart' show SetAvailabilityRequest;
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/quick_barcode_scanner_sheet.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:intl/intl.dart' show DateFormat;

/// المخزون — verified pharmacy card + tinted stat grid + med list with
/// available/limited/unavailable action buttons (per mockup).
class InventoryTab extends HookConsumerWidget {
  const InventoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = useState('');
    final searchCtrl = useTextEditingController();
    final state = ref.watch(pharmacyInventoryControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: state.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accentBlue)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذر تحميل المخزون',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(pharmacyInventoryControllerProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (items) {
          final filtered = searchQuery.value.isEmpty
              ? items
              : items
                  .where((i) => i.medicationName
                      .toLowerCase()
                      .contains(searchQuery.value.toLowerCase()))
                  .toList();

          final available = items
              .where((i) => i.status == 'InStock' && i.quantity >= 5)
              .length;
          final limited = items
              .where((i) => i.status == 'InStock' && i.quantity > 0 && i.quantity <= 4)
              .length;
          final unavailable = items.where((i) => i.status != 'InStock').length;

          return RefreshIndicator(
            color: AppColors.accentBlue,
            onRefresh: () async =>
                ref.invalidate(pharmacyInventoryControllerProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                const SizedBox(height: 4),
                // ── Verified pharmacy card ────────────────────────────────
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
                          const Expanded(
                            child: SectionLabel('صيدلية موثقة'),
                          ),
                          const StatusChip(
                            'موثقة',
                            tone: ChipTone.success,
                            icon: Icons.verified_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('مخزونك',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      const Text('تحديث لحظي — المرضى بيشوفوا اللي بتقوله هنا',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                              width: 7,
                              height: 7,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.successIcon)),
                          const SizedBox(width: 6),
                          const Text('تُبلغ مباشرة',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.successText)),
                          const Spacer(),
                          const Text('آخر تحديث: الآن',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                  // ── Stat grid: available / limited / unavailable ─────────
                  Row(
                    children: [
                      Expanded(
                        child: StatCardTinted(
                          value: available,
                          label: 'متاح',
                          icon: Icons.inventory_2_outlined,
                          bg: AppColors.successBg,
                          fg: AppColors.successText,
                          iconColor: AppColors.successIcon,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCardTinted(
                          value: limited,
                          label: 'محدود',
                          icon: Icons.warning_amber_outlined,
                          bg: AppColors.warningBg,
                          fg: AppColors.warningText,
                          iconColor: AppColors.warningIcon,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCardTinted(
                          value: unavailable,
                          label: 'غير متاح',
                          icon: Icons.cancel_outlined,
                          bg: AppColors.dangerBg,
                          fg: AppColors.dangerText,
                          iconColor: AppColors.dangerIcon,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section header + search ──────────────────────────────
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionLabel('قائمة الأدوية'),
                            Text('مخزون اليوم',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      // Quick Barcode Scanner button
                      GestureDetector(
                        onTap: () => QuickBarcodeScannerSheet.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlueBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_scanner_rounded,
                                  size: 15, color: AppColors.accentBlue),
                              SizedBox(width: 4),
                              Text('مسح سريع',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accentBlue)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add medication button
                      GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => _AddMedSheet(),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlueBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 15, color: AppColors.accentBlue),
                              SizedBox(width: 4),
                              Text('إضافة دواء',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accentBlue)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (v) => searchQuery.value = v,
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن دواء',
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 19, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Medication cards ─────────────────────────────────────
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.medication_outlined,
                              size: 40, color: AppColors.textMuted),
                          SizedBox(height: 10),
                          Text('مفيش أدوية لسه',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                          SizedBox(height: 4),
                          Text('ضيف أول دواء من زر إضافة دواء فوق.',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  else
                    ...filtered.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MedCard(item: item),
                        )),
                ],
              ),
            );
          },
        ),
    );
  }
}

// Tinted stat card variant (whole card takes the state tint per spec).
class StatCardTinted extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color iconColor;

  const StatCardTinted({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.topStart,
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text('$value',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: fg, height: 1.1)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: fg.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

// ─── Medication card with availability actions ────────────────────────────────
class _MedCard extends HookConsumerWidget {
  final dynamic item;
  const _MedCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState(false);

    final isOut = item.status != 'InStock';
    final isLimited = !isOut && item.quantity <= 4;
    final isAvailable = !isOut && !isLimited;

    final (chipLabel, chipBg, chipFg) = isOut
        ? ('غير متاح', AppColors.dangerBg, AppColors.dangerText)
        : isLimited
            ? ('محدود', AppColors.warningBg, AppColors.warningText)
            : ('متاح', AppColors.successBg, AppColors.successText);

    Future<void> setAvailability(int qty) async {
      busy.value = true;
      try {
        await ref.read(apiClientProvider).setAvailability(
              item.id as String,
              SetAvailabilityRequest(quantity: qty, price: item.price as double),
            );
        ref.invalidate(pharmacyInventoryControllerProvider);
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

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(
                Icons.medication_outlined,
                bg: isOut
                    ? AppColors.dangerBg
                    : isLimited
                        ? AppColors.warningBg
                        : AppColors.successBg,
                color: isOut
                    ? AppColors.dangerIcon
                    : isLimited
                        ? AppColors.warningIcon
                        : AppColors.successIcon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.medicationName as String,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('EGP ${(item.price as double).toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(chipLabel,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: chipFg)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '${item.quantity} وحدة · ${DateFormat('HH:mm').format((item.updatedAt ?? item.createdAt as DateTime).toLocal())}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AvailabilityButton(
                  label: 'متاح',
                  selected: isAvailable,
                  selectedBg: AppColors.successBg,
                  selectedFg: AppColors.successText,
                  selectedBorder: AppColors.successIcon,
                  icon: Icons.check_rounded,
                  onTap: busy.value ? null : () => setAvailability(10),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AvailabilityButton(
                  label: 'محدود',
                  selected: isLimited,
                  selectedBg: AppColors.warningBg,
                  selectedFg: AppColors.warningText,
                  selectedBorder: AppColors.warningIcon,
                  onTap: busy.value ? null : () => setAvailability(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AvailabilityButton(
                  label: 'غير متاح',
                  selected: isOut,
                  selectedBg: AppColors.dangerBg,
                  selectedFg: AppColors.dangerText,
                  selectedBorder: AppColors.dangerIcon,
                  onTap: busy.value ? null : () => setAvailability(0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailabilityButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedBg;
  final Color selectedFg;
  final Color selectedBorder;
  final IconData? icon;
  final VoidCallback? onTap;

  const _AvailabilityButton({
    required this.label,
    required this.selected,
    required this.selectedBg,
    required this.selectedFg,
    required this.selectedBorder,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedBg : AppColors.card,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? selectedBorder : AppColors.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected && icon != null) ...[
                Icon(icon, size: 15, color: selectedFg),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? selectedFg : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add medication bottom sheet (mockup: إضافة دواء) ─────────────────────────
class _AddMedSheet extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameCtrl = useTextEditingController();
    final strengthCtrl = useTextEditingController();
    final qtyCtrl = useTextEditingController(text: '10');
    final priceCtrl = useTextEditingController();
    final noteCtrl = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final availability = useState<int>(10); // 10=available, 3=limited, 0=unavailable
    final submitting = useState(false);

    Future<void> save() async {
      if (!formKey.currentState!.validate()) return;
      submitting.value = true;
      try {
        await ref.read(pharmacyInventoryControllerProvider.notifier).addItem(
              nameCtrl.text.trim(),
              double.tryParse(priceCtrl.text) ?? 0,
              quantity: int.tryParse(qtyCtrl.text) ?? 10,
              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
            );
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الدواء اتضاف للمخزون.')),
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20, right: 20, top: 4,
      ),
      child: Form(
        key: formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const SectionLabel('إضافة دواء'),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'اسم الدواء', hintText: 'مثلاً: أموكسيسيلين'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: strengthCtrl,
                    decoration: const InputDecoration(
                        labelText: 'التركيز', hintText: '500 مجم'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'السعر EGP', hintText: '28.50'),
                    validator: (v) =>
                        v == null || double.tryParse(v) == null ? 'رقم غير صحيح' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية المتوفرة'),
            ),
            const SizedBox(height: 14),
            const SectionLabel('حالة التوفر'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _AvailabilityButton(
                    label: 'متاح',
                    selected: availability.value >= 5,
                    selectedBg: AppColors.successBg,
                    selectedFg: AppColors.successText,
                    selectedBorder: AppColors.successIcon,
                    icon: Icons.check_rounded,
                    onTap: () => availability.value = 10,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AvailabilityButton(
                    label: 'محدود',
                    selected: availability.value > 0 && availability.value <= 4,
                    selectedBg: AppColors.warningBg,
                    selectedFg: AppColors.warningText,
                    selectedBorder: AppColors.warningIcon,
                    onTap: () => availability.value = 3,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AvailabilityButton(
                    label: 'غير متاح',
                    selected: availability.value == 0,
                    selectedBg: AppColors.dangerBg,
                    selectedFg: AppColors.dangerText,
                    selectedBorder: AppColors.dangerIcon,
                    onTap: () => availability.value = 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'ملاحظات للمرضى (اختياري)',
                  hintText: 'مثلاً: متوفر بس علبة الـ30 كبسولة'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: submitting.value ? null : save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand900,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
                child: submitting.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ في المخزون'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
