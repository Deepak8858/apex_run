import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/planned_workout.dart';
import '../../domain/models/weekly_stats.dart';

/// CoachingDataSource — Phase 4c upgrade
///
/// Supports three modes:
/// 1. **Edge Function** (preferred): Calls `process-coaching` Supabase Edge Function
///    which runs Gemini server-side — no API key exposed in client.
/// 2. **Client-side Gemini** (fallback): Direct Gemini API call when Edge Function is unavailable.
/// 3. **Smart fallback**: Generates sensible workout recommendations from training data
///    even when AI services are completely unavailable.
class CoachingDataSource {
  GenerativeModel? _model;
  final SupabaseClient? _supabase;

  CoachingDataSource({SupabaseClient? supabase}) : _supabase = supabase {
    if (Env.geminiApiKey.isNotEmpty) {
      try {
        _model = GenerativeModel(
          model: Env.geminiModel,
          apiKey: Env.geminiApiKey,
          systemInstruction: Content.text(
            'You are an elite running coach specializing in marathon physiology '
            'and data-driven training. Analyze the runner\'s recent training data '
            'and provide specific, actionable workout recommendations. '
            'Always respond in valid JSON format when generating workouts.',
          ),
        );
      } catch (e) {
        debugPrint('Failed to initialize Gemini model: $e');
      }
    }
  }

  /// Generate a daily workout — tries Edge Function → Gemini → smart fallback
  Future<PlannedWorkout?> generateDailyWorkout({
    required String userId,
    required List<Activity> recentActivities,
    required WeeklyStats weeklyStats,
  }) async {
    // Try Edge Function first (Phase 4c)
    if (_supabase != null && Env.enableEdgeFunctions) {
      try {
        final result = await _generateViaEdgeFunction(
          userId: userId,
          recentActivities: recentActivities,
          weeklyStats: weeklyStats,
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('Edge Function failed, falling back to client-side: $e');
      }
    }

    // Fallback: client-side Gemini
    if (_model != null) {
      try {
        final result = await _generateViaClientGemini(
          userId: userId,
          recentActivities: recentActivities,
          weeklyStats: weeklyStats,
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('Client Gemini failed, using smart fallback: $e');
      }
    }

    // Final fallback: rule-based workout generation
    return _generateSmartFallback(userId: userId, weeklyStats: weeklyStats);
  }

  /// Edge Function call — server-side Gemini (no API key exposure)
  Future<PlannedWorkout?> _generateViaEdgeFunction({
    required String userId,
    required List<Activity> recentActivities,
    required WeeklyStats weeklyStats,
  }) async {
    final activitiesPayload = recentActivities.map((a) => {
          'name': a.activityName,
          'distance_km':
              double.parse((a.distanceMeters / 1000).toStringAsFixed(1)),
          'duration_min': (a.durationSeconds / 60).round(),
          'pace': a.formattedPace,
          'type': a.activityType,
        }).toList();

    final response = await _supabase!.functions.invoke(
      'process-coaching',
      body: {
        'user_id': userId,
        'last_7_days_load': {
          'total_distance_km': double.parse(
              (weeklyStats.totalDistanceMeters / 1000).toStringAsFixed(1)),
          'total_duration_min':
              (weeklyStats.totalDurationSeconds / 60).round(),
          'run_count': weeklyStats.runCount,
          'avg_pace': weeklyStats.formattedPace,
        },
        'recent_activities': activitiesPayload,
      },
    );

    if (response.status != 200) {
      throw Exception('Edge Function returned ${response.status}');
    }

    final json = response.data as Map<String, dynamic>;

    return PlannedWorkout(
      userId: userId,
      workoutType: json['workout_type'] as String? ?? 'easy',
      description: json['description'] as String? ?? 'Easy recovery run',
      targetDistanceMeters:
          (json['target_distance_meters'] as num?)?.toDouble(),
      targetDurationMinutes: json['target_duration_minutes'] as int?,
      coachingRationale: json['coaching_rationale'] as String?,
      plannedDate: DateTime.now(),
    );
  }

  /// Client-side Gemini fallback
  Future<PlannedWorkout?> _generateViaClientGemini({
    required String userId,
    required List<Activity> recentActivities,
    required WeeklyStats weeklyStats,
  }) async {
    final prompt = _buildWorkoutPrompt(recentActivities, weeklyStats);
    final response = await _model!.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null) return null;
    return _parseWorkoutResponse(text, userId);
  }

  /// Get freeform coaching insight (client-side only for now)
  Future<String> getCoachingInsight({
    required List<Activity> recentActivities,
  }) async {
    if (_model == null) {
      return _getFallbackInsight(recentActivities);
    }

    try {
      final activitiesSummary = recentActivities.map((a) {
        return '- ${a.activityName}: ${a.formattedDistance}, '
            '${a.formattedDuration}, pace ${a.formattedPace}';
      }).join('\n');

      final prompt = '''
Analyze this runner's recent training and provide 2-3 brief, actionable coaching insights.
Focus on training balance, recovery needs, and progression.

Recent Activities:
$activitiesSummary

Respond in plain text, not JSON. Keep it concise (3-4 sentences max).
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? _getFallbackInsight(recentActivities);
    } catch (e) {
      debugPrint('Coaching insight failed: $e');
      return _getFallbackInsight(recentActivities);
    }
  }

  /// Rule-based fallback insight when AI is unavailable
  String _getFallbackInsight(List<Activity> recentActivities) {
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
    } else {
      return 'You completed $runCount run${runCount > 1 ? 's' : ''} (${totalKm.toStringAsFixed(1)} km). '
          'Aim for 3-4 runs per week to build aerobic fitness. '
          'Prioritize easy-paced runs to build your base safely.';
    }
  }

  /// Smart rule-based workout generation when AI services are unavailable
  PlannedWorkout _generateSmartFallback({
    required String userId,
    required WeeklyStats weeklyStats,
  }) {
    final dayOfWeek = DateTime.now().weekday; // 1=Monday .. 7=Sunday
    String workoutType;
    String description;
    double targetDistance;
    int targetDuration;
    String rationale;

    if (weeklyStats.runCount == 0) {
      // New runner or rest week
      workoutType = 'easy';
      description = 'Easy 30-minute run at conversational pace. '
          'Focus on relaxed form and steady breathing.';
      targetDistance = 4000;
      targetDuration = 30;
      rationale =
          'Starting fresh — an easy run builds aerobic base without overloading.';
    } else if (dayOfWeek == 1 || dayOfWeek == 5) {
      // Monday & Friday → Easy/recovery
      workoutType = weeklyStats.runCount > 4 ? 'recovery' : 'easy';
      description = workoutType == 'recovery'
          ? 'Light recovery jog (20 min). Keep heart rate very low.'
          : 'Easy run at comfortable pace. Build endurance without strain.';
      targetDistance = workoutType == 'recovery' ? 3000 : 5000;
      targetDuration = workoutType == 'recovery' ? 20 : 35;
      rationale = weeklyStats.runCount > 4
          ? 'High training load this week — recovery keeps you fresh.'
          : 'Easy effort to maintain consistency.';
    } else if (dayOfWeek == 3) {
      // Wednesday → Tempo or intervals
      workoutType = 'tempo';
      description = 'Tempo run: 10 min warm-up, 15 min at tempo pace '
          '(comfortably hard), 10 min cool-down.';
      targetDistance = 7000;
      targetDuration = 35;
      rationale =
          'Mid-week quality session improves lactate threshold.';
    } else if (dayOfWeek == 7) {
      // Sunday → Long run
      workoutType = 'long_run';
      description = 'Long run at easy pace. Build distance gradually. '
          'Stay hydrated and maintain steady effort.';
      targetDistance = 10000;
      targetDuration = 60;
      rationale =
          'Weekly long run is the cornerstone of endurance development.';
    } else {
      // Tuesday, Thursday, Saturday → Easy
      workoutType = 'easy';
      description = 'Easy run with good form focus. '
          'Keep pace conversational and enjoy the run.';
      targetDistance = 5000;
      targetDuration = 30;
      rationale = 'Easy effort between harder sessions supports recovery.';
    }

    return PlannedWorkout(
      userId: userId,
      workoutType: workoutType,
      description: description,
      targetDistanceMeters: targetDistance,
      targetDurationMinutes: targetDuration,
      coachingRationale: rationale,
      plannedDate: DateTime.now(),
    );
  }

  String _buildWorkoutPrompt(
    List<Activity> recentActivities,
    WeeklyStats weeklyStats,
  ) {
    final activitiesSummary = recentActivities.map((a) {
      return '{"name":"${a.activityName}","distance_km":${(a.distanceMeters / 1000).toStringAsFixed(1)},'
          '"duration_min":${(a.durationSeconds / 60).toStringAsFixed(0)},'
          '"pace":"${a.formattedPace}","type":"${a.activityType}"}';
    }).join(',\n');

    return '''
Generate ONE workout for today based on this runner's training data.

Weekly Stats:
- Runs this week: ${weeklyStats.runCount}
- Total distance: ${weeklyStats.formattedDistance}
- Total time: ${weeklyStats.formattedDuration}
- Average pace: ${weeklyStats.formattedPace}

Recent Activities (last 7 days):
[$activitiesSummary]

Respond ONLY with a JSON object in this exact format (no markdown, no code blocks):
{
  "workout_type": "easy|tempo|intervals|long_run|recovery|race",
  "description": "Brief workout description with specific instructions",
  "target_distance_meters": 5000,
  "target_duration_minutes": 30,
  "coaching_rationale": "Why this workout is recommended today"
}
''';
  }

  PlannedWorkout? _parseWorkoutResponse(String text, String userId) {
    try {
      var cleaned = text.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceAll(RegExp(r'\n?```$'), '');
      }

      final json = jsonDecode(cleaned.trim()) as Map<String, dynamic>;

      return PlannedWorkout(
        userId: userId,
        workoutType: json['workout_type'] as String? ?? 'easy',
        description: json['description'] as String? ?? 'Easy recovery run',
        targetDistanceMeters:
            (json['target_distance_meters'] as num?)?.toDouble(),
        targetDurationMinutes: json['target_duration_minutes'] as int?,
        coachingRationale: json['coaching_rationale'] as String?,
        plannedDate: DateTime.now(),
      );
    } catch (_) {
      return PlannedWorkout(
        userId: userId,
        workoutType: 'easy',
        description: 'Easy recovery run at comfortable pace',
        targetDistanceMeters: 5000,
        targetDurationMinutes: 30,
        coachingRationale:
            'Default easy run recommendation (AI response could not be parsed)',
        plannedDate: DateTime.now(),
      );
    }
  }
}
