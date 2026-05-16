import 'package:apex_run/data/services/adaptive_plan_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptivePlanService', () {
    final service = AdaptivePlanService();
    final monday = DateTime(2026, 5, 18);

    test('generates a four-week 10K plan on preferred weekdays', () {
      final result = service.generatePlan(
        AdaptivePlanOptions(
          userId: 'user-1',
          goal: TrainingPlanGoal.tenK,
          startDate: monday,
          weeks: 4,
          trainingWeekdays: const [
            DateTime.monday,
            DateTime.wednesday,
            DateTime.saturday,
          ],
          currentWeeklyDistanceMeters: 12000,
        ),
      );

      expect(result.workouts, hasLength(12));
      expect(result.summary.goalLabel, '10K');
      expect(result.summary.weekCount, 4);
      expect(result.summary.totalWorkouts, 12);
      expect(result.workouts.map((w) => w.plannedDate.weekday).toSet(), {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.saturday,
      });
      expect(
        result.workouts.where((w) => w.workoutType == 'long_run'),
        hasLength(4),
      );
      expect(result.workouts.any((w) => w.workoutType == 'tempo'), isTrue);
    });

    test('keeps weekly distance ramp at or below twelve percent', () {
      final result = service.generatePlan(
        AdaptivePlanOptions(
          userId: 'user-1',
          goal: TrainingPlanGoal.halfMarathon,
          startDate: monday,
          weeks: 6,
          trainingWeekdays: const [
            DateTime.monday,
            DateTime.tuesday,
            DateTime.thursday,
            DateTime.saturday,
          ],
          currentWeeklyDistanceMeters: 20000,
        ),
      );

      for (var week = 1; week < result.weeklyDistanceMeters.length; week++) {
        final previous = result.weeklyDistanceMeters[week - 1];
        final current = result.weeklyDistanceMeters[week];
        expect(current, lessThanOrEqualTo(previous * 1.12 + 1));
      }
    });

    test('low recovery removes quality workouts from first week', () {
      final result = service.generatePlan(
        AdaptivePlanOptions(
          userId: 'user-1',
          goal: TrainingPlanGoal.tenK,
          startDate: monday,
          weeks: 4,
          trainingWeekdays: const [
            DateTime.monday,
            DateTime.wednesday,
            DateTime.saturday,
          ],
          currentWeeklyDistanceMeters: 12000,
          recoveryScore: 42,
        ),
      );

      final firstWeek = result.workouts.where(
        (w) => w.plannedDate.isBefore(monday.add(const Duration(days: 7))),
      );

      expect(firstWeek.any((w) => w.workoutType == 'tempo'), isFalse);
      expect(firstWeek.any((w) => w.workoutType == 'intervals'), isFalse);
      expect(result.summary.adaptationNote, contains('recovery'));
    });

    test('moves plan start to the next available training day', () {
      final result = service.generatePlan(
        AdaptivePlanOptions(
          userId: 'user-1',
          goal: TrainingPlanGoal.fiveK,
          startDate: DateTime(2026, 5, 19),
          weeks: 2,
          trainingWeekdays: const [DateTime.wednesday, DateTime.friday],
          currentWeeklyDistanceMeters: 8000,
        ),
      );

      expect(result.workouts.first.plannedDate, DateTime(2026, 5, 20));
      expect(result.workouts.map((w) => w.plannedDate.weekday).toSet(), {
        DateTime.wednesday,
        DateTime.friday,
      });
    });
  });
}
