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
import 'package:nawakes_mobile/features/search/presentation/widgets/eda_price_badge.dart';
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
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:nawakes_mobile/features/onboarding/presentation/patient_onboarding_sheet.dart';
import 'package:nawakes_mobile/features/search/presentation/widgets/mandatory_location_prompt_dialog.dart';
import 'package:nawakes_mobile/core/services/search_history_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:nawakes_mobile/core/utils/arabic_digits.dart';

String _formatDistance(double km) {
  if (km <= 0) return 'قريب جدًا';
  if (km < 1) return '${ArabicDigits.convert((km * 1000).round())} م';
  return '${ArabicDigits.convert(km.toStringAsFixed(1), formatDecimals: true)} كم';
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
    final searchHistory = ref.watch(searchHistoryProvider);
    final isFocused = useState(false);
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

    useEffect(() {
      void onFocusChange() {
        isFocused.value = focusNode.hasFocus;
      }
      focusNode.addListener(onFocusChange);
      return () => focusNode.removeListener(onFocusChange);
    }, [focusNode]);

    Future<void> doSearch(String query) async {
      if (query.trim().length < 2) return;
      focusNode.unfocus();
      ref.read(searchHistoryProvider.notifier).addQuery(query);

      // Enforce GPS location via Mandatory Location Prompt ("سماح")
      final hasLocationPermission = await ensureLocationPermission(context, ref);
      if (!hasLocationPermission) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('البحث متوقف: يجب منح صلاحية الموقع (GPS) لعرض الصيدليات الأقرب إليك بدقة.'),
              backgroundColor: AppColors.danger,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // ── Check multi-medication query (e.g. "بنادول و كتافلام", "أوجمنتين، كونكور") ──
      var tokens = ArabicMedicationMapper.splitMedications(query);
      if (tokens.length < 2) {
        final delimiterRegex = RegExp(r'\s+(?:و|\+|مع|and)\s+|[,\u060C+]+', caseSensitive: false);
        final manualParts = query
            .split(delimiterRegex)
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s.length >= 2)
            .toList();
        if (manualParts.length >= 2) {
          tokens = manualParts;
        }
      }

      if (tokens.length >= 2) {
        suggestions.value = [];
        final api = ref.read(apiClientProvider);
        final List<BatchSearchItemDto> batchItems = [];
        for (final token in tokens) {
          final resolved = await ArabicMedicationMapper.resolveSingleMedication(token, api);
          final finalName = resolved.isNotEmpty ? resolved : token;
          batchItems.add(BatchSearchItemDto(
            medication: finalName,
            quantity: 1,
          ));
        }

        if (context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BatchSearchResultsScreen(items: batchItems),
          ));
        }
        return;
      }

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
        if (context.mounted) {
          PatientOnboardingSheet.showIfFirstTime(context, ref);
        }
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

        body: Stack(
        children: [
          SafeArea(
            bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const NawaqssLogo(size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'أهلاً بيك 👋',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'أي دوا ناقص؟',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: context.textColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.notifications_none_rounded,
                        size: 24, color: context.textColor),
                    onPressed: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Search pill with blue round action ───────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
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
                            style: TextStyle(fontSize: 13.5),
                            decoration: const InputDecoration(
                              hintText: 'دوّر باسم الدوا…',
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

                  // ── Google-Style Suggestions / Search History Dropdown ──
                  if (suggestions.value.isNotEmpty || (isFocused.value && searchHistory.isNotEmpty)) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (suggestions.value.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.fromLTRB(14, 10, 14, 4),
                              child: Text(
                                'اقتراحات الأدوية',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            ...suggestions.value.map((s) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.search_rounded,
                                      size: 18, color: AppColors.primary),
                                  title: Text(s,
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                  trailing: const Icon(
                                      Icons.north_west_rounded,
                                      size: 14,
                                      color: AppColors.textHint),
                                  onTap: () {
                                    searchCtrl.text = s;
                                    doSearch(s);
                                  },
                                )),
                          ] else if (isFocused.value && searchHistory.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'عمليات البحث السابقة',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => ref
                                        .read(searchHistoryProvider.notifier)
                                        .clearAll(),
                                    child: const Text('مسح السجل',
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 11,
                                            color: AppColors.danger)),
                                  ),
                                ],
                              ),
                            ),
                            ...searchHistory.take(5).map((q) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.history_rounded,
                                      size: 18, color: AppColors.textSecondary),
                                  title: Text(q,
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 16, color: AppColors.textHint),
                                    onPressed: () => ref
                                        .read(searchHistoryProvider.notifier)
                                        .removeQuery(q),
                                  ),
                                  onTap: () {
                                    searchCtrl.text = q;
                                    doSearch(q);
                                  },
                                )),
                          ],
                        ],
                      ),
                    ),
                  ],

                  if (hasSearched.value) ...[
                    // ── Map container (Appears only on Search) ───────────────────
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor),
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
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: context.borderColor),
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
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (searchState.isLoading) ...[
                            const SizedBox(height: 12),
                            const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  NuqousMascot.searching(height: 85),
                                  SizedBox(height: 8),
                                  Text(
                                    'نقوص بيلف على الصيدليات القريبة يدورلك عليه...',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: NawaqsColors.tealDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            ...List.generate(
                                2,
                                (_) => const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: SizedBox(
                                          height: 58, child: _SkeletonRow()),
                                    ))
                          ] else if (results == null || results.isEmpty) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const NuqousMascot.worried(height: 85),
                                  const SizedBox(height: 8),
                                  const NawaqssShortageSticker(
                                    label: 'ناقص وغير متوفر حالياً!',
                                    fontSize: 12.5,
                                    enableTilt: true,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'الدواء ناقص في الصيدليات المحيطة بنطاق ${radius.value.round()} كم.',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
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
                    // ── Brand Kit Page 15: Big Prescription Scan Hero Banner ──
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [NawaqsColors.teal, NawaqsColors.tealDark],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: NawaqsColors.teal.withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'صوّر روشتتك',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'وتلاقيلك الأدوية في ثواني',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  key: const ValueKey('home_hero_scan_button'),
                                  onPressed: () => PrescriptionSourceSheet.show(
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
                                  style: FilledButton.styleFrom(
                                    backgroundColor: NawaqsColors.coral,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.camera_alt_rounded, size: 17),
                                  label: const Text(
                                    'ابدأ المسح',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const NuqousMascot(height: 94, mood: NuqousMood.welcome),
                        ],
                      ),
                    ),

                    // ── Brand Kit Page 15: Recent Searches (آخر بحث) ──
                    if (searchHistory.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'آخر بحث',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: context.textColor,
                              ),
                            ),
                            TextButton(
                              onPressed: () => ref.read(searchHistoryProvider.notifier).clearAll(),
                              child: const Text(
                                'مسح السجل',
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: searchHistory.map((item) => Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: _buildRecentSearchChip(
                              medName: item,
                              onTap: () {
                                searchCtrl.text = item;
                                doSearch(item);
                              },
                              onDelete: () => ref.read(searchHistoryProvider.notifier).removeQuery(item),
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'أدوية شائعة البحث',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: context.textColor,
                              ),
                            ),
                            NawaqssStatusPill(status: 'متاح'),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildRecentSearchChip(
                              medName: 'أوجمنتين 1 جم',
                              onTap: () {
                                searchCtrl.text = 'أوجمنتين 1 جم';
                                doSearch('أوجمنتين 1 جم');
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildRecentSearchChip(
                              medName: 'كونكور 5 مجم',
                              onTap: () {
                                searchCtrl.text = 'كونكور 5 مجم';
                                doSearch('كونكور 5 مجم');
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildRecentSearchChip(
                              medName: 'بانادول إكسترا',
                              onTap: () {
                                searchCtrl.text = 'بانادول إكسترا';
                                doSearch('بانادول إكسترا');
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

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
                style: TextStyle(
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
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                        '${item.addressLine} · ${_timeAgo(item.lastUpdatedAt)}',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.status == 'InStock')
                          const NawaqssFoundSticker(
                            label: 'لقيناه!',
                            fontSize: 10.5,
                            enableTilt: true,
                          )
                        else if (item.status == 'Limited')
                          const NawaqssSingleMedSticker(
                            label: 'كمية محدودة',
                            fontSize: 10,
                            enableTilt: true,
                          )
                        else
                          const NawaqssShortageSticker(
                            label: 'ناقص وغير متاح',
                            fontSize: 10,
                            enableTilt: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    EdaPriceBadge(
                      officialEdaPriceEgp: item.officialEdaPriceEgp,
                      priceVariancePercent: item.priceVariancePercent,
                      isEdaPriceVerified: item.isEdaPriceVerified,
                      edaPriceBadgeText: item.edaPriceBadgeText,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatDistance(item.distanceKm),
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(item.price.toArabicPrice(),
                      style: TextStyle(
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

Widget _buildRecentSearchChip({
  required String medName,
  String? timeAgo,
  int? pharmacyCount,
  required VoidCallback onTap,
  VoidCallback? onDelete,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? const Color(0xFF142730) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: NawaqsColors.mint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history_rounded, size: 16, color: NawaqsColors.teal),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                medName,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.isDarkMode ? const Color(0xFFFBF7F0) : NawaqsColors.ink,
                ),
              ),
              Text(
                timeAgo != null
                    ? (pharmacyCount != null ? '$timeAgo · $pharmacyCount صيدليات' : '$timeAgo · بحث سابق')
                    : (pharmacyCount != null ? '$pharmacyCount صيدليات متاحة' : 'بحث سابق'),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close_rounded, size: 14, color: AppColors.textHint),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
