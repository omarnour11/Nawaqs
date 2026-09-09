import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart' show apiClientProvider;
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/search/presentation/search_controller.dart' as sc;
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:nawakes_mobile/features/search/presentation/all_results_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/shortage_sos_card.dart';
import 'package:nawakes_mobile/features/search/presentation/pharmacy_details_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ─── Light clinical map style ────────────────────────────────────────────────
const _kMapStyle = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#eef0ee"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#cfe6f5"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#f6f2e8"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#f3eedd"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a94a0"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#4b5563"}]}
]
''';

// ─── Numbered map pins (badge = live unit count, color = availability) ───────
final Map<String, BitmapDescriptor> _pinCache = {};

Future<BitmapDescriptor> _buildCountPin({required int count, required bool inStock}) async {
  final key = '$count|$inStock';
  if (_pinCache.containsKey(key)) return _pinCache[key]!;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const w = 44.0, h = 56.0;

  final pinColor = inStock ? AppColors.successIcon : AppColors.warningIcon;

  // soft shadow under the tip
  canvas.drawCircle(
      const Offset(w / 2, h - 5), 5,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

  // teardrop pin
  final path = Path()
    ..addOval(const Rect.fromLTWH(2, 2, w - 4, w - 4))
    ..moveTo(w * 0.28, w * 0.70)
    ..quadraticBezierTo(w / 2, h, w / 2, h)
    ..quadraticBezierTo(w / 2, h, w * 0.72, w * 0.70)
    ..close();
  canvas.drawPath(path, Paint()..color = pinColor);
  canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);

  final tp = TextPainter(
    text: TextSpan(
        text: '$count',
        style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset((w - tp.width) / 2, (w - tp.height) / 2 + 1));

  final picture = recorder.endRecording();
  final img = await picture.toImage(w.toInt(), h.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final descriptor = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  _pinCache[key] = descriptor;
  return descriptor;
}

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
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchCtrl = useTextEditingController();
    final focusNode = useFocusNode();
    final searchState = ref.watch(sc.searchControllerProvider);
    final hasSearched = useState(false);
    final radius = useState<double>(10.0);
    final suggestions = useState<List<String>>([]);

    final mapController = useState<GoogleMapController?>(null);
    final markers = useState<Set<Marker>>({});

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

    // Build numbered pins when results arrive + fit camera
    ref.listen<AsyncValue<SearchMedicationResponse?>>(
      sc.searchControllerProvider,
      (prev, next) {
        final data = next.value;
        if (!next.hasValue || data == null || data.results.isEmpty) {
          markers.value = {};
          return;
        }

        Future.wait(data.results.map((r) => _buildCountPin(
              count: r.status == 'InStock'
                  ? (r.quantity > 0 ? r.quantity : 1)
                  : 0,
              inStock: r.status == 'InStock',
            ))).then((icons) {
          final newMarkers = <Marker>{};
          for (var i = 0; i < data.results.length; i++) {
            final item = data.results[i];
            newMarkers.add(Marker(
              markerId: MarkerId(item.inventoryItemId),
              position: LatLng(item.latitude, item.longitude),
              icon: icons[i],
              anchor: const Offset(0.5, 1.0),
              onTap: () => context.push('/pharmacy-details',
                  extra: PharmacyDetailsArgs(item: item)),
            ));
          }
          markers.value = newMarkers;

          if (data.results.length > 1) {
            final lats = data.results.map((r) => r.latitude);
            final lngs = data.results.map((r) => r.longitude);
            mapController.value?.animateCamera(CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(lats.reduce((a, b) => a < b ? a : b),
                    lngs.reduce((a, b) => a < b ? a : b)),
                northeast: LatLng(lats.reduce((a, b) => a > b ? a : b),
                    lngs.reduce((a, b) => a > b ? a : b)),
              ),
              60,
            ));
          } else {
            final r = data.results.first;
            mapController.value?.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(r.latitude, r.longitude), 14),
            );
          }
        });
      },
    );

    final results = searchState.value?.results;

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
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
                              markers.value = {};
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded,
                                  size: 16, color: AppColors.textMuted),
                            ),
                          ),
                        const SizedBox(width: 6),
                        Material(
                          color: AppColors.accentBlue,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => doSearch(searchCtrl.text),
                            child: const SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(Icons.north_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Suggestions
                  if (suggestions.value.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        children: suggestions.value
                            .map((s) => ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  leading: const Icon(Icons.medication_rounded,
                                      size: 17, color: AppColors.accentBlue),
                                  title: Text(s,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  onTap: () {
                                    searchCtrl.text = s;
                                    suggestions.value = [];
                                    doSearch(s);
                                  },
                                ))
                            .toList(),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // ── Map card ───────────────────────────────────────────────
                  Container(
                    height: 210,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: GoogleMap(
                      style: _kMapStyle,
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(30.0444, 31.2357),
                        zoom: 12,
                      ),
                      markers: markers.value,
                      mapToolbarEnabled: false,
                      zoomControlsEnabled: false,
                      buildingsEnabled: false,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      onMapCreated: (c) => mapController.value = c,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Results card ───────────────────────────────────────────
                  if (!hasSearched.value)
                    _IdleCard(
                      onSample: () {
                        searchCtrl.text = 'Panadol';
                        doSearch('Panadol');
                      },
                    )
                  else
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
                ],
              ),
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
                  Text('EGP ${item.price.toStringAsFixed(0)}',
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

// ─── Idle card ────────────────────────────────────────────────────────────────
class _IdleCard extends StatelessWidget {
  final VoidCallback onSample;
  const _IdleCard({required this.onSample});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('التوفر القريب'),
          const SizedBox(height: 6),
          const Text('ابحث عن دواء وشوف مين متوفر دلوقتي',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'اكتب اسم الدواء، شوف أقرب صيدلية عندها مخزون حقيقي، واحجز تصريح استلام مدته ساعتين.',
            style: TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary, height: 1.55),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onSample,
            icon: const Icon(Icons.search_rounded, size: 16),
            label: const Text('جرب: Panadol'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 38),
              side: const BorderSide(color: AppColors.hairline),
            ),
          ),
        ],
      ),
    );
  }
}
