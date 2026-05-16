import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/models/activity.dart';

/// Lightweight model for the challenges grid.
class Challenge {
  const Challenge({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.goalValue,
    required this.startsAt,
    required this.endsAt,
    required this.rewardXp,
    this.progress = 0,
    this.completedAt,
    this.joined = false,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final String category;
  final double goalValue;
  final DateTime startsAt;
  final DateTime endsAt;
  final int rewardXp;
  final double progress;
  final DateTime? completedAt;
  final bool joined;

  double get percent => goalValue == 0 ? 0 : (progress / goalValue).clamp(0.0, 1.0);
  bool get completed => completedAt != null;
  bool get active => DateTime.now().isAfter(startsAt) && DateTime.now().isBefore(endsAt);
}

class ChallengeService {
  ChallengeService(this._supabase);

  final SupabaseClient _supabase;
  final _log = AppLogger.tag('Challenge');

  /// Active challenges + caller's progress (if joined).
  Future<List<Challenge>> activeWithProgress() async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return const [];

    final challengeRows = await _supabase
        .from('challenges')
        .select()
        .gte('ends_at', DateTime.now().toUtc().toIso8601String())
        .order('starts_at', ascending: false);

    final participationRows = await _supabase
        .from('challenge_participants')
        .select('challenge_id, progress, completed_at')
        .eq('user_id', me);

    final progressByChallenge = {
      for (final r in participationRows as List)
        r['challenge_id'] as String: r as Map<String, dynamic>,
    };

    return (challengeRows as List).map((raw) {
      final c = raw as Map<String, dynamic>;
      final p = progressByChallenge[c['id'] as String];
      return Challenge(
        id: c['id'] as String,
        code: c['code'] as String,
        name: c['name'] as String,
        description: c['description'] as String,
        category: c['category'] as String,
        goalValue: (c['goal_value'] as num).toDouble(),
        startsAt: DateTime.parse(c['starts_at'] as String),
        endsAt: DateTime.parse(c['ends_at'] as String),
        rewardXp: (c['reward_xp'] as num?)?.toInt() ?? 0,
        progress: (p?['progress'] as num?)?.toDouble() ?? 0,
        completedAt: p?['completed_at'] != null
            ? DateTime.parse(p!['completed_at'] as String)
            : null,
        joined: p != null,
      );
    }).toList();
  }

  Future<void> autoEnrollActive() async {
    try {
      await _supabase.rpc('auto_enroll_active_challenges');
    } catch (e, st) {
      _log.w('auto_enroll RPC failed', error: e, stackTrace: st);
    }
  }

  Future<void> join(String challengeId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) throw const AuthException('Not signed in');
    await _supabase.from('challenge_participants').upsert({
      'challenge_id': challengeId,
      'user_id': me,
    }, onConflict: 'challenge_id,user_id');
  }

  Future<void> leave(String challengeId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return;
    await _supabase
        .from('challenge_participants')
        .delete()
        .eq('challenge_id', challengeId)
        .eq('user_id', me);
  }

  /// Call after activity insert. Cascades into all active enrolled challenges.
  Future<void> applyActivity(Activity activity) async {
    try {
      await _supabase.rpc('apply_activity_to_challenges', params: {
        'p_distance_meters': activity.distanceMeters,
        'p_duration_seconds': activity.durationSeconds,
        'p_elevation_meters': activity.elevationGainMeters ?? 0,
      });
    } catch (e, st) {
      _log.w('apply_activity RPC failed', error: e, stackTrace: st);
    }
  }
}
