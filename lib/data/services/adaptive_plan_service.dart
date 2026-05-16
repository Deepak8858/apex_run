import '../../domain/models/planned_workout.dart';

enum TrainingPlanGoal { fiveK, tenK, halfMarathon, marathon, generalFitness }

extension TrainingPlanGoalLabel on TrainingPlanGoal {
  String get label {
    switch (this) {
      case TrainingPlanGoal.fiveK:
        return '5K';
      case TrainingPlanGoal.tenK:
        return '10K';
      case TrainingPlanGoal.halfMarathon:
        return 'Half Marathon';
      case TrainingPlanGoal.marathon:
        return 'Marathon';
      case TrainingPlanGoal.generalFitness:
        return 'General Fitness';
    }
  }
}

class AdaptivePlanOptions {
  const AdaptivePlanOptions({
    required this.userId,
    required this.goal,
    required this.startDate,
    required this.weeks,
    required this.trainingWeekdays,
    this.currentWeeklyDistanceMeters = 0,
    this.recoveryScore,
  });

  final String userId;
  final TrainingPlanGoal goal;
  final DateTime startDate;
  final int weeks;
  final List<int> trainingWeekdays;
  final double currentWeeklyDistanceMeters;
  final int? recoveryScore;
}

class AdaptivePlanSummary {
  const AdaptivePlanSummary({
    required this.goalLabel,
    required this.weekCount,
    required this.totalWorkouts,
    required this.firstWeekDistanceMeters,
    required this.peakWeekDistanceMeters,
    required this.adaptationNote,
  });

  final String goalLabel;
  final int weekCount;
  final int totalWorkouts;
  final double firstWeekDistanceMeters;
  final double peakWeekDistanceMeters;
  final String adaptationNote;

  String get firstWeekDistanceLabel =>
      '${(firstWeekDistanceMeters / 1000).toStringAsFixed(1)} km';

  String get peakWeekDistanceLabel =>
      '${(peakWeekDistanceMeters / 1000).toStringAsFixed(1)} km';
}

class AdaptivePlanResult {
  const AdaptivePlanResult({
    required this.workouts,
    required this.weeklyDistanceMeters,
    required this.summary,
  });

  final List<PlannedWorkout> workouts;
  final List<double> weeklyDistanceMeters;
  final AdaptivePlanSummary summary;
}

class AdaptivePlanService {
  static const double _maxWeeklyRamp = 1.12;

  AdaptivePlanResult generatePlan(AdaptivePlanOptions options) {
    final weekdays = _normalWeekdays(options.trainingWeekdays);
    final weeks = options.weeks.clamp(2, 24);
    final baseDistance = _baseWeeklyDistance(options);
    final lowRecovery =
        options.recoveryScore != null && options.recoveryScore! < 50;
    final weeklyDistances = <double>[];
    final workouts = <PlannedWorkout>[];

    for (var week = 0; week < weeks; week++) {
      final previous = weeklyDistances.isEmpty
          ? baseDistance
          : weeklyDistances.last;
      final target = week == 0 ? baseDistance : previous * _weeklyRampFor(week);
      final cappedTarget = weeklyDistances.isEmpty
          ? target
          : target.clamp(0, previous * _maxWeeklyRamp).toDouble();
      weeklyDistances.add(cappedTarget);

      final weekStart = _weekStartFor(options.startDate, week);
      final dates = weekdays
          .map((weekday) => _dateForWeekday(weekStart, weekday))
          .where((date) => !date.isBefore(_dateOnly(options.startDate)))
          .toList();
      final weekWorkouts = _buildWeek(
        options: options,
        weekIndex: week,
        dates: dates,
        weeklyDistanceMeters: cappedTarget,
        lowRecovery: lowRecovery && week == 0,
      );
      workouts.addAll(weekWorkouts);
    }

    final note = lowRecovery
        ? 'First week reduced because recovery is low; quality work resumes once readiness improves.'
        : 'Plan uses conservative weekly ramping and one quality session per week.';

    return AdaptivePlanResult(
      workouts: workouts,
      weeklyDistanceMeters: weeklyDistances,
      summary: AdaptivePlanSummary(
        goalLabel: options.goal.label,
        weekCount: weeks,
        totalWorkouts: workouts.length,
        firstWeekDistanceMeters: weeklyDistances.first,
        peakWeekDistanceMeters: weeklyDistances.reduce((a, b) => a > b ? a : b),
        adaptationNote: note,
      ),
    );
  }

  List<PlannedWorkout> _buildWeek({
    required AdaptivePlanOptions options,
    required int weekIndex,
    required List<DateTime> dates,
    required double weeklyDistanceMeters,
    required bool lowRecovery,
  }) {
    if (dates.isEmpty) return const [];

    final distances = _distanceSplit(dates.length, weeklyDistanceMeters);
    final longRunIndex = dates.length - 1;
    final qualityIndex = dates.length >= 3 ? 1 : 0;

    return [
      for (var i = 0; i < dates.length; i++)
        _workoutFor(
          options: options,
          weekIndex: weekIndex,
          dayIndex: i,
          date: dates[i],
          distanceMeters: distances[i],
          isLongRun: i == longRunIndex,
          isQuality: i == qualityIndex,
          lowRecovery: lowRecovery,
        ),
    ];
  }

  PlannedWorkout _workoutFor({
    required AdaptivePlanOptions options,
    required int weekIndex,
    required int dayIndex,
    required DateTime date,
    required double distanceMeters,
    required bool isLongRun,
    required bool isQuality,
    required bool lowRecovery,
  }) {
    final qualityType = weekIndex.isEven ? 'tempo' : 'intervals';
    final type = lowRecovery
        ? (dayIndex == 0
              ? 'recovery'
              : isLongRun
              ? 'long_run'
              : 'easy')
        : isLongRun
        ? 'long_run'
        : isQuality
        ? qualityType
        : 'easy';

    final durationMinutes = _durationMinutes(distanceMeters, type);
    return PlannedWorkout(
      userId: options.userId,
      workoutType: type,
      description: _descriptionFor(type, options.goal, distanceMeters),
      targetDistanceMeters: distanceMeters.roundToDouble(),
      targetDurationMinutes: durationMinutes,
      coachingRationale: _rationaleFor(type, weekIndex, lowRecovery),
      plannedDate: _dateOnly(date),
    );
  }

  List<double> _distanceSplit(int workoutCount, double totalMeters) {
    if (workoutCount == 1) return [totalMeters];
    if (workoutCount == 2) {
      return [totalMeters * 0.45, totalMeters * 0.55];
    }

    final distances = List<double>.filled(workoutCount, 0);
    distances[workoutCount - 1] = totalMeters * 0.4;
    distances[1] = totalMeters * 0.3;
    final easyCount = workoutCount - 2;
    final easyDistance = totalMeters * 0.3 / easyCount;
    for (var i = 0; i < workoutCount; i++) {
      if (i != 1 && i != workoutCount - 1) {
        distances[i] = easyDistance;
      }
    }
    return distances;
  }

  double _baseWeeklyDistance(AdaptivePlanOptions options) {
    final minimum = switch (options.goal) {
      TrainingPlanGoal.fiveK => 8000.0,
      TrainingPlanGoal.tenK => 12000.0,
      TrainingPlanGoal.halfMarathon => 20000.0,
      TrainingPlanGoal.marathon => 30000.0,
      TrainingPlanGoal.generalFitness => 10000.0,
    };
    final current = options.currentWeeklyDistanceMeters;
    if (current <= 0) return minimum;
    return current < minimum ? minimum : current;
  }

  double _weeklyRampFor(int weekIndex) {
    if ((weekIndex + 1) % 4 == 0) return 0.9;
    return 1.08;
  }

  int _durationMinutes(double distanceMeters, String type) {
    final pace = switch (type) {
      'tempo' => 5.4,
      'intervals' => 5.1,
      'long_run' => 6.4,
      'recovery' => 7.0,
      _ => 6.2,
    };
    return ((distanceMeters / 1000) * pace).round().clamp(15, 240);
  }

  String _descriptionFor(
    String type,
    TrainingPlanGoal goal,
    double distanceMeters,
  ) {
    final distance = '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    switch (type) {
      case 'tempo':
        return '$distance tempo session for ${goal.label}: warm up, hold comfortably hard effort, cool down.';
      case 'intervals':
        return '$distance interval session for ${goal.label}: short repeats with easy recoveries.';
      case 'long_run':
        return '$distance long run at relaxed conversational effort.';
      case 'recovery':
        return '$distance recovery run. Keep effort very easy and stop if fatigue rises.';
      default:
        return '$distance easy run at conversational pace.';
    }
  }

  String _rationaleFor(String type, int weekIndex, bool lowRecovery) {
    if (lowRecovery) {
      return 'Recovery is low, so this week prioritizes consistency without extra intensity.';
    }
    switch (type) {
      case 'tempo':
        return 'Week ${weekIndex + 1} includes controlled threshold work to improve sustainable pace.';
      case 'intervals':
        return 'Week ${weekIndex + 1} includes faster repeats to build speed while total load stays capped.';
      case 'long_run':
        return 'Long runs build aerobic durability for the goal distance.';
      default:
        return 'Easy mileage supports aerobic growth and recovery between harder sessions.';
    }
  }

  List<int> _normalWeekdays(List<int> weekdays) {
    final cleaned =
        weekdays
            .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
            .toSet()
            .toList()
          ..sort();
    if (cleaned.isEmpty) {
      return const [DateTime.monday, DateTime.wednesday, DateTime.saturday];
    }
    return cleaned;
  }

  DateTime _weekStartFor(DateTime startDate, int weekIndex) {
    final start = _dateOnly(startDate);
    final monday = start.subtract(
      Duration(days: start.weekday - DateTime.monday),
    );
    return monday.add(Duration(days: weekIndex * 7));
  }

  DateTime _dateForWeekday(DateTime weekStart, int weekday) {
    return _dateOnly(weekStart.add(Duration(days: weekday - DateTime.monday)));
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
