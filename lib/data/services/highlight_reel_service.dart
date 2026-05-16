import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/gps_point.dart';

/// Generates a 1080×1920 shareable image of a finished activity.
///
/// V1: pure-Dart canvas paint (route polyline + headline metric cards).
/// No ffmpeg, no network call to Mapbox static API — fully offline so it
/// works on cellular and never racks up image-render bills.
///
/// V2 (deferred): swap to MP4 reel via ffmpeg_kit_flutter once the
/// `ENABLE_VIDEO_REELS` feature flag ships.
class HighlightReelService {
  static final _log = AppLogger.tag('Reel');

  static const _width = 1080.0;
  static const _height = 1920.0;
  static const _bg = Color(0xFF0A0A0A);
  static const _lime = Color(0xFFCCFF00);
  static const _muted = Color(0xFFB0B0B0);

  /// Returns the saved PNG path. Caller can hand to [share].
  Future<String> generateImage(Activity activity) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, _width, _height));

    _paintBackground(canvas);
    _paintBrand(canvas);
    _paintRoute(canvas, activity.rawGpsPoints);
    _paintMetrics(canvas, activity);
    _paintFooter(canvas);

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), _height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode highlight image');
    }
    final bytes = byteData.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/apexrun_${activity.id ?? DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    _log.i('Reel rendered (${bytes.length ~/ 1024} KB)');
    return file.path;
  }

  Future<void> share(Activity activity) async {
    final path = await generateImage(activity);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'image/png')],
      text: 'Logged ${_distance(activity.distanceMeters)} on Apex Run',
    );
  }

  // ── Painters ────────────────────────────────────────────────────────

  void _paintBackground(Canvas canvas) {
    final rect = const Rect.fromLTWH(0, 0, _width, _height);
    canvas.drawRect(rect, Paint()..color = _bg);

    // Radial glow behind the brand mark.
    final glow = Paint()
      ..shader = const RadialGradient(
        center: Alignment.topCenter,
        radius: 0.8,
        colors: [
          Color(0x33CCFF00),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glow);
  }

  void _paintBrand(Canvas canvas) {
    _drawText(canvas,
        text: 'APEX RUN',
        x: 60,
        y: 90,
        size: 36,
        color: _lime,
        weight: FontWeight.w900,
        letterSpacing: 6);
    _drawText(canvas,
        text: 'PEAK PERFORMANCE',
        x: 60,
        y: 140,
        size: 18,
        color: _muted,
        weight: FontWeight.w500,
        letterSpacing: 4);
  }

  void _paintRoute(Canvas canvas, List<GpsPoint> points) {
    if (points.length < 2) return;

    // Fit route to a 920×920 area centered horizontally, vertically below header.
    const left = 80.0, top = 260.0, size = 920.0;
    double minLat = points.first.latitude, maxLat = minLat;
    double minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final spanLat = (maxLat - minLat).abs();
    final spanLng = (maxLng - minLng).abs();
    final span = (spanLat > spanLng ? spanLat : spanLng).clamp(1e-6, double.infinity);

    Offset project(GpsPoint p) {
      final dx = (p.longitude - minLng) / span;
      final dy = 1 - (p.latitude - minLat) / span;
      return Offset(left + dx * size, top + dy * size);
    }

    final path = Path();
    path.moveTo(project(points.first).dx, project(points.first).dy);
    for (final p in points.skip(1)) {
      final o = project(p);
      path.lineTo(o.dx, o.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = _lime.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final start = project(points.first);
    final end = project(points.last);
    canvas.drawCircle(start, 14, Paint()..color = Colors.white);
    canvas.drawCircle(start, 8, Paint()..color = _lime);
    canvas.drawCircle(end, 14, Paint()..color = Colors.white);
    canvas.drawCircle(end, 8, Paint()..color = const Color(0xFFFF3366));
  }

  void _paintMetrics(Canvas canvas, Activity a) {
    const top = 1320.0;
    const cellW = 320.0;
    const cellH = 200.0;
    const padding = 60.0;

    _metricCell(canvas,
        x: padding,
        y: top,
        w: cellW,
        h: cellH,
        label: 'DISTANCE',
        value: _distance(a.distanceMeters));
    _metricCell(canvas,
        x: padding + cellW + 20,
        y: top,
        w: cellW,
        h: cellH,
        label: 'TIME',
        value: _duration(a.durationSeconds));
    _metricCell(canvas,
        x: padding + (cellW + 20) * 2,
        y: top,
        w: cellW,
        h: cellH,
        label: 'PACE',
        value: _pace(a.avgPaceMinPerKm));
  }

  void _metricCell(Canvas canvas, {
    required double x,
    required double y,
    required double w,
    required double h,
    required String label,
    required String value,
  }) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(24),
    );
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF1A1A1A));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF2A2A2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _drawText(canvas,
        text: label,
        x: x + 24,
        y: y + 26,
        size: 18,
        color: _muted,
        weight: FontWeight.w600,
        letterSpacing: 3);
    _drawText(canvas,
        text: value,
        x: x + 24,
        y: y + 78,
        size: 56,
        color: Colors.white,
        weight: FontWeight.w900,
        letterSpacing: -1);
  }

  void _paintFooter(Canvas canvas) {
    _drawText(canvas,
        text: 'apexrun.app',
        x: 60,
        y: _height - 80,
        size: 22,
        color: _muted,
        weight: FontWeight.w500);
  }

  void _drawText(Canvas canvas, {
    required String text,
    required double x,
    required double y,
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _width);
    tp.paint(canvas, Offset(x, y));
  }

  // ── Formatting ──────────────────────────────────────────────────────

  String _distance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _pace(double? paceMinPerKm) {
    if (paceMinPerKm == null || paceMinPerKm <= 0 || paceMinPerKm.isInfinite) {
      return '--:--';
    }
    final total = (paceMinPerKm * 60).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
