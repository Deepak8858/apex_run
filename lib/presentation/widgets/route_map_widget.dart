import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/gps_point.dart';

/// Reusable Mapbox route map widget for live tracking and activity detail views.
///
/// Supports:
/// - Live route polyline overlay
/// - Start/end markers
/// - Auto-camera framing
/// - Dark style matching ApexRun theme
class RouteMapWidget extends StatefulWidget {
  final List<GpsPoint> routePoints;
  final bool isLiveTracking;
  final bool showStartEndMarkers;
  final bool animateRoute;
  final double initialZoom;
  final EdgeInsets padding;

  const RouteMapWidget({
    super.key,
    required this.routePoints,
    this.isLiveTracking = false,
    this.showStartEndMarkers = true,
    this.animateRoute = false,
    this.initialZoom = 15.0,
    this.padding = const EdgeInsets.all(50),
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _polylineManager;
  PolylineAnnotationManager? _glowManager;
  PointAnnotationManager? _pointManager;
  Timer? _animTimer;
  int _animIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (Env.mapboxAccessToken.isEmpty) {
      return _MapPlaceholder(
        routePoints: widget.routePoints,
        isLiveTracking: widget.isLiveTracking,
      );
    }

    return MapWidget(
      key: const ValueKey('routeMap'),
      mapOptions: MapOptions(
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      ),
      styleUri: MapboxStyles.DARK,
      cameraOptions: _initialCamera(),
      onMapCreated: _onMapCreated,
    );
  }

  CameraOptions _initialCamera() {
    if (widget.routePoints.isEmpty) {
      return CameraOptions(
        center: Point(coordinates: Position(0, 0)),
        zoom: 2,
      );
    }

    final last = widget.routePoints.last;
    return CameraOptions(
      center: Point(
        coordinates: Position(last.longitude, last.latitude),
      ),
      zoom: widget.initialZoom,
    );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // Disable unnecessary interactions for cleaner UX during tracking
    if (widget.isLiveTracking) {
      await map.gestures.updateSettings(GesturesSettings(
        rotateEnabled: false,
        pitchEnabled: false,
      ));
    }

    // Create glow manager first (renders behind main line)
    _glowManager =
        await map.annotations.createPolylineAnnotationManager();
    _polylineManager =
        await map.annotations.createPolylineAnnotationManager();
    _pointManager = await map.annotations.createPointAnnotationManager();

    if (widget.animateRoute && !widget.isLiveTracking) {
      _startAnimatedDraw();
    } else {
      _drawRoute();
    }
  }

  @override
  void didUpdateWidget(covariant RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routePoints.length != oldWidget.routePoints.length) {
      _drawRoute();
      if (widget.isLiveTracking && widget.routePoints.isNotEmpty) {
        _flyToLatest();
      }
    }
  }

  /// Animate the route line drawing progressively like Strava replay
  void _startAnimatedDraw() {
    if (widget.routePoints.length < 2) return;

    _animIndex = 2;
    // Fit camera to full route first
    _fitBounds();

    // Progressively draw the route
    const stepDuration = Duration(milliseconds: 16); // ~60fps
    final totalPoints = widget.routePoints.length;
    final pointsPerFrame = math.max(1, totalPoints ~/ 120); // ~2 seconds

    _animTimer = Timer.periodic(stepDuration, (timer) {
      if (_animIndex >= totalPoints) {
        timer.cancel();
        _drawMarkers();
        return;
      }
      _animIndex = math.min(_animIndex + pointsPerFrame, totalPoints);
      _drawAnimFrame(_animIndex);
    });
  }

  /// Draw a single frame of the animation
  Future<void> _drawAnimFrame(int pointCount) async {
    if (_polylineManager == null || pointCount < 2) return;

    await _polylineManager!.deleteAll();
    await _glowManager?.deleteAll();

    final subset = widget.routePoints.sublist(0, pointCount);
    final coordinates = subset
        .map((p) => Position(p.longitude, p.latitude))
        .toList();

    // Outer glow line (wider, transparent)
    await _glowManager?.create(PolylineAnnotationOptions(
      geometry: LineString(coordinates: coordinates),
      lineColor: AppTheme.electricLime.withAlpha(60).toARGB32(),
      lineWidth: 10.0,
      lineOpacity: 0.4,
    ));

    // Main route line
    await _polylineManager!.create(PolylineAnnotationOptions(
      geometry: LineString(coordinates: coordinates),
      lineColor: AppTheme.electricLime.toARGB32(),
      lineWidth: 4.0,
      lineOpacity: 0.95,
    ));
  }

  Future<void> _drawRoute() async {
    if (_polylineManager == null || widget.routePoints.length < 2) return;

    // Clear existing annotations
    await _polylineManager!.deleteAll();
    await _glowManager?.deleteAll();
    await _pointManager?.deleteAll();

    // Draw polyline
    final coordinates = widget.routePoints
        .map((p) => Position(p.longitude, p.latitude))
        .toList();

    // Outer glow line (Strava-style neon effect)
    await _glowManager?.create(PolylineAnnotationOptions(
      geometry: LineString(coordinates: coordinates),
      lineColor: AppTheme.electricLime.withAlpha(60).toARGB32(),
      lineWidth: 10.0,
      lineOpacity: 0.4,
    ));

    // Main route line
    await _polylineManager!.create(PolylineAnnotationOptions(
      geometry: LineString(coordinates: coordinates),
      lineColor: AppTheme.electricLime.toARGB32(),
      lineWidth: 4.0,
      lineOpacity: 0.95,
    ));

    _drawMarkers();

    // Fit camera to bounds for detail view
    if (!widget.isLiveTracking && widget.routePoints.length >= 2) {
      _fitBounds();
    }
  }

  Future<void> _drawMarkers() async {
    if (_pointManager == null) return;
    await _pointManager!.deleteAll();

    // Start & end markers
    if (widget.showStartEndMarkers && widget.routePoints.length >= 2) {
      final start = widget.routePoints.first;
      final end = widget.routePoints.last;

      await _pointManager?.create(PointAnnotationOptions(
        geometry:
            Point(coordinates: Position(start.longitude, start.latitude)),
        iconSize: 1.2,
        textField: 'S',
        textSize: 12,
        textColor: AppTheme.success.toARGB32(),
      ));

      if (!widget.isLiveTracking) {
        await _pointManager?.create(PointAnnotationOptions(
          geometry:
              Point(coordinates: Position(end.longitude, end.latitude)),
          iconSize: 1.2,
          textField: 'F',
          textSize: 12,
          textColor: AppTheme.error.toARGB32(),
        ));
      }
    }
  }

  Future<void> _flyToLatest() async {
    if (_mapboxMap == null || widget.routePoints.isEmpty) return;

    final latest = widget.routePoints.last;
    await _mapboxMap!.flyTo(
      CameraOptions(
        center:
            Point(coordinates: Position(latest.longitude, latest.latitude)),
        zoom: 16.0,
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  Future<void> _fitBounds() async {
    if (_mapboxMap == null || widget.routePoints.length < 2) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in widget.routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = CoordinateBounds(
      southwest: Point(coordinates: Position(minLng, minLat)),
      northeast: Point(coordinates: Position(maxLng, maxLat)),
      infiniteBounds: false,
    );
    final camera = await _mapboxMap!.cameraForCoordinateBounds(
      bounds,
      MbxEdgeInsets(
        top: widget.padding.top,
        left: widget.padding.left,
        bottom: widget.padding.bottom,
        right: widget.padding.right,
      ),
      null, null, null, null,
    );
    _mapboxMap!.setCamera(camera);
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _polylineManager = null;
    _glowManager = null;
    _pointManager = null;
    super.dispose();
  }
}

/// Fallback placeholder when Mapbox token is not configured.
/// Shows a simple visual representation of the route.
class _MapPlaceholder extends StatelessWidget {
  final List<GpsPoint> routePoints;
  final bool isLiveTracking;

  const _MapPlaceholder({
    required this.routePoints,
    required this.isLiveTracking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Stack(
        children: [
          // Grid pattern background
          CustomPaint(
            size: ui.Size(double.infinity, double.infinity),
            painter: _GridPainter(),
          ),
          // Route line overlay
          if (routePoints.length >= 2)
            CustomPaint(
              size: ui.Size(double.infinity, double.infinity),
              painter: _RoutePainter(routePoints),
            ),
          // Label
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLiveTracking
                      ? Icons.my_location_rounded
                      : Icons.map_rounded,
                  size: 32,
                  color: AppTheme.electricLime.withOpacity(0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  isLiveTracking
                      ? '${routePoints.length} GPS points'
                      : 'Map preview',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                ),
                if (Env.mapboxAccessToken.isEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Add MAPBOX_ACCESS_TOKEN for maps',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textTertiary.withOpacity(0.5),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = Paint()
      ..color = AppTheme.surfaceLight.withOpacity(0.3)
      ..strokeWidth = 0.5;

    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoutePainter extends CustomPainter {
  final List<GpsPoint> points;
  _RoutePainter(this.points);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (points.length < 2) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final latRange = (maxLat - minLat).clamp(0.0001, double.infinity);
    final lngRange = (maxLng - minLng).clamp(0.0001, double.infinity);

    const pad = 20.0;
    final drawW = size.width - pad * 2;
    final drawH = size.height - pad * 2;

    Offset toScreen(GpsPoint p) {
      final x = pad + ((p.longitude - minLng) / lngRange) * drawW;
      final y = pad + (1 - (p.latitude - minLat) / latRange) * drawH;
      return Offset(x, y);
    }

    final path = Path()..moveTo(toScreen(points.first).dx, toScreen(points.first).dy);
    for (int i = 1; i < points.length; i++) {
      final s = toScreen(points[i]);
      path.lineTo(s.dx, s.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.electricLime.withOpacity(0.7)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Start dot
    canvas.drawCircle(toScreen(points.first), 5, Paint()..color = AppTheme.success);
    // End dot
    canvas.drawCircle(toScreen(points.last), 5, Paint()..color = AppTheme.electricLime);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.points.length != points.length;
}

/// Extension to convert Color to ARGB32 int for Mapbox annotations
extension ColorArgb on Color {
  int toARGB32() => value.toInt();
}
