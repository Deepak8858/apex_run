import 'package:flutter_test/flutter_test.dart';
import 'package:apex_run/core/config/env.dart';
import 'package:apex_run/domain/models/activity.dart';
import 'package:apex_run/domain/models/weekly_stats.dart';
import 'package:apex_run/domain/models/planned_workout.dart';
import 'package:apex_run/domain/models/segment.dart';
import 'package:apex_run/domain/models/segment_effort.dart';
import 'package:apex_run/ml/models/form_analysis_result.dart';
import 'package:apex_run/ml/models/hrv_data.dart';
import 'package:apex_run/ml/gait_metrics_calculator.dart';

/// Integration test that verifies the full data flow from JSON → Model → Display
///
/// This tests the entire pipeline without hitting actual APIs.
void main() {
  group('Activity Pipeline Integration', () {
    test('Activity model constructs with required fields', () {
      final activity = Activity(
        userId: 'user-test',
        activityName: 'Morning Run',
        activityType: 'run',
        distanceMeters: 10500,
        durationSeconds: 3180,
        avgPaceMinPerKm: 5.05,
        elevationGainMeters: 85,
        startTime: DateTime(2024, 3, 15, 6, 30),
      );

      expect(activity.activityName, 'Morning Run');
      expect(activity.distanceMeters, 10500);
      expect(activity.durationSeconds, 3180);
      expect(activity.avgPaceMinPerKm, 5.05);
      expect(activity.formattedDistance, contains('10.5'));
    });

    test('Activity with null optional fields is valid', () {
      final activity = Activity(
        userId: 'user-test',
        activityName: 'Quick Run',
        activityType: 'run',
        distanceMeters: 3000,
        durationSeconds: 900,
        startTime: DateTime.now(),
      );

      expect(activity.elevationGainMeters, isNull);
      expect(activity.avgHeartRate, isNull);
      expect(activity.maxHeartRate, isNull);
      expect(activity.description, isNull);
    });
  });

  group('Weekly Stats Aggregation Integration', () {
    test('aggregates multiple activities correctly', () {
      final activities = [
        Activity(
          userId: 'u',
          activityName: 'Run 1',
          activityType: 'run',
          distanceMeters: 5000,
          durationSeconds: 1500,
          startTime: DateTime.now(),
        ),
        Activity(
          userId: 'u',
          activityName: 'Run 2',
          activityType: 'run',
          distanceMeters: 8000,
          durationSeconds: 2400,
          startTime: DateTime.now(),
        ),
        Activity(
          userId: 'u',
          activityName: 'Run 3',
          activityType: 'run',
          distanceMeters: 12000,
          durationSeconds: 3600,
          startTime: DateTime.now(),
        ),
      ];

      final stats = WeeklyStats.fromActivities(activities);

      expect(stats.runCount, 3);
      expect(stats.totalDistanceMeters, 25000.0);
      expect(stats.totalDurationSeconds, 7500);
      expect(stats.formattedDistance, '25.0 km');
      expect(stats.formattedDuration, '2h 5m');
    });
  });

  group('Workout Planning Integration', () {
    test('workout round-trip through JSON preserves all fields', () {
      final workout = PlannedWorkout(
        id: 'w-1',
        userId: 'u-1',
        workoutType: 'intervals',
        description: '6x400m at 5K pace with 200m jog recovery.',
        targetDistanceMeters: 6000,
        targetDurationMinutes: 40,
        coachingRationale: 'Build VO2max with structured interval work',
        plannedDate: DateTime(2024, 3, 20),
        isCompleted: false,
      );

      final json = workout.toSupabaseJson();
      json['id'] = 'w-1';  // Simulate DB returning ID
      final restored = PlannedWorkout.fromSupabaseJson(json);

      expect(restored.id, workout.id);
      expect(restored.workoutType, workout.workoutType);
      expect(restored.description, workout.description);
      expect(restored.targetDistanceMeters, workout.targetDistanceMeters);
      expect(restored.targetDurationMinutes, workout.targetDurationMinutes);
      expect(restored.coachingRationale, workout.coachingRationale);
      expect(restored.isCompleted, false);
    });
  });

  group('Segment Leaderboard Integration', () {
    test('segment with efforts produces correct ranking', () {
      final segment = Segment.fromSupabaseJson({
        'id': 'seg-int-1',
        'name': 'Hill Climb Challenge',
        'distance_meters': 1500.0,
        'elevation_gain_meters': 80.0,
        'is_verified': true,
        'total_attempts': 50,
        'unique_athletes': 20,
      });

      final efforts = [
        SegmentEffort(
          segmentId: segment.id!,
          activityId: 'a1',
          userId: 'u1',
          elapsedSeconds: 360,
          avgPaceMinPerKm: 4.0,
          recordedAt: DateTime.now(),
        ),
        SegmentEffort(
          segmentId: segment.id!,
          activityId: 'a2',
          userId: 'u2',
          elapsedSeconds: 420,
          avgPaceMinPerKm: 4.67,
          recordedAt: DateTime.now(),
        ),
        SegmentEffort(
          segmentId: segment.id!,
          activityId: 'a3',
          userId: 'u3',
          elapsedSeconds: 480,
          avgPaceMinPerKm: 5.33,
          recordedAt: DateTime.now(),
        ),
      ];

      // Simulate sorting by elapsed time for leaderboard
      efforts.sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));

      expect(efforts[0].elapsedSeconds, 360);
      expect(efforts[0].formattedTime, '6:00');
      expect(efforts[1].formattedTime, '7:00');
      expect(efforts[2].formattedTime, '8:00');
      expect(segment.formattedDistance, '1.50 km');
    });
  });

  group('ML Form Analysis Integration', () {
    test('GaitMetricsCalculator processes frames and produces result', () {
      final calculator = GaitMetricsCalculator();

      // Process enough frames to have data
      for (int i = 0; i < 100; i++) {
        calculator.addPoseFrame(
          landmarks: _createRunningPoseLandmarks(i),
          timestampMs: i * 33, // ~30 FPS
          confidence: 0.95,
        );
      }

      expect(calculator.hasEnoughData, true);

      final formScore = calculator.calculateFormScore();
      expect(formScore, greaterThanOrEqualTo(0));
      expect(formScore, lessThanOrEqualTo(100));

      final tips = calculator.generateCoachingTips();
      expect(tips, isNotEmpty);
    });

    test('FormAnalysisResult assessment chain covers full range', () {
      // Test elite runner metrics
      final elite = FormAnalysisResult(
        groundContactTimeMs: 170,
        verticalOscillationCm: 6.0,
        cadenceSpm: 190,
        strideLengthM: 1.3,
        formScore: 95,
      );
      expect(elite.gctAssessment, 'Elite');
      expect(elite.oscillationAssessment, 'Elite');
      expect(elite.cadenceAssessment, 'Optimal');

      // Test beginner runner metrics
      final beginner = FormAnalysisResult(
        groundContactTimeMs: 340,
        verticalOscillationCm: 14.0,
        cadenceSpm: 155,
        strideLengthM: 0.9,
        formScore: 25,
      );
      expect(beginner.gctAssessment, 'Needs Work');
      expect(beginner.oscillationAssessment, 'Needs Work');
      expect(beginner.cadenceAssessment, 'Low');
    });

    test('HRV recovery assessment drives training recommendation', () {
      final scenarios = [
        (RecoveryStatus.optimal, true, 'quality'),
        (RecoveryStatus.good, true, 'moderate'),
        (RecoveryStatus.moderate, false, 'Easy'),
        (RecoveryStatus.low, false, 'light'),
        (RecoveryStatus.critical, false, 'rest'),
      ];

      for (final (status, canTrain, keyword) in scenarios) {
        final hrv = HrvData(
          rmssd: 50,
          restingHeartRate: 55,
          hrvScore: 70,
          recoveryStatus: status,
          measuredAt: DateTime.now(),
        );

        expect(hrv.canTrainHard, canTrain,
            reason: 'Recovery ${status.name} should${canTrain ? "" : " not"} allow hard training');
        expect(
          hrv.trainingRecommendation.toLowerCase(),
          contains(keyword.toLowerCase()),
          reason: 'Recovery ${status.name} recommendation should contain "$keyword"',
        );
      }
    });
  });

  group('Configuration Integration', () {
    test('all required services are configured', () {
      expect(Env.isConfigured, true);
      expect(Env.isMapboxConfigured, true);
      expect(Env.isGeminiConfigured, true);
      expect(Env.supabaseUrl, contains('supabase.co'));
      expect(Env.backendUrl, contains('8080'));
    });

    test('feature flags have sensible defaults', () {
      expect(Env.enableAiCoaching, true);
      expect(Env.enableFormAnalysis, true);
      expect(Env.enableSegmentLeaderboards, true);
      expect(Env.enableBackgroundGps, true);
    });
  });
}

/// Generate realistic 33-point BlazePose landmarks simulating running motion
List<PoseLandmark> _createRunningPoseLandmarks(int frameIndex) {
  final phase = (frameIndex % 30) / 30.0;
  final bounce = 0.02 * (1.0 - (2.0 * phase - 1.0).abs());

  return List.generate(33, (i) {
    double x, y, z;

    switch (i) {
      case 0: // Nose
        x = 0.5;
        y = 0.15 + bounce;
        z = 0.0;
        break;
      case 23: // Left hip
        x = 0.45;
        y = 0.55 + bounce;
        z = 0.0;
        break;
      case 24: // Right hip
        x = 0.55;
        y = 0.55 + bounce;
        z = 0.0;
        break;
      case 25: // Left knee
        x = 0.42;
        y = 0.72 + bounce + (phase < 0.5 ? -0.05 * phase : 0.0);
        z = 0.0;
        break;
      case 26: // Right knee
        x = 0.58;
        y = 0.72 + bounce + (phase >= 0.5 ? -0.05 * (1.0 - phase) : 0.0);
        z = 0.0;
        break;
      case 27: // Left ankle
        x = 0.40;
        y = 0.90 + (phase < 0.5 ? -0.1 * phase : 0.0);
        z = 0.0;
        break;
      case 28: // Right ankle
        x = 0.60;
        y = 0.90 + (phase >= 0.5 ? -0.1 * (1.0 - phase) : 0.0);
        z = 0.0;
        break;
      case 29: // Left heel
        x = 0.39;
        y = 0.92;
        z = 0.0;
        break;
      case 30: // Right heel
        x = 0.61;
        y = 0.92;
        z = 0.0;
        break;
      case 31: // Left toe
        x = 0.38;
        y = 0.95;
        z = 0.0;
        break;
      case 32: // Right toe
        x = 0.62;
        y = 0.95;
        z = 0.0;
        break;
      case 11: // Left shoulder
        x = 0.42;
        y = 0.32 + bounce;
        z = 0.0;
        break;
      case 12: // Right shoulder
        x = 0.58;
        y = 0.32 + bounce;
        z = 0.0;
        break;
      case 15: // Left wrist
        x = 0.35 + 0.05 * (phase < 0.5 ? phase * 2 : 2.0 - phase * 2);
        y = 0.50 + bounce;
        z = 0.0;
        break;
      case 16: // Right wrist
        x = 0.65 - 0.05 * (phase < 0.5 ? phase * 2 : 2.0 - phase * 2);
        y = 0.50 + bounce;
        z = 0.0;
        break;
      default:
        x = 0.5;
        y = 0.5;
        z = 0.0;
    }

    return PoseLandmark(
      index: i,
      x: x,
      y: y,
      z: z,
      visibility: 0.95,
    );
  });
}
