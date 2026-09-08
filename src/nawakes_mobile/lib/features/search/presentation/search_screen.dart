import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/search/presentation/search_controller.dart' as sc;
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ─── Map Style JSON ──────────────────────────────────────────────────────────
const _kMapStyle = '''
[
  {"featureType":"all","elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
  {"featureType":"all","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"all","elementType":"labels.text.fill","stylers":[{"color":"#64748b"}]},
  {"featureType":"all","elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#0f172a"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#0f172a"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.medical","stylers":[{"visibility":"simplified"}]},
  {"featureType":"poi.medical","elementType":"labels.icon","stylers":[{"color":"#0f766e"},{"visibility":"on"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#e2e8f0"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#cbd5e1"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#94a3b8"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#94a3b8"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#bfdbfe"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#60a5fa"}]}
]
''';


// ─── Custom Canvas Marker Builder ────────────────────────────────────────────
Future<BitmapDescriptor> _buildCanvasMarker({
  required Color pinColor,
  required Color crossColor,
  int size = 96,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final w = size.toDouble();

  // Pin body paint
  final bodyPaint = Paint()..color = pinColor;
  final strokePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.05;

  // Shadow
  final shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.18)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

  final pinPath = _buildPinPath(w);

  // Draw shadow slightly offset
  canvas.save();
  canvas.translate(w * 0.04, w * 0.05);
  canvas.drawPath(pinPath, shadowPaint);
  canvas.restore();

  // Draw pin body
  canvas.drawPath(pinPath, bodyPaint);
  // White stroke border
  canvas.drawPath(pinPath, strokePaint);

  // Draw white cross inside circle
  final cx = w / 2;
  final cy = w * 0.36;
  final arm = w * 0.13;
  final thick = w * 0.075;
  final crossPaint = Paint()
    ..color = crossColor
    ..strokeCap = StrokeCap.round
    ..strokeWidth = thick
    ..style = PaintingStyle.stroke;
  canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), crossPaint);
  canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), crossPaint);

  final picture = recorder.endRecording();
  final img = await picture.toImage(size, (size * 1.3).round());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

Path _buildPinPath(double w) {
  final path = Path();
  final r = w * 0.38; // circle radius
  final cx = w / 2;
  final cy = w * 0.36;
  // Circle on top
  path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
  // Teardrop tip pointing down
  path.moveTo(cx - w * 0.1, cy + r * 0.7);
  path.quadraticBezierTo(cx, w * 1.15, cx, w * 1.15);
  path.quadraticBezierTo(cx, w * 1.15, cx + w * 0.1, cy + r * 0.7);
  path.close();
  return path;
}

// ─── Distance Formatter ─────────────────────────────────────────────────────
String _formatDistance(double distanceKm) {
  if (distanceKm <= 0.0) return 'Nearby';
  if (distanceKm < 1.0) {
    final meters = (distanceKm * 1000).round();
    return '$meters m away';
  }
  return '${distanceKm.toStringAsFixed(1)} km away';
}

// ─── Main Screen ─────────────────────────────────────────────────────────────
class SearchScreen extends HookConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchState = ref.watch(sc.searchControllerProvider);
    final isLocating = useState(false);
    final hasSearched = useState(false);

    // Map controller & markers
    final mapController = useState<GoogleMapController?>(null);
    final inStockMarker = useState<BitmapDescriptor?>(null);
    final outOfStockMarker = useState<BitmapDescriptor?>(null);

    // Build canvas markers once
    useEffect(() {
      _buildCanvasMarker(pinColor: const Color(0xFF0F766E), crossColor: Colors.white)
          .then((b) => inStockMarker.value = b);
      _buildCanvasMarker(pinColor: const Color(0xFFDC2626), crossColor: Colors.white)
          .then((b) => outOfStockMarker.value = b);
      return null;
    }, const []);

    Future<void> doSearch(String query) async {
      if (query.trim().length < 2) return;
      isLocating.value = true;
      hasSearched.value = true;
      // GPS resolution is now handled inside SearchController.search()
      ref.read(sc.searchControllerProvider.notifier).search(query.trim()).then((_) {
        isLocating.value = false;
      }).catchError((e) {
        isLocating.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Search error: $e'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Find Medications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks_rounded),
            tooltip: 'My Reservations',
            onPressed: () => context.push('/my-reservations'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: doSearch,
                decoration: InputDecoration(
                  hintText: 'Search medication e.g., Panadol, Amoxicillin',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
                  prefixIcon: isLocating.value
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                        )
                      : const Icon(Icons.search_rounded, color: AppColors.primary),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppColors.textHint),
                          onPressed: () {
                            searchController.clear();
                            hasSearched.value = false;
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                          tooltip: 'Detect My Location & Search',
                          onPressed: () => doSearch(searchController.text),
                        ),
                      ),
                    ],
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // ── Results area ────────────────────────────────────────────────
          Expanded(
            child: searchState.when(
              data: (data) {
                if (!hasSearched.value || data == null) return _IdleState();
                if (data.results.isEmpty) return _NoResults(query: searchController.text);

                final inIcon = inStockMarker.value ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
                final outIcon = outOfStockMarker.value ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

                final markers = data.results.map((item) => Marker(
                      markerId: MarkerId(item.pharmacyId),
                      position: LatLng(item.latitude, item.longitude),
                      icon: item.status == 'InStock' ? inIcon : outIcon,
                      onTap: () => _showPharmacySheet(context, item),
                    )).toSet();

                final mapWidget = _BrandedMap(
                  markers: markers,
                  initialTarget: LatLng(data.results.first.latitude, data.results.first.longitude),
                  onControllerReady: (c) => mapController.value = c,
                );

                final listWidget = RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => doSearch(searchController.text),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: data.results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _PharmacyResultCard(item: data.results[i]),
                  ),
                );

                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return Row(
                        children: [
                          Expanded(flex: 4, child: listWidget),
                          Expanded(flex: 6, child: mapWidget),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        SizedBox(height: 350, width: double.infinity, child: mapWidget),
                        Expanded(child: listWidget),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 52),
                      const SizedBox(height: 16),
                      Text('Search failed', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(e.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => doSearch(searchController.text),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── In-app modal bottom sheet (no external map links) ──────────────────────
  void _showPharmacySheet(BuildContext context, PharmacySearchResultDto item) {
    final inStock = item.status == 'InStock';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PharmacyBottomSheet(item: item),
    );
  }
}

// ─── Branded Google Map Widget ────────────────────────────────────────────────
class _BrandedMap extends StatelessWidget {
  final Set<Marker> markers;
  final LatLng initialTarget;
  final void Function(GoogleMapController) onControllerReady;

  const _BrandedMap({
    required this.markers,
    required this.initialTarget,
    required this.onControllerReady,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14.0),
      markers: markers,
      // ── Fully In-App: disable external toolbar ──
      mapToolbarEnabled: false,
      // ── Navigation controls ──
      zoomControlsEnabled: true,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
      // ── Location layer ──
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      // ── Apply branded style on map creation ──
      onMapCreated: (controller) {
        controller.setMapStyle(_kMapStyle);
        onControllerReady(controller);
      },
    );
  }
}

// ─── Pharmacy Modal Bottom Sheet ─────────────────────────────────────────────
class _PharmacyBottomSheet extends StatelessWidget {
  final PharmacySearchResultDto item;
  const _PharmacyBottomSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final inStock = item.status == 'InStock';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: inStock ? AppColors.successSurface : AppColors.dangerSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.local_pharmacy_rounded,
                        color: inStock ? AppColors.success : AppColors.danger,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.pharmacyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                              const SizedBox(width: 3),
                              Text(
                                item.trustScore.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 3),
                              Text(
                                _formatDistance(item.distanceKm),
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 16),

                // Status + price row
                Row(
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: inStock ? AppColors.successSurface : AppColors.dangerSurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            inStock ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 14,
                            color: inStock ? AppColors.success : AppColors.danger,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            inStock ? 'In Stock' : 'Out of Stock',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: inStock ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Price', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                        Text(
                          'EGP ${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Reserve button — navigates in-app
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: inStock
                        ? () {
                            Navigator.of(context).pop();
                            context.push('/pharmacy-details', extra: item);
                          }
                        : null,
                    icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                    label: Text(inStock ? 'Reserve Medication' : 'Unavailable'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.border,
                      disabledForegroundColor: AppColors.textHint,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pharmacy List Card ───────────────────────────────────────────────────────
class _PharmacyResultCard extends StatelessWidget {
  final PharmacySearchResultDto item;
  const _PharmacyResultCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final inStock = item.status == 'InStock';
    return Card(
      child: InkWell(
        onTap: () => context.push('/pharmacy-details', extra: item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: inStock ? AppColors.successSurface : AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_pharmacy_rounded,
                  color: inStock ? AppColors.success : AppColors.danger,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.pharmacyName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(_formatDistance(item.distanceKm),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(width: 10),
                        const Icon(Icons.star_rounded, size: 13, color: AppColors.accent),
                        const SizedBox(width: 3),
                        Text(item.trustScore.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: inStock ? AppColors.successSurface : AppColors.dangerSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            inStock ? '✓ In Stock' : '✕ Out of Stock',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: inStock ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'EGP ${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Idle State ───────────────────────────────────────────────────────────────
class _IdleState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
            child: const Icon(Icons.search_rounded, color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: 24),
          Text('Find Your Medication',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          const Text(
            "Search for any medication and we'll show you the nearest pharmacies with real-time stock availability.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.6, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.my_location_rounded, color: AppColors.accentDark, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap the location icon to detect your GPS position and search nearby.',
                    style: TextStyle(fontSize: 13, color: AppColors.accentDark, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── No Results ───────────────────────────────────────────────────────────────
class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 72, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text('No results for "$query"', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'No nearby pharmacies have this medication in stock. Try a different name or expand your search radius.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
