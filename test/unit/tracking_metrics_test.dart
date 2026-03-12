import 'package:flutter_test/flutter_test.dart';
import 'package:apex_run/domain/models/tracking_metrics.dart';
import 'package:apex_run/domain/models/gps_point.dart';

void main() {
  group('TrackingMetrics Model Tests', () {
    test('default constructor should initialize correctly', () {
      const metrics = TrackingMetrics();
      expect(metrics.distanceMeters, 0);
      expect(metrics.durationSeconds, 0);
      expect(metrics.currentPaceMinPerKm, 0);
      expect(metrics.currentSpeedKmh, 0);
      expect(metrics.routePoints, isEmpty);
      expect(metrics.state, TrackingState.idle);
    });

    test('copyWith should update specified fields', () {
      const initial = TrackingMetrics();
      final updated = initial.copyWith(
        distanceMeters: 1500,
        durationSeconds: 360,
        state: TrackingState.tracking,
      );

      expect(updated.distanceMeters, 1500);
      expect(updated.durationSeconds, 360);
      expect(updated.currentPaceMinPerKm, 0); // Unchanged
      expect(updated.state, TrackingState.tracking);
    });

    group('formattedDistance & distanceUnit', () {
      test('should return meters when < 1000m', () {
        const metrics = TrackingMetrics(distanceMeters: 850);
        expect(metrics.formattedDistance, '850');
        expect(metrics.distanceUnit, 'm');
      });

      test('should return kilometers when >= 1000m', () {
        const metrics = TrackingMetrics(distanceMeters: 1500);
        expect(metrics.formattedDistance, '1.50');
        expect(metrics.distanceUnit, 'km');
      });

      test('should handle exact kilometer boundaries', () {
        const metrics = TrackingMetrics(distanceMeters: 2000);
        expect(metrics.formattedDistance, '2.00');
        expect(metrics.distanceUnit, 'km');
      });
    });

    group('formattedDuration', () {
      test('should format correctly for duration < 1 hour', () {
        const metrics = TrackingMetrics(durationSeconds: 3599); // 59 mins, 59 secs
        expect(metrics.formattedDuration, '59:59');
      });

      test('should format correctly for duration >= 1 hour', () {
        const metrics = TrackingMetrics(durationSeconds: 3661); // 1 hr, 1 min, 1 sec
        expect(metrics.formattedDuration, '1:01:01');
      });

      test('should pad seconds and minutes correctly', () {
        const metrics = TrackingMetrics(durationSeconds: 65); // 1 min, 5 secs
        expect(metrics.formattedDuration, '01:05');
      });
    });

    group('formattedPace', () {
      test('should format valid pace correctly', () {
        const metrics = TrackingMetrics(currentPaceMinPerKm: 5.5); // 5:30 min/km
        expect(metrics.formattedPace, '5:30');
      });

      test('should handle exact minute pace', () {
        const metrics = TrackingMetrics(currentPaceMinPerKm: 6.0); // 6:00 min/km
        expect(metrics.formattedPace, '6:00');
      });

      test('should return --:-- for 0 or negative pace', () {
        expect(const TrackingMetrics(currentPaceMinPerKm: 0).formattedPace, '--:--');
        expect(const TrackingMetrics(currentPaceMinPerKm: -1).formattedPace, '--:--');
      });

      test('should return --:-- for infinite pace', () {
        expect(const TrackingMetrics(currentPaceMinPerKm: double.infinity).formattedPace, '--:--');
      });
    });
  });
}
