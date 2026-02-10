import 'gps_point.dart';

enum TrackingState { idle, tracking, paused }

class TrackingMetrics {
  final double distanceMeters;
  final int durationSeconds;
  final double currentPaceMinPerKm;
  final double currentSpeedKmh;
  final List<GpsPoint> routePoints;
  final TrackingState state;

  const TrackingMetrics({
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.currentPaceMinPerKm = 0,
    this.currentSpeedKmh = 0,
    this.routePoints = const [],
    this.state = TrackingState.idle,
  });

  TrackingMetrics copyWith({
    double? distanceMeters,
    int? durationSeconds,
    double? currentPaceMinPerKm,
    double? currentSpeedKmh,
    List<GpsPoint>? routePoints,
    TrackingState? state,
  }) {
    return TrackingMetrics(
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      currentPaceMinPerKm:
          currentPaceMinPerKm ?? this.currentPaceMinPerKm,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      routePoints: routePoints ?? this.routePoints,
      state: state ?? this.state,
    );
  }

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return (distanceMeters / 1000).toStringAsFixed(2);
    }
    return distanceMeters.toStringAsFixed(0);
  }

  String get distanceUnit => distanceMeters >= 1000 ? 'km' : 'm';

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (currentPaceMinPerKm <= 0 || currentPaceMinPerKm.isInfinite) {
      return '--:--';
    }
    final totalSeconds = (currentPaceMinPerKm * 60).round();
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
