import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/gps_point.dart';

/// Pace chart widget for activity detail view.
/// Displays pace over distance with color-coded zones.
class PaceChartWidget extends StatelessWidget {
  final List<GpsPoint> points;
  final double height;

  const PaceChartWidget({
    super.key,
    required this.points,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 3) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Not enough data for pace chart',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final paceSegments = _calculatePaceSegments();
    if (paceSegments.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _PaceChartPainter(paceSegments),
      ),
    );
  }

  List<_PaceSegment> _calculatePaceSegments() {
    final segments = <_PaceSegment>[];
    double cumulativeDistance = 0;

    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1];
      final p2 = points[i];

      final dt = p2.timestamp.difference(p1.timestamp).inSeconds;
      if (dt <= 0) continue;

      final dlat = (p2.latitude - p1.latitude) * 111320;
      final dlng = (p2.longitude - p1.longitude) *
          111320 *
          _cosine(p1.latitude * 3.14159 / 180);
      final dist = _sqrt(dlat * dlat + dlng * dlng);

      if (dist < 1) continue;

      final paceMinPerKm = (dt / 60) / (dist / 1000);
      cumulativeDistance += dist;

      if (paceMinPerKm > 0 && paceMinPerKm < 20) {
        segments.add(_PaceSegment(
          distanceMeters: cumulativeDistance,
          paceMinPerKm: paceMinPerKm,
        ));
      }
    }

    return segments;
  }

  double _cosine(double rad) {
    // Simple cosine approximation
    final x = rad % (2 * 3.14159);
    return 1 -
        (x * x) / 2 +
        (x * x * x * x) / 24 -
        (x * x * x * x * x * x) / 720;
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}

class _PaceSegment {
  final double distanceMeters;
  final double paceMinPerKm;

  _PaceSegment({
    required this.distanceMeters,
    required this.paceMinPerKm,
  });
}

class _PaceChartPainter extends CustomPainter {
  final List<_PaceSegment> segments;

  _PaceChartPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    const topPad = 10.0;
    const bottomPad = 20.0;
    const leftPad = 0.0;
    const rightPad = 0.0;

    final drawW = size.width - leftPad - rightPad;
    final drawH = size.height - topPad - bottomPad;

    final maxDist = segments.last.distanceMeters;
    final paces = segments.map((s) => s.paceMinPerKm).toList();
    paces.sort();
    final minPace = paces.first;
    final maxPace = paces[(paces.length * 0.95).floor()]; // 95th percentile
    final paceRange = (maxPace - minPace).clamp(0.5, double.infinity);

    // Draw pace line
    final path = Path();
    bool first = true;

    for (final seg in segments) {
      final x = leftPad + (seg.distanceMeters / maxDist) * drawW;
      final normalizedPace =
          ((seg.paceMinPerKm - minPace) / paceRange).clamp(0.0, 1.0);
      // Invert: higher pace (slower) = lower on chart
      final y = topPad + normalizedPace * drawH;

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    // Fill under curve
    final fillPath = Path.from(path);
    fillPath.lineTo(leftPad + drawW, topPad + drawH);
    fillPath.lineTo(leftPad, topPad + drawH);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.electricLime.withOpacity(0.3),
            AppTheme.electricLime.withOpacity(0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.electricLime
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Axis labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Fastest pace label (top)
    textPainter.text = TextSpan(
      text: _formatPace(minPace),
      style: const TextStyle(
        color: AppTheme.textTertiary,
        fontSize: 9,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - textPainter.width - 2, 0));

    // Slowest pace label (bottom)
    textPainter.text = TextSpan(
      text: _formatPace(maxPace),
      style: const TextStyle(
        color: AppTheme.textTertiary,
        fontSize: 9,
      ),
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(size.width - textPainter.width - 2, drawH + topPad - 10));
  }

  String _formatPace(double pace) {
    final totalSec = (pace * 60).round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  @override
  bool shouldRepaint(covariant _PaceChartPainter old) =>
      old.segments.length != segments.length;
}

/// Elevation chart overlay widget
class ElevationChartWidget extends StatelessWidget {
  final List<GpsPoint> points;
  final double height;

  const ElevationChartWidget({
    super.key,
    required this.points,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 3) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _ElevationPainter(points),
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  final List<GpsPoint> points;
  _ElevationPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final altitudes = points.map((p) => p.altitude).toList();
    final minAlt = altitudes.reduce((a, b) => a < b ? a : b);
    final maxAlt = altitudes.reduce((a, b) => a > b ? a : b);
    final range = (maxAlt - minAlt).clamp(1.0, double.infinity);

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final normalizeAlt = (points[i].altitude - minAlt) / range;
      final y = size.height - normalizeAlt * (size.height - 10);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Fill
    final fill = Path.from(path);
    fill.lineTo(size.width, size.height);
    fill.lineTo(0, size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.elevation.withOpacity(0.3),
            AppTheme.elevation.withOpacity(0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.elevation
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: '${maxAlt.toStringAsFixed(0)}m',
      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 9),
    );
    tp.layout();
    tp.paint(canvas, const Offset(2, 0));

    tp.text = TextSpan(
      text: '${minAlt.toStringAsFixed(0)}m',
      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 9),
    );
    tp.layout();
    tp.paint(canvas, Offset(2, size.height - 12));
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter old) =>
      old.points.length != points.length;
}
