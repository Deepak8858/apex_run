import 'dart:math';
import '../../domain/models/gps_point.dart';

class GpsUtils {
  static const double _earthRadiusMeters = 6371000;

  /// Calculate distance between two GPS points using Haversine formula
  static double haversineDistance(GpsPoint a, GpsPoint b) {
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);

    final sinDLat = sin(dLat / 2);
    final sinDLng = sin(dLng / 2);

    final h = sinDLat * sinDLat +
        cos(_toRadians(a.latitude)) *
            cos(_toRadians(b.latitude)) *
            sinDLng *
            sinDLng;

    return 2 * _earthRadiusMeters * asin(sqrt(h));
  }

  /// Calculate total distance from a list of GPS points
  static double totalDistance(List<GpsPoint> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += haversineDistance(points[i - 1], points[i]);
    }
    return total;
  }

  /// Build WKT LINESTRING from GPS points
  static String toWktLineString(List<GpsPoint> points) {
    if (points.length < 2) {
      return 'SRID=4326;LINESTRING(0 0, 0 0)';
    }
    final coords =
        points.map((p) => '${p.longitude} ${p.latitude}').join(', ');
    return 'SRID=4326;LINESTRING($coords)';
  }

  /// Calculate pace in min/km
  static double calculatePace(double distanceMeters, int durationSeconds) {
    if (distanceMeters <= 0) return 0;
    return (durationSeconds / 60) / (distanceMeters / 1000);
  }

  /// Calculate speed in km/h
  static double calculateSpeed(double distanceMeters, int durationSeconds) {
    if (durationSeconds <= 0) return 0;
    return (distanceMeters / 1000) / (durationSeconds / 3600);
  }

  /// Filter out GPS points with poor accuracy
  static List<GpsPoint> filterByAccuracy(
      List<GpsPoint> points, double maxAccuracyMeters) {
    return points.where((p) => p.accuracy <= maxAccuracyMeters).toList();
  }

  /// Remove GPS points within the privacy radius of home location
  static List<GpsPoint> blurNearHome(
    List<GpsPoint> points,
    double homeLat,
    double homeLng,
    double radiusMeters,
  ) {
    final home = GpsPoint(
      latitude: homeLat,
      longitude: homeLng,
      timestamp: DateTime.now(),
    );
    return points
        .where((p) => haversineDistance(p, home) > radiusMeters)
        .toList();
  }

  /// Calculate current pace from recent GPS points (rolling window)
  static double rollingPace(List<GpsPoint> points, {int windowSeconds = 30}) {
    if (points.length < 2) return 0;

    final now = points.last.timestamp;
    final cutoff = now.subtract(Duration(seconds: windowSeconds));
    final recentPoints =
        points.where((p) => p.timestamp.isAfter(cutoff)).toList();

    if (recentPoints.length < 2) return 0;

    final distance = totalDistance(recentPoints);
    final duration = recentPoints.last.timestamp
        .difference(recentPoints.first.timestamp)
        .inSeconds;

    return calculatePace(distance, duration);
  }

  /// Calculate elevation gain from GPS points
  static double elevationGain(List<GpsPoint> points) {
    if (points.length < 2) return 0;
    double gain = 0;
    for (int i = 1; i < points.length; i++) {
      final diff = points[i].altitude - points[i - 1].altitude;
      if (diff > 0) gain += diff;
    }
    return gain;
  }

  /// Calculate elevation loss from GPS points
  static double elevationLoss(List<GpsPoint> points) {
    if (points.length < 2) return 0;
    double loss = 0;
    for (int i = 1; i < points.length; i++) {
      final diff = points[i - 1].altitude - points[i].altitude;
      if (diff > 0) loss += diff;
    }
    return loss;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}
