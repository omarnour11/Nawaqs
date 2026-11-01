import 'package:flutter/material.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

class VoiceResolvedItem {
  final String spokenText;
  final String resolvedName;

  const VoiceResolvedItem({
    required this.spokenText,
    required this.resolvedName,
  });
}

enum VoiceConfirmAction {
  searchSingle,
  searchBatch,
  editBasket,
  cancel,
}

class VoiceConfirmResult {
  final VoiceConfirmAction action;
  final String? singleMedication;
  final List<VoiceResolvedItem> items;

  const VoiceConfirmResult({
    required this.action,
    this.singleMedication,
    this.items = const [],
  });

  bool get isSingleSearch => action == VoiceConfirmAction.searchSingle;
  bool get isBatchSearch => action == VoiceConfirmAction.searchBatch;
  bool get isOpenBasket => action == VoiceConfirmAction.editBasket;
  bool get isCancelled => action == VoiceConfirmAction.cancel;
}

/// Bottom sheet presented after voice recognition asking the patient
/// to confirm what was heard and resolved before launching search.
/// Handles both single medication confirmation and multiple medications (batch search).
class VoiceConfirmSheet extends StatelessWidget {
  const VoiceConfirmSheet({
    super.key,
    required this.rawSpokenText,
    required this.items,
  });

  final String rawSpokenText;
  final List<VoiceResolvedItem> items;

  /// Backward-compatible show method returning boolean.
  static Future<bool?> show(
    BuildContext context, {
    String? spokenText,
    String? resolvedName,
    String? rawSpokenText,
    List<VoiceResolvedItem>? items,
  }) async {
    final list = items ?? [
      VoiceResolvedItem(
        spokenText: spokenText ?? '',
        resolvedName: resolvedName ?? '',
      )
    ];

    final result = await showAdvanced(
      context,
      rawSpokenText: rawSpokenText ?? spokenText ?? '',
      items: list,
    );

    if (result == null || result.isCancelled) return false;
    return true;
  }

  /// Advanced show method returning rich `VoiceConfirmResult`.
  static Future<VoiceConfirmResult?> showAdvanced(
    BuildContext context, {
    required String rawSpokenText,
    required List<VoiceResolvedItem> items,
  }) {
    return showModalBottomSheet<VoiceConfirmResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceConfirmSheet(
        rawSpokenText: rawSpokenText,
        items: items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMultiple = items.length > 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (!isMultiple) _buildSingleMedicationView(context)
              else _buildMultipleMedicationsView(context),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleMedicationView(BuildContext context) {
    final item = items.isNotEmpty
        ? items.first
        : VoiceResolvedItem(spokenText: rawSpokenText, resolvedName: rawSpokenText);

    final showSpokenDiff = item.spokenText.trim().isNotEmpty &&
        item.spokenText.trim().toLowerCase() != item.resolvedName.trim().toLowerCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Medication icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.medication_rounded,
            color: AppColors.primary,
            size: 34,
          ),
        ),

        const SizedBox(height: 14),

        const Text(
          'هل تقصد هذا الدواء؟',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),

        const SizedBox(height: 8),

        // Resolved name prominently displayed
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            children: [
              Text(
                item.resolvedName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand900,
                ),
              ),
              if (showSpokenDiff) ...[
                const SizedBox(height: 4),
                Text(
                  'النطق المسموع: «${item.spokenText}»',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Actions: Search (بحث) & Cancel (إلغاء)
        Row(
          children: [
            // Cancel button
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('voice_confirm_cancel_btn'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: const BorderSide(color: AppColors.hairline),
                ),
                onPressed: () => Navigator.of(context).pop(
                  const VoiceConfirmResult(action: VoiceConfirmAction.cancel),
                ),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Search button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                key: const ValueKey('voice_confirm_search_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 1,
                ),
                icon: const Icon(Icons.search_rounded, size: 20),
                label: const Text(
                  'بحث',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(
                  VoiceConfirmResult(
                    action: VoiceConfirmAction.searchSingle,
                    singleMedication: item.resolvedName,
                    items: items,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMultipleMedicationsView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.layers_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تم التعرف على ${items.length} أدوية',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand900,
                    ),
                  ),
                  if (rawSpokenText.isNotEmpty)
                    Text(
                      'النطق المسموع: «$rawSpokenText»',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Medication items list
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final it = items[idx];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.resolvedName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand900,
                            ),
                          ),
                          if (it.spokenText.toLowerCase() != it.resolvedName.toLowerCase())
                            Text(
                              'النطق: «${it.spokenText}»',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded, color: AppColors.successIcon, size: 18),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 18),

        // Action buttons
        Row(
          children: [
            // Cancel button
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('voice_confirm_cancel_btn'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppColors.hairline),
                ),
                onPressed: () => Navigator.of(context).pop(
                  const VoiceConfirmResult(action: VoiceConfirmAction.cancel),
                ),
                child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(width: 8),

            // Edit in basket button
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('voice_confirm_edit_basket_btn'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
                label: const Text('تعديل في السلة', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => Navigator.of(context).pop(
                  VoiceConfirmResult(
                    action: VoiceConfirmAction.editBasket,
                    items: items,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Batch Search Now button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                key: const ValueKey('voice_confirm_batch_search_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
                icon: const Icon(Icons.saved_search_rounded, size: 20),
                label: Text(
                  'بحث جماعي (${items.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () => Navigator.of(context).pop(
                  VoiceConfirmResult(
                    action: VoiceConfirmAction.searchBatch,
                    items: items,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
