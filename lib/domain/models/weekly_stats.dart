import 'activity.dart';

class WeeklyStats {
  final int runCount;
  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final double avgPaceMinPerKm;

  const WeeklyStats({
    this.runCount = 0,
    this.totalDistanceMeters = 0,
    this.totalDurationSeconds = 0,
    this.avgPaceMinPerKm = 0,
  });

  factory WeeklyStats.fromActivities(List<Activity> activities) {
    if (activities.isEmpty) {
      return const WeeklyStats();
    }

    final totalDistance =
        activities.fold<double>(0, (sum, a) => sum + a.distanceMeters);
    final totalDuration =
        activities.fold<int>(0, (sum, a) => sum + a.durationSeconds);

    double avgPace = 0;
    if (totalDistance > 0) {
      avgPace = (totalDuration / 60) / (totalDistance / 1000);
    }

    return WeeklyStats(
      runCount: activities.length,
      totalDistanceMeters: totalDistance,
      totalDurationSeconds: totalDuration,
      avgPaceMinPerKm: avgPace,
    );
  }

  String get formattedDistance {
    if (totalDistanceMeters >= 1000) {
      return '${(totalDistanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${totalDistanceMeters.toStringAsFixed(0)} m';
  }

  String get formattedDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedPace {
    if (avgPaceMinPerKm <= 0 || avgPaceMinPerKm.isInfinite) {
      return '--:--';
    }
    final totalSeconds = (avgPaceMinPerKm * 60).round();
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')} /km';
  }
}
