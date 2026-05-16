import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/models/achievement.dart';
import '../../domain/models/activity.dart';

/// Evaluates which catalog achievements an activity unlocks and inserts
/// rows into `public.user_achievements`. Idempotent — duplicate inserts
/// silently no-op (primary-key constraint + ON CONFLICT DO NOTHING via try).
class AchievementService {
  AchievementService(this._supabase);

  final SupabaseClient _supabase;
  final _log = AppLogger.tag('Achieve');

  Future<List<Achievement>> catalog() async {
    final rows = await _supabase
        .from('achievements')
        .select()
        .order('rarity', ascending: true);
    return (rows as List)
        .map((j) => Achievement.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<UnlockedAchievement>> myUnlocked({int limit = 50}) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return const [];
    final rows = await _supabase
        .from('user_achievements')
        .select('achievement_code, unlocked_at, activity_id')
        .eq('user_id', me)
        .order('unlocked_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((j) =>
            UnlockedAchievement.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Evaluate post-save. Returns the *newly* unlocked codes.
  /// [currentStreak] should be the streak AFTER this activity is counted.
  Future<List<String>> evaluateForActivity({
    required Activity activity,
    required int currentStreak,
  }) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return const [];

    final eligible = <String>{};

    // First run.
    eligible.add('first_run');

    // Distance milestones (single activity).
    final dist = activity.distanceMeters;
    if (dist >= 3000) eligible.add('three_km');
    if (dist >= 5000) eligible.add('five_km');
    if (dist >= 10000) eligible.add('ten_km');
    if (dist >= 15000) eligible.add('fifteen_km');
    if (dist >= 21097) eligible.add('half_marathon');
    if (dist >= 30000) eligible.add('thirty_km');
    if (dist >= 42195) eligible.add('marathon');
    if (dist >= 50000) eligible.add('ultra');

    // Streak milestones (current after-save streak).
    if (currentStreak >= 3) eligible.add('streak_3');
    if (currentStreak >= 7) eligible.add('streak_7');
    if (currentStreak >= 14) eligible.add('streak_14');
    if (currentStreak >= 30) eligible.add('streak_30');
    if (currentStreak >= 60) eligible.add('streak_60');
    if (currentStreak >= 100) eligible.add('streak_100');
    if (currentStreak >= 365) eligible.add('streak_365');

    // Time-of-day specials.
    final h = activity.startTime.toLocal().hour;
    if (h < 7) eligible.add('early_bird');
    if (h >= 22) eligible.add('night_owl');

    // Elevation milestones (single activity).
    final gain = activity.elevationGainMeters ?? 0;
    if (gain >= 500) eligible.add('hill_climber');
    if (gain >= 1500) eligible.add('mountain_goat');

    // Pace milestones — only count distances ≥ 5km so quick sprints don't qualify.
    final pace = activity.avgPaceMinPerKm;
    if (pace != null && dist >= 5000) {
      if (pace < 5.0) eligible.add('sub_5_min_km');
      if (pace < 4.0) eligible.add('sub_4_min_km');
    }

    // Lifetime distance — single query for SUM, cheap on the indexed column.
    try {
      final totalRows = await _supabase
          .from('activities')
          .select('distance_meters')
          .eq('user_id', me);
      final lifetime = (totalRows as List).fold<double>(
        0,
        (s, r) => s + ((r['distance_meters'] as num?)?.toDouble() ?? 0),
      );
      if (lifetime >= 100000) eligible.add('lifetime_100km');
      if (lifetime >= 500000) eligible.add('lifetime_500km');
      if (lifetime >= 1000000) eligible.add('lifetime_1000km');
      if (lifetime >= 5000000) eligible.add('lifetime_5000km');
    } catch (e, st) {
      _log.w('Lifetime distance query failed', error: e, stackTrace: st);
    }

    // PR detection — was this the user's best time over a standard distance?
    // Standard rungs: 5K (5000m), 10K (10000m), half (21097m), marathon (42195m).
    // Treat the activity as eligible for a PR badge if it COVERED the distance
    // and finished within standard tolerance (±0.5km for short, ±1km for long).
    Future<bool> isPrAt(double targetMeters, double tolerance, String code) async {
      if (dist < targetMeters - tolerance) return false;
      try {
        final priorRows = await _supabase
            .from('activities')
            .select('duration_seconds, distance_meters')
            .eq('user_id', me)
            .neq('id', activity.id ?? '')
            .gte('distance_meters', targetMeters - tolerance)
            .lte('distance_meters', targetMeters + tolerance * 4);
        final priorBest = (priorRows as List)
            .map((r) => (r['duration_seconds'] as num).toInt())
            .fold<int>(1 << 30, (b, s) => s < b ? s : b);
        return activity.durationSeconds < priorBest;
      } catch (_) {
        return false;
      }
    }

    if (await isPrAt(5000, 250, 'pr_5k')) eligible.add('pr_5k');
    if (await isPrAt(10000, 500, 'pr_10k')) eligible.add('pr_10k');
    if (await isPrAt(21097, 1000, 'pr_half')) eligible.add('pr_half');
    if (await isPrAt(42195, 1500, 'pr_marathon')) eligible.add('pr_marathon');

    if (eligible.isEmpty) return const [];

    // Filter out already-unlocked codes.
    final existingRows = await _supabase
        .from('user_achievements')
        .select('achievement_code')
        .eq('user_id', me)
        .inFilter('achievement_code', eligible.toList());
    final already = (existingRows as List)
        .map((r) => r['achievement_code'] as String)
        .toSet();
    final toUnlock = eligible.difference(already).toList();
    if (toUnlock.isEmpty) return const [];

    try {
      await _supabase.from('user_achievements').insert(
            toUnlock
                .map((code) => {
                      'user_id': me,
                      'achievement_code': code,
                      'activity_id': activity.id,
                    })
                .toList(),
          );
      _log.i('Unlocked ${toUnlock.length} achievement(s): ${toUnlock.join(",")}');
    } catch (e, st) {
      _log.w('Achievement insert failed', error: e, stackTrace: st);
    }
    return toUnlock;
  }
}
