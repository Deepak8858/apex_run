import 'package:flutter_test/flutter_test.dart';
import 'package:apex_run/domain/models/weekly_stats.dart';
import 'package:apex_run/domain/models/activity.dart';

void main() {
  group('WeeklyStats', () {
    test('fromActivities with empty list returns zero stats', () {
      final stats = WeeklyStats.fromActivities([]);
      expect(stats.runCount, 0);
      expect(stats.totalDistanceMeters, 0);
      expect(stats.totalDurationSeconds, 0);
      expect(stats.avgPaceMinPerKm, 0);
    });

    test('fromActivities calculates correct totals', () {
      final activities = [
        Activity(
          userId: 'user1',
          activityName: 'Morning Run',
          activityType: 'run',
          distanceMeters: 5000,
          durationSeconds: 1500, // 25 min
          startTime: DateTime.now(),
        ),
        Activity(
          userId: 'user1',
          activityName: 'Evening Run',
          activityType: 'run',
          distanceMeters: 3000,
          durationSeconds: 1200, // 20 min
          startTime: DateTime.now(),
        ),
      ];

      final stats = WeeklyStats.fromActivities(activities);
      expect(stats.runCount, 2);
      expect(stats.totalDistanceMeters, 8000);
      expect(stats.totalDurationSeconds, 2700);
    });

    test('formattedDistance shows km for >= 1000m', () {
      final stats = WeeklyStats(totalDistanceMeters: 5500);
      expect(stats.formattedDistance, '5.5 km');
    });

    test('formattedDistance shows m for < 1000m', () {
      final stats = WeeklyStats(totalDistanceMeters: 800);
      expect(stats.formattedDistance, '800 m');
    });

    test('formattedDuration shows hours and minutes', () {
      final stats = WeeklyStats(totalDurationSeconds: 3900); // 1h 5m
      expect(stats.formattedDuration, '1h 5m');
    });

    test('formattedDuration shows only minutes when < 1 hour', () {
      final stats = WeeklyStats(totalDurationSeconds: 1800); // 30m
      expect(stats.formattedDuration, '30m');
    });

    test('formattedPace returns --:-- for zero distance', () {
      final stats = WeeklyStats(totalDistanceMeters: 0);
      expect(stats.formattedPace, '--:--');
    });

    test('formattedPace returns correct pace format', () {
      final stats = WeeklyStats(avgPaceMinPerKm: 5.5);
      expect(stats.formattedPace, '5:30 /km');
    });
  });
}
