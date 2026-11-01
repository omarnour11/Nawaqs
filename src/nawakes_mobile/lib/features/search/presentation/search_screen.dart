import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:nawakes_mobile/core/map/nawaqs_map.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart'
    show describeApiError;
import 'package:nawakes_mobile/features/search/presentation/search_controller.dart' as sc;
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:nawakes_mobile/features/search/presentation/all_results_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/shortage_sos_card.dart';
import 'package:nawakes_mobile/features/search/presentation/pharmacy_details_screen.dart';
import 'package:nawakes_mobile/core/services/voice_search_service.dart';
import 'package:nawakes_mobile/core/services/arabic_medication_mapper.dart';
import 'package:nawakes_mobile/core/ui/voice_recording_overlay.dart';
import 'package:nawakes_mobile/features/search/presentation/voice_confirm_sheet.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_source_sheet.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_basket_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/batch_search_results_screen.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/features/search/presentation/medication_equivalents_card.dart';
import 'package:nawakes_mobile/features/search/presentation/prescription_scanner_hud_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/widgets/home_catalog_view.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

String _formatDistance(double km) {
  if (km <= 0) return 'قريب جدًا';
  if (km < 1) return '${(km * 1000).round()} متر';
  return '${km.toStringAsFixed(1)} كم';
}

String _timeAgo(DateTime utc) {
  final diff = DateTime.now().toUtc().difference(utc);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'تحديث من ${diff.inMinutes} دقايق';
  return 'تحديث من ${diff.inHours} ساعة';
}

/// Availability chip from quantity: 0/unavailable → danger, 1–4 → limited, 5+ → available.
(ChipTone, String) availabilityOf(PharmacySearchResultDto r) {
  if (r.status != 'InStock') return (ChipTone.danger, 'غير متاح');
  final q = r.quantity;
  if (q <= 4) return (ChipTone.warning, 'محدود · $q وحدة');
  return (ChipTone.success, 'متاح');
}

// ─── Main Screen ─────────────────────────────────────────────────────────────
class SearchScreen extends HookConsumerWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchCtrl = useTextEditingController(text: initialQuery ?? '');
    final focusNode = useFocusNode();
    final searchState = ref.watch(sc.searchControllerProvider);
    final hasSearched = useState(initialQuery != null && initialQuery!.trim().length >= 2);
    final radius = useState<double>(10.0);
    final suggestions = useState<List<String>>([]);
    final isListening = useState(false);
    final isProcessingVoice = useState(false);
    final speechTranscript = useState<String>('');
    final voice = useMemoized(VoiceSearchService.new, const []);

    final mapPins = useState<List<NawaqsMapPin>>([]);

    // Debounced autocomplete
    useEffect(() {
      Timer? debounce;
      void onChanged(String text) {
        debounce?.cancel();
        if (text.trim().length < 2) {
          suggestions.value = [];
          return;
        }
        debounce = Timer(const Duration(milliseconds: 350), () async {
          try {
            final result =
                await ref.read(apiClientProvider).suggestMedications(text.trim());
            suggestions.value = result;
          } catch (_) {
            suggestions.value = [];
          }
        });
      }

      searchCtrl.addListener(() => onChanged(searchCtrl.text));
      return () => debounce?.cancel();
    }, const []);

    Future<void> doSearch(String query) async {
      if (query.trim().length < 2) return;
      focusNode.unfocus();

      // Enforce GPS location
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled && context.mounted) {
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (dCtx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.location_off_rounded, color: AppColors.danger, size: 24),
                  SizedBox(width: 8),
                  Text('تفعيل خدمة الموقع (GPS)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              content: const Text(
                'لتحديد الصيدليات المتاحة حولك بدقة ومعرفة المسافة الحقيقية، يجب تفعيل خدمة الموقع الجغرافي (GPS) قبل البحث.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brand900),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('فتح إعدادات الموقع'),
                  onPressed: () {
                    Geolocator.openLocationSettings();
                    Navigator.pop(dCtx, true);
                  },
                ),
              ],
            ),
          );
          if (openSettings != true) return;
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('يجب إعطاء إذن الموقع لإظهار الصيدليات القريبة بدقة.'),
              action: SnackBarAction(
                label: 'الإعدادات',
                textColor: Colors.white,
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
          return;
        }
      } catch (_) {}

      suggestions.value = [];
      hasSearched.value = true;
      try {
        await ref.read(sc.searchControllerProvider.notifier)
            .search(query.trim(), radius: radius.value);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      }
    }

    Future<void> handleVoiceDone() async {
      if (isProcessingVoice.value) return;
      if (!isListening.value) return;

      isProcessingVoice.value = true;
      isListening.value = false;

      // Extract spoken text BEFORE resetting or stopping
      final raw = speechTranscript.value.trim().isNotEmpty
          ? speechTranscript.value.trim()
          : (voice.lastWords.trim().isNotEmpty
              ? voice.lastWords.trim()
              : searchCtrl.text.trim());

      speechTranscript.value = '';

      try {
        await voice.stop();
      } catch (_) {}

      if (raw.isEmpty) {
        isProcessingVoice.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم نتمكن من التقاط الصوت، يرجى المحاولة والتحدث بوضوح'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 1. Resolve voice input (Egyptian dialect, Arabic DB check, multiple meds)
      final segments = ArabicMedicationMapper.splitMedications(raw);
      final rawTokens = segments.isNotEmpty ? segments : [raw];

      final api = ref.read(apiClientProvider);
      final List<VoiceResolvedItem> resolvedItems = [];
      for (final seg in rawTokens) {
        final resolved = await ArabicMedicationMapper.resolveSingleMedication(seg, api);
        if (resolved.isNotEmpty) {
          resolvedItems.add(VoiceResolvedItem(
            spokenText: seg,
            resolvedName: resolved,
          ));
        }
      }

      isProcessingVoice.value = false;
      if (!context.mounted || resolvedItems.isEmpty) return;

      // 2. Show VoiceConfirmSheet (single or multiple)
      final confirmResult = await VoiceConfirmSheet.showAdvanced(
        context,
        rawSpokenText: raw,
        items: resolvedItems,
      );

      if (!context.mounted || confirmResult == null || confirmResult.isCancelled) {
        return;
      }

      if (confirmResult.isSingleSearch) {
        final medName = confirmResult.singleMedication ?? resolvedItems.first.resolvedName;
        searchCtrl.text = medName;
        doSearch(medName);
      } else if (confirmResult.isBatchSearch) {
        final batchItems = resolvedItems
            .map((e) => BatchSearchItemDto(
                  medication: e.resolvedName,
                  quantity: 1,
                ))
            .toList();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BatchSearchResultsScreen(items: batchItems),
        ));
      } else if (confirmResult.isOpenBasket) {
        final basketItems = resolvedItems
            .map((e) => PrescriptionBasketItem(
                  tradeName: e.resolvedName,
                  quantity: 1,
                ))
            .toList();
        await PrescriptionBasketScreen.show(context, items: basketItems);
      }
    }

    useEffect(() {
      if (initialQuery != null && initialQuery!.trim().length >= 2) {
        Future.microtask(() => doSearch(initialQuery!));
      }
      Future.microtask(() async {
        try {
          final serviceEnabled = await Geolocator.isLocationServiceEnabled();
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (!serviceEnabled && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تنبيه: خدمة الموقع (GPS) مغلقة — يُرجى تفعيلها لإظهار الصيدليات الأقرب إليك بدقة.'),
                duration: Duration(seconds: 4),
              ),
            );
          }
        } catch (_) {}
      });
      return null;
    }, [initialQuery]);

    ref.listen<AsyncValue<SearchMedicationResponse?>>(
      sc.searchControllerProvider,
      (prev, next) {
        final data = next.value;
        if (!next.hasValue || data == null || data.results.isEmpty) {
          mapPins.value = [];
          return;
        }

        mapPins.value = [
          for (final item in data.results)
            NawaqsMapPin(
              id: item.inventoryItemId,
              point: LatLng(item.latitude, item.longitude),
              label: item.status == 'InStock'
                  ? '${item.quantity > 0 ? item.quantity : 1}'
                  : '0',
              color: item.status == 'InStock'
                  ? AppColors.successIcon
                  : AppColors.warningIcon,
              onTap: () => context.push('/pharmacy-details',
                  extra: PharmacyDetailsArgs(item: item)),
            ),
        ];
      },
    );

    final results = searchState.value?.results;

    return PopScope(
      canPop: !isListening.value,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (isListening.value) {
          isListening.value = false;
          speechTranscript.value = '';
          try {
            voice.stop();
          } catch (_) {}
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.page,
        body: Stack(
        children: [
          SafeArea(
            bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            NawaqsTopBar(
              eyebrow: 'نواقص',
              title: 'إيجاد دواء',
              onBell: () => context.push('/notifications'),
            ),
            const ScreenSubtitle('توفر الصيدليات المباشر حوالينك'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Search pill with blue round action ───────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    padding: const EdgeInsetsDirectional.only(start: 4, end: 5),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.search_rounded,
                              size: 19, color: AppColors.textMuted),
                        ),
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            focusNode: focusNode,
                            textInputAction: TextInputAction.search,
                            onSubmitted: doSearch,
                            style: const TextStyle(fontSize: 13.5),
                            decoration: const InputDecoration(
                              hintText: 'ابحث عن دواء… مثلاً بانادول',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (searchCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              searchCtrl.clear();
                              hasSearched.value = false;
                              suggestions.value = [];
                              mapPins.value = [];
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded,
                                  size: 16, color: AppColors.textMuted),
                            ),
                          ),
                        // Microphone (Egyptian dialect voice search)
                        GestureDetector(
                          key: const ValueKey('search_mic_button'),
                          onTap: () async {
                            if (isListening.value) {
                              await handleVoiceDone();
                              return;
                            }
                            try {
                              final ok = await voice.initialize();
                              if (!ok) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('ميكروفون الجهاز غير متاح أو لم يتم منحه الإذن')),
                                  );
                                }
                                return;
                              }
                              speechTranscript.value = '';
                              isListening.value = true;
                              await voice.startListening(
                                onResult: (text) {
                                  searchCtrl.text = text;
                                  speechTranscript.value = text;
                                },
                                onDone: () => handleVoiceDone(),
                              );
                            } catch (_) {
                              isListening.value = false;
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('حدث خطأ أثناء تشغيل الميكروفون، يرجى المحاولة ثانية')),
                                );
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: isListening.value
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.mic_rounded,
                                    size: 18, color: AppColors.accentBlue),
                          ),
                        ),
                        // Photo & Camera scan (HUD Scanner)
                        GestureDetector(
                          key: const ValueKey('search_camera_scan_button'),
                          onTap: () => PrescriptionSourceSheet.show(
                            context,
                            onScanned: (result) async {
                              final raw = result.lines.join('\n');
                              await PrescriptionScannerHudScreen.start(
                                context,
                                imageFile: result.imageFile,
                                imageBytes: result.imageBytes,
                                ocrHintText: raw.isNotEmpty ? raw : null,
                              );
                            },
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.document_scanner_rounded,
                                size: 18, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Explicit Search Submit Button
                        GestureDetector(
                          key: const ValueKey('search_submit_button'),
                          onTap: () => doSearch(searchCtrl.text),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_rounded,
                                    size: 15, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'بحث',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (hasSearched.value) ...[
                    // ── Map container (Appears only on Search) ───────────────────
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: NawaqsMap(
                        pins: mapPins.value,
                        fitPins: mapPins.value.isNotEmpty,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Results card ───────────────────────────────────────────
                    Container(
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
                              const Expanded(child: SectionLabel('التوفر القريب')),
                              TextButton.icon(
                                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                                label: const Text('الرئيسية', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  searchCtrl.clear();
                                  hasSearched.value = false;
                                },
                              ),
                              const SizedBox(width: 4),
                              _FilterButton(
                                onTap: () {
                                  final order = [5.0, 10.0, 20.0];
                                  radius.value = order[
                                      (order.indexOf(radius.value) + 1) % order.length];
                                  if (hasSearched.value) doSearch(searchCtrl.text);
                                },
                                label: '${radius.value.round()} كم',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            searchState.isLoading
                                ? 'جارٍ البحث…'
                                : (results == null || results.isEmpty)
                                    ? 'مفيش نتايج'
                                    : '${results.length} صيدلية موجودة',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (searchState.isLoading)
                            ...List.generate(
                                2,
                                (_) => const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: SizedBox(
                                          height: 58, child: _SkeletonRow()),
                                    ))
                          else if (results == null || results.isEmpty) ...[
                            const Text(
                              'جرب اسم دواء تاني أو وسّع نطاق البحث.',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                  height: 1.5),
                            ),
                            const SizedBox(height: 10),
                            ShortageSosCard(medicationName: searchCtrl.text.trim()),
                            const SizedBox(height: 10),
                            _EquivalentsLoader(medicationName: searchCtrl.text.trim()),
                          ]
                          else
                            ...results.take(6).map(
                                  (r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 9),
                                    child: _PharmacyRow(item: r),
                                  ),
                                ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Toggle pills ───────────────────────────────────────────
                    Row(
                      children: [
                        const _TogglePill(label: 'قريب', active: true),
                        const SizedBox(width: 8),
                        _TogglePill(
                          label: 'كل النتايج',
                          active: false,
                          onTap: results == null || results.isEmpty
                              ? null
                              : () => context.push('/all-results',
                                  extra: AllResultsArgs(
                                    results: results,
                                    medicationName: searchCtrl.text.trim(),
                                  )),
                        ),
                      ],
                    ),
                  ] else ...[
                    // ── Home Catalog View (El-Ezaby style with Nawakes Identity) ──
                    HomeCatalogView(
                      onOpenScanner: () => PrescriptionSourceSheet.show(
                        context,
                        onScanned: (result) async {
                          final raw = result.lines.join('\n');
                          await PrescriptionScannerHudScreen.start(
                            context,
                            imageFile: result.imageFile,
                            imageBytes: result.imageBytes,
                            ocrHintText: raw.isNotEmpty ? raw : null,
                          );
                        },
                      ),
                      onSearchKeyword: (kw) {
                        searchCtrl.text = kw;
                        doSearch(kw);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      if (isListening.value)
        VoiceRecordingOverlay(
          currentTranscript: speechTranscript.value,
          onCancel: () async {
            isListening.value = false;
            speechTranscript.value = '';
            try {
              await voice.stop();
            } catch (_) {}
          },
          onDone: () => handleVoiceDone(),
        ),
    ],
  ),
),
);
  }
}

// ─── Skeleton row ─────────────────────────────────────────────────────────────
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F4),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ─── Filter button ────────────────────────────────────────────────────────────
class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;
  final String? label;
  const _FilterButton({required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_rounded, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label ?? 'فلترة',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─── Toggle pill ──────────────────────────────────────────────────────────────
class _TogglePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _TogglePill({required this.label, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.accentBlueBg : const Color(0xFFF1F2F4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.accentBlue : AppColors.textSecondary)),
      ),
    );
  }
}

// ─── Pharmacy queue row (list-row component from spec) ───────────────────────
class _PharmacyRow extends StatelessWidget {
  final PharmacySearchResultDto item;
  const _PharmacyRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final (tone, label) = availabilityOf(item);
    final (bg, fg) = switch (tone) {
      ChipTone.success => (AppColors.successBg, AppColors.successIcon),
      ChipTone.warning => (AppColors.warningBg, AppColors.warningIcon),
      ChipTone.danger => (AppColors.dangerBg, AppColors.dangerIcon),
      ChipTone.neutral => (AppColors.accentBlueBg, AppColors.accentBlue),
    };

    return Material(
      color: AppColors.fieldBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/pharmacy-details',
            extra: PharmacyDetailsArgs(item: item)),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              IconTile(Icons.storefront_outlined, bg: bg, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.pharmacyName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                        '${item.addressLine} · ${_timeAgo(item.lastUpdatedAt)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(label,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: fg)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatDistance(item.distanceKm),
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('${item.price.toStringAsFixed(0)} ج.م',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentBlue)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Equivalents loader (Phase 4) ────────────────────────────────────────────
class _EquivalentsLoader extends HookConsumerWidget {
  final String medicationName;
  const _EquivalentsLoader({required this.medicationName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = useMemoized(
      () => ref.read(apiClientProvider).getMedicationEquivalents(
            medicationName,
            30.0444, // Cairo default; refined by geolocator where available
            31.2357,
            5,
          ),
      [medicationName],
    );
    final snapshot = useFuture(future);

    if (snapshot.hasError || !snapshot.hasData) return const SizedBox.shrink();
    final response = snapshot.data!;
    if (response.availableEquivalents.isEmpty) return const SizedBox.shrink();

    return MedicationEquivalentsCard(response: response);
  }
}
