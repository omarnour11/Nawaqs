import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

/// A pharmacy (or user) pin on the OpenStreetMap-backed map.
class NawaqsMapPin {
  const NawaqsMapPin({
    required this.id,
    required this.point,
    this.label,
    this.color,
    this.onTap,
  });

  final String id;
  final LatLng point;
  final String? label;
  final Color? color;
  final VoidCallback? onTap;
}

/// Free OSM map. No Google API key — the previous Maps key was invalid and
/// left the widget gray / unusable.
class NawaqsMap extends StatefulWidget {
  const NawaqsMap({
    super.key,
    this.controller,
    this.center = const LatLng(30.0444, 31.2357),
    this.zoom = 12,
    this.pins = const [],
    this.onTap,
    this.interactive = true,
    this.fitPins = false,
  });

  final MapController? controller;
  final LatLng center;
  final double zoom;
  final List<NawaqsMapPin> pins;
  final TapCallback? onTap;
  final bool interactive;
  final bool fitPins;

  @override
  State<NawaqsMap> createState() => _NawaqsMapState();
}

class _NawaqsMapState extends State<NawaqsMap> {
  late final MapController _controller;
  var _ownsController = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? MapController();
  }

  @override
  void didUpdateWidget(covariant NawaqsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fitPins && widget.pins.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitPins());
    } else if (oldWidget.center != widget.center) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _controller.move(widget.center, widget.zoom);
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _fitPins() {
    if (!mounted || widget.pins.isEmpty) return;
    try {
      if (widget.pins.length == 1) {
        _controller.move(widget.pins.first.point, 14);
        return;
      }
      final bounds = LatLngBounds.fromPoints(widget.pins.map((p) => p.point).toList());
      if (bounds.north == bounds.south && bounds.east == bounds.west) {
        _controller.move(widget.pins.first.point, 14);
        return;
      }
      _controller.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(36)),
      );
    } catch (_) {
      _controller.move(widget.pins.first.point, 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        minZoom: 5,
        maxZoom: 18,
        onTap: widget.onTap,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        backgroundColor: const Color(0xFFEEF0EE),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.nawakes.nawakes_mobile',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            for (final pin in widget.pins)
              Marker(
                key: ValueKey(pin.id),
                point: pin.point,
                width: 44,
                height: 56,
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: pin.onTap,
                  child: _PinBadge(
                    label: pin.label,
                    color: pin.color ?? AppColors.accentBlue,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PinBadge extends StatelessWidget {
  const _PinBadge({required this.color, this.label});

  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: AppShadows.mapFloat,
          ),
          child: Text(
            label == null || label!.isEmpty ? '•' : label!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(10, 8),
          painter: _PinTipPainter(color),
        ),
      ],
    );
  }
}

class _PinTipPainter extends CustomPainter {
  _PinTipPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTipPainter oldDelegate) => oldDelegate.color != color;
}
