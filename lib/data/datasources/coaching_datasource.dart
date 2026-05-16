import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/planned_workout.dart';
import '../../domain/models/weekly_stats.dart';

/// CoachingDataSource — server-only AI calls.
///
/// Every Gemini call goes through a Supabase Edge Function. The client never
/// holds the API key. If the Edge Function fails or rate-limits, we fall back
/// to a deterministic rule-based plan so the user is never blocked.
class CoachingDataSource {
  CoachingDataSource({required SupabaseClient supabase}) : _supabase = supabase;

  final SupabaseClient _supabase;
  final _log = AppLogger.tag('Coach');

  /// Generate a daily workout via `process-coaching` Edge Function.
  /// Falls back to rule-based plan on 429 / 5xx / network error.
  Future<PlannedWorkout?> generateDailyWorkout({
    required String userId,
    required List<Activity> recentActivities,
    required WeeklyStats weeklyStats,
  }) async {
    try {
      final payload = {
        'user_id': userId,
        'last_7_days_load': {
          'total_distance_km': double.parse(
              (weeklyStats.totalDistanceMeters / 1000).toStringAsFixed(1)),
          'total_duration_min':
              (weeklyStats.totalDurationSeconds / 60).round(),
          'run_count': weeklyStats.runCount,
          'avg_pace': weeklyStats.formattedPace,
        },
        'recent_activities': recentActivities
            .map((a) => {
                  'name': a.activityName,
                  'distance_km': double.parse(
                      (a.distanceMeters / 1000).toStringAsFixed(1)),
                  'duration_min': (a.durationSeconds / 60).round(),
                  'pace': a.formattedPace,
                  'type': a.activityType,
                })
            .toList(),
      };

      final response = await _supabase.functions
          .invoke('process-coaching', body: payload);

      if (response.status == 429) {
        _log.w('process-coaching rate-limited; serving rule-based plan');
        return _ruleBasedPlan(userId: userId, weeklyStats: weeklyStats);
      }
      if (response.status != 200 || response.data == null) {
        _log.w('process-coaching status=${response.status}; falling back');
        return _ruleBasedPlan(userId: userId, weeklyStats: weeklyStats);
      }

      final json = Map<String, dynamic>.from(response.data as Map);
      return PlannedWorkout(
        userId: userId,
        workoutType: json['workout_type'] as String? ?? 'easy',
        description:
            json['description'] as String? ?? 'Easy recovery run',
        targetDistanceMeters:
            (json['target_distance_meters'] as num?)?.toDouble(),
        targetDurationMinutes: json['target_duration_minutes'] as int?,
        coachingRationale: json['coaching_rationale'] as String?,
        plannedDate: DateTime.now(),
      );
    } catch (e, st) {
      _log.w('process-coaching failed; falling back', error: e, stackTrace: st);
      return _ruleBasedPlan(userId: userId, weeklyStats: weeklyStats);
    }
  }

  /// Freeform insight via `coach-insight` Edge Function. Returns a sensible
  /// rule-based message on failure rather than surfacing a raw error.
  Future<String> getCoachingInsight({
    required List<Activity> recentActivities,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'coach-insight',
        body: {
          'recent_activities': recentActivities
              .map((a) => {
                    'name': a.activityName,
                    'distance_km': double.parse(
                        (a.distanceMeters / 1000).toStringAsFixed(1)),
                    'duration_min': (a.durationSeconds / 60).round(),
                    'pace': a.formattedPace,
                    'type': a.activityType,
                  })
              .toList(),
        },
      );

      if (response.status == 429) {
        _log.w('coach-insight rate-limited');
        return _ruleBasedInsight(recentActivities);
      }
      if (response.status != 200 || response.data == null) {
        _log.w('coach-insight status=${response.status}; using fallback');
        return _ruleBasedInsight(recentActivities);
      }

      final data = Map<String, dynamic>.from(response.data as Map);
      final insight = data['insight'] as String?;
      if (insight == null || insight.isEmpty) {
        return _ruleBasedInsight(recentActivities);
      }
      return insight;
    } catch (e, st) {
      _log.w('coach-insight failed; using fallback', error: e, stackTrace: st);
      return _ruleBasedInsight(recentActivities);
    }
  }

  // ── Deterministic fallbacks ─────────────────────────────────────────

  String _ruleBasedInsight(List<Activity> recentActivities) {
    if (recentActivities.isEmpty) {
      return 'Welcome! Start with easy runs of 20-30 minutes to build your base. '
          'Focus on maintaining a conversational pace and running consistently 3-4 times per week.';
    }
    final totalKm = recentActivities.fold<double>(
            0, (sum, a) => sum + a.distanceMeters) /
        1000;
    final runCount = recentActivities.length;

    if (runCount >= 5) {
      return 'Great consistency with $runCount runs this week (${totalKm.toStringAsFixed(1)} km total)! '
          'Consider adding one easy recovery day between hard efforts. '
          'Keep 80% of your runs at an easy conversational pace.';
    } else if (runCount >= 3) {
      return 'Good training volume with $runCount runs (${totalKm.toStringAsFixed(1)} km). '
          'Try to maintain this consistency. Your next step could be adding one more easy run or '
          'introducing a tempo segment into one of your runs.';
    }
    return 'You completed $runCount run${runCount > 1 ? 's' : ''} (${totalKm.toStringAsFixed(1)} km). '
        'Aim for 3-4 runs per week to build aerobic fitness. '
        'Prioritize easy-paced runs to build your base safely.';
  }

  PlannedWorkout _ruleBasedPlan({
    required String userId,
    required WeeklyStats weeklyStats,
  }) {
    final dow = DateTime.now().weekday;
    String type;
    String description;
    double dist;
    int duration;
    String rationale;

    if (weeklyStats.runCount == 0) {
      type = 'easy';
      description =
          'Easy 30-minute run at conversational pace. Focus on relaxed form and steady breathing.';
      dist = 4000;
      duration = 30;
      rationale = 'Starting fresh — an easy run builds aerobic base without overloading.';
    } else if (dow == 1 || dow == 5) {
      type = weeklyStats.runCount > 4 ? 'recovery' : 'easy';
      description = type == 'recovery'
          ? 'Light recovery jog (20 min). Keep heart rate very low.'
          : 'Easy run at comfortable pace. Build endurance without strain.';
      dist = type == 'recovery' ? 3000 : 5000;
      duration = type == 'recovery' ? 20 : 35;
      rationale = weeklyStats.runCount > 4
          ? 'High training load this week — recovery keeps you fresh.'
          : 'Easy effort to maintain consistency.';
    } else if (dow == 3) {
      type = 'tempo';
      description =
          'Tempo run: 10 min warm-up, 15 min at tempo pace (comfortably hard), 10 min cool-down.';
      dist = 7000;
      duration = 35;
      rationale = 'Mid-week quality session improves lactate threshold.';
    } else if (dow == 7) {
      type = 'long_run';
      description =
          'Long run at easy pace. Build distance gradually. Stay hydrated and maintain steady effort.';
      dist = 10000;
      duration = 60;
      rationale = 'Weekly long run is the cornerstone of endurance development.';
    } else {
      type = 'easy';
      description = 'Easy run with good form focus. Keep pace conversational.';
      dist = 5000;
      duration = 30;
      rationale = 'Easy effort between harder sessions supports recovery.';
    }

    return PlannedWorkout(
      userId: userId,
      workoutType: type,
      description: description,
      targetDistanceMeters: dist,
      targetDurationMinutes: duration,
      coachingRationale: rationale,
      plannedDate: DateTime.now(),
    );
  }
}
