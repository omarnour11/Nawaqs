import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/utils/arabic_digits.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:dio/dio.dart' show MultipartFile;
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_controller.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/quick_barcode_scanner_sheet.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_dashboard_models.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_onboarding_screen.dart'
    show myPharmacyProvider;

/// المخزون — verified pharmacy card + tinted stat grid + med list with
/// available/limited/unavailable action buttons (per mockup).
class InventoryTab extends HookConsumerWidget {
  const InventoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = useState('');
    final searchCtrl = useTextEditingController();
    final state = ref.watch(pharmacyInventoryControllerProvider);
    final pharmacyState = ref.watch(myPharmacyProvider);
    final verificationStatus =
        pharmacyState.value?.verificationStatus ?? 'Pending';

    return Scaffold(

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
                          Expanded(
                            child: SectionLabel(
                              verificationStatus == 'Approved'
                                  ? 'صيدلية موثقة'
                                  : 'حالة اعتماد الصيدلية',
                            ),
                          ),
                          StatusChip(
                            verificationStatus == 'Approved'
                                ? 'موثقة'
                                : (verificationStatus == 'Rejected'
                                    ? 'مرفوضة'
                                    : 'قيد المراجعة'),
                            tone: verificationStatus == 'Approved'
                                ? ChipTone.success
                                : (verificationStatus == 'Rejected'
                                    ? ChipTone.danger
                                    : ChipTone.warning),
                            icon: verificationStatus == 'Approved'
                                ? Icons.verified_outlined
                                : (verificationStatus == 'Rejected'
                                    ? Icons.cancel_outlined
                                    : Icons.hourglass_top_rounded),
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
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.successIcon,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('تُبلغ مباشرة',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.successText)),
                          const Spacer(),
                          Text(
                            'آخر تحديث: ${DateFormat('HH:mm').format(DateTime.now())}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
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
                  const SectionLabel('قائمة الأدوية'),
                  const Text('مخزون اليوم',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => QuickBarcodeScannerSheet.show(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlueBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const _AddMedSheet(),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlueBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const _CsvImportSheet(),
                      ),
                      icon: const Icon(Icons.upload_file_outlined, size: 16),
                      label: const Text('استيراد CSV'),
                    ),
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
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

// ─── Medication card with availability actions ────────────────────────────────
class _MedCard extends HookConsumerWidget {
  final PharmacyInventoryItemDto item;
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
              item.id,
              SetAvailabilityRequest(quantity: qty, price: item.price),
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
                    Text(item.medicationName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(item.price.toArabicPrice(),
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
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20, color: AppColors.textSecondary),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'إدارة الصنف',
                onPressed: () => _showItemSettingsSheet(context, ref, item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'حذف الصنف',
                onPressed: () => _confirmDeleteItem(context, ref, item),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'الكمية بالمخزون: ${item.quantity} وحدة · ${DateFormat('HH:mm').format((item.lastUpdatedAt ?? item.createdAt).toLocal())}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: const Size(28, 26),
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppColors.hairline),
                    ),
                    icon: const Icon(Icons.remove, size: 14),
                    label: const Text('بيع كاونتر (-1)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                    onPressed: (busy.value || item.quantity <= 0)
                        ? null
                        : () => setAvailability(item.quantity - 1),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: const Size(28, 26),
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppColors.hairline),
                    ),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('+1', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                    onPressed: busy.value ? null : () => setAvailability(item.quantity + 1),
                  ),
                ],
              ),
            ],
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

void _showItemSettingsSheet(
    BuildContext context, WidgetRef ref, PharmacyInventoryItemDto item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _ItemSettingsModal(item: item),
  );
}

class _ItemSettingsModal extends HookConsumerWidget {
  final PharmacyInventoryItemDto item;
  const _ItemSettingsModal({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = useState(item.quantity);
    final priceCtrl = useTextEditingController(text: item.price.toStringAsFixed(2));
    final isSaving = useState(false);
    final isDeleting = useState(false);

    Future<void> save() async {
      final parsedPrice = double.tryParse(
              priceCtrl.text.replaceAll('،', '.').replaceAll(',', '.').trim()) ??
          item.price;
      isSaving.value = true;
      try {
        await ref
            .read(pharmacyInventoryControllerProvider.notifier)
            .updateItem(item.id, qty.value, parsedPrice);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث بيانات الصنف بنجاح.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    Future<void> delete() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('حذف الصنف من المخزون'),
          content: Text(
              'هل أنت متأكد من حذف "${item.medicationName}"؟ لن يؤثر الحذف على سجلات المبيعات أو الحجوزات السابقة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      isDeleting.value = true;
      try {
        await ref
            .read(pharmacyInventoryControllerProvider.notifier)
            .deleteItem(item.id);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الصنف من المخزون.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      } finally {
        isDeleting.value = false;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
                      item.medicationName,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    const Text('إدارة الصنف والمخزون',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('الكمية المتوفرة',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: qty.value > 0 ? () => qty.value-- : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 14),
              Container(
                width: 72,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Text(
                  '${qty.value}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              IconButton.filledTonal(
                onPressed: () => qty.value++,
                icon: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => qty.value += 10,
                child: const Text('+10'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('السعر (ج.م)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: priceCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'مثال: 45.50',
              suffixText: 'ج.م',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (isSaving.value || isDeleting.value) ? null : delete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('حذف الصنف'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side:
                        const BorderSide(color: AppColors.danger, width: 1.2),
                    minimumSize: const Size(0, 46),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (isSaving.value || isDeleting.value) ? null : save,
                  icon: isSaving.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('حفظ التعديلات'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 46),
                  ),
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
                Icon(icon, size: 14, color: selectedFg),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? selectedFg : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add medication bottom sheet (mockup: إضافة دواء) ─────────────────────────
class _AddMedSheet extends HookConsumerWidget {
  const _AddMedSheet();

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

    double? parseArabicDouble(String? raw) {
      if (raw == null) return null;
      var s = raw.trim();
      if (s.isEmpty) return null;
      const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      for (int i = 0; i < arabicDigits.length; i++) {
        s = s.replaceAll(arabicDigits[i], '$i');
      }
      s = s.replaceAll('،', '.').replaceAll(',', '.');
      return double.tryParse(s);
    }

    int? parseArabicInt(String? raw) {
      if (raw == null) return null;
      var s = raw.trim();
      if (s.isEmpty) return null;
      const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      for (int i = 0; i < arabicDigits.length; i++) {
        s = s.replaceAll(arabicDigits[i], '$i');
      }
      return int.tryParse(s);
    }

    Future<void> save() async {
      if (!formKey.currentState!.validate()) return;
      submitting.value = true;
      final qty = parseArabicInt(qtyCtrl.text.trim()) ?? availability.value;
      final strength = strengthCtrl.text.trim();
      final name = strength.isEmpty
          ? nameCtrl.text.trim()
          : '${nameCtrl.text.trim()} $strength';
      final price = parseArabicDouble(priceCtrl.text) ?? 0.0;
      try {
        await ref.read(pharmacyInventoryControllerProvider.notifier).addItem(
              name,
              price,
              quantity: qty,
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

    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                        labelText: 'التركيز (اختياري)', hintText: '500 مجم'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'السعر (ج.م)', hintText: '28.50'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final parsed = parseArabicDouble(v);
                      if (parsed == null || parsed < 0) return 'رقم غير صحيح';
                      if (parsed > 10000000) return 'الحد الأقصى 10,000,000 ج.م';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية المتوفرة'),
              onChanged: (v) {
                final parsed = parseArabicInt(v);
                if (parsed == null) return;
                availability.value = parsed.clamp(0, 100000);
              },
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
                    onTap: () {
                      availability.value = 10;
                      qtyCtrl.text = '10';
                    },
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
                    onTap: () {
                      availability.value = 3;
                      qtyCtrl.text = '3';
                    },
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
                    onTap: () {
                      availability.value = 0;
                      qtyCtrl.text = '0';
                    },
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
            FilledButton(
              onPressed: submitting.value ? null : save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand900,
                minimumSize: const Size.fromHeight(48),
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
          ],
        ),
        ),
      ),
    );
  }
}

class _CsvImportSheet extends HookConsumerWidget {
  const _CsvImportSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final csvCtrl = useTextEditingController(
      text: 'MedicationName,Price,Status\nPanadol,25,InStock\n',
    );
    final submitting = useState(false);

    Future<void> import() async {
      submitting.value = true;
      try {
        final file = MultipartFile.fromString(
          csvCtrl.text,
          filename: 'inventory.csv',
        );
        final result =
            await ref.read(apiClientProvider).bulkImportInventory(file);
        ref.invalidate(pharmacyInventoryControllerProvider);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'اتضاف ${result.importedCount} · اتنحّى ${result.skippedCount}',
              ),
            ),
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

    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const SectionLabel('استيراد مخزون'),
            const SizedBox(height: 8),
            const Text(
              'الصيغة: MedicationName,Price,Status — Status = InStock أو OutOfStock',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: csvCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'CSV',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: submitting.value ? null : import,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(submitting.value ? 'جارٍ الاستيراد…' : 'استيراد'),
            ),
          ],
        ),
      ),
    );
  }
}


void _confirmDeleteItem(
    BuildContext context, WidgetRef ref, PharmacyInventoryItemDto item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: const Text('حذف الصنف من المخزون'),
      content: Text(
          'هل تريد بالتأكيد حذف "${item.medicationName}" نهائياً من قائمة الأدوية بالصيدلية؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dCtx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(dCtx, true),
          child: const Text('حذف الصنف'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await ref
          .read(pharmacyInventoryControllerProvider.notifier)
          .deleteItem(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف "${item.medicationName}" بنجاح من قائمة الصيدلية.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeApiError(e))),
        );
      }
    }
  }
}