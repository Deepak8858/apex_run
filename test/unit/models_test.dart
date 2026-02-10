import 'package:flutter_test/flutter_test.dart';
import 'package:apex_run/domain/models/planned_workout.dart';
import 'package:apex_run/domain/models/segment.dart';
import 'package:apex_run/domain/models/segment_effort.dart';
import 'package:apex_run/ml/models/form_analysis_result.dart';
import 'package:apex_run/ml/models/hrv_data.dart';

void main() {
  group('PlannedWorkout', () {
    test('fromSupabaseJson parses correctly', () {
      final json = {
        'id': 'test-id',
        'user_id': 'user-1',
        'workout_type': 'tempo',
        'description': 'Tempo run',
        'target_distance_meters': 7000.0,
        'target_duration_minutes': 35,
        'coaching_rationale': 'Build speed',
        'planned_date': '2024-01-15',
        'is_completed': false,
      };

      final workout = PlannedWorkout.fromSupabaseJson(json);
      expect(workout.id, 'test-id');
      expect(workout.workoutType, 'tempo');
      expect(workout.formattedType, 'Tempo Run');
      expect(workout.targetDistanceMeters, 7000.0);
      expect(workout.isCompleted, false);
    });

    test('toSupabaseJson produces correct format', () {
      final workout = PlannedWorkout(
        userId: 'user-1',
        workoutType: 'easy',
        description: 'Easy run',
        plannedDate: DateTime(2024, 1, 15),
      );

      final json = workout.toSupabaseJson();
      expect(json['user_id'], 'user-1');
      expect(json['workout_type'], 'easy');
      expect(json['planned_date'], '2024-01-15');
      expect(json['is_completed'], false);
    });

    test('formattedType returns human-readable text', () {
      expect(
        PlannedWorkout(
          userId: 'u',
          workoutType: 'intervals',
          description: 'd',
          plannedDate: DateTime.now(),
        ).formattedType,
        'Intervals',
      );
      expect(
        PlannedWorkout(
          userId: 'u',
          workoutType: 'long_run',
          description: 'd',
          plannedDate: DateTime.now(),
        ).formattedType,
        'Long Run',
      );
    });
  });

  group('Segment', () {
    test('fromSupabaseJson parses correctly', () {
      final json = {
        'id': 'seg-1',
        'name': 'Park Loop',
        'distance_meters': 2500.0,
        'elevation_gain_meters': 30.0,
        'is_verified': true,
        'total_attempts': 42,
        'unique_athletes': 15,
      };

      final segment = Segment.fromSupabaseJson(json);
      expect(segment.name, 'Park Loop');
      expect(segment.distanceMeters, 2500.0);
      expect(segment.isVerified, true);
      expect(segment.formattedDistance, '2.50 km');
    });

    test('formattedDistance returns meters for < 1000m', () {
      final segment = Segment.fromSupabaseJson({
        'name': 'Short Sprint',
        'distance_meters': 400.0,
      });
      expect(segment.formattedDistance, '400 m');
    });
  });

  group('SegmentEffort', () {
    test('formattedTime returns mm:ss', () {
      final effort = SegmentEffort(
        segmentId: 's1',
        activityId: 'a1',
        userId: 'u1',
        elapsedSeconds: 185,
        avgPaceMinPerKm: 4.5,
        recordedAt: DateTime.now(),
      );
      expect(effort.formattedTime, '3:05');
    });

    test('formattedPace returns correct format', () {
      final effort = SegmentEffort(
        segmentId: 's1',
        activityId: 'a1',
        userId: 'u1',
        elapsedSeconds: 300,
        avgPaceMinPerKm: 5.25,
        recordedAt: DateTime.now(),
      );
      expect(effort.formattedPace, '5:15 /km');
    });
  });

  group('FormAnalysisResult', () {
    test('gctAssessment returns correct label', () {
      expect(
        FormAnalysisResult(
          groundContactTimeMs: 180,
          verticalOscillationCm: 7,
          cadenceSpm: 185,
          strideLengthM: 1.2,
          formScore: 85,
        ).gctAssessment,
        'Elite',
      );

      expect(
        FormAnalysisResult(
          groundContactTimeMs: 320,
          verticalOscillationCm: 13,
          cadenceSpm: 155,
          strideLengthM: 1.0,
          formScore: 35,
        ).gctAssessment,
        'Needs Work',
      );
    });

    test('cadenceAssessment returns correct label', () {
      expect(
        FormAnalysisResult(
          groundContactTimeMs: 200,
          verticalOscillationCm: 8,
          cadenceSpm: 182,
          strideLengthM: 1.15,
          formScore: 80,
        ).cadenceAssessment,
        'Optimal',
      );
    });
  });

  group('HrvData', () {
    test('canTrainHard returns true for optimal/good', () {
      final hrv = HrvData(
        rmssd: 75,
        restingHeartRate: 52,
        hrvScore: 82,
        recoveryStatus: RecoveryStatus.optimal,
        measuredAt: DateTime.now(),
      );
      expect(hrv.canTrainHard, true);
    });

    test('canTrainHard returns false for low/critical', () {
      final hrv = HrvData(
        rmssd: 25,
        restingHeartRate: 68,
        hrvScore: 30,
        recoveryStatus: RecoveryStatus.low,
        measuredAt: DateTime.now(),
      );
      expect(hrv.canTrainHard, false);
    });

    test('trainingRecommendation matches recovery status', () {
      final hrv = HrvData(
        rmssd: 15,
        restingHeartRate: 75,
        hrvScore: 15,
        recoveryStatus: RecoveryStatus.critical,
        measuredAt: DateTime.now(),
      );
      expect(hrv.trainingRecommendation, contains('rest'));
    });
  });
}
