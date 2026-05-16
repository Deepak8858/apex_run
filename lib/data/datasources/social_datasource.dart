import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/models/activity.dart';

/// Reads + mutates social graph + kudos. Backed by RLS policies in
/// migration `20260511000003_social_subs_achievements.sql`.
class SocialDataSource {
  SocialDataSource(this._supabase);

  final SupabaseClient _supabase;
  final _log = AppLogger.tag('Social');

  // ── Friendships ────────────────────────────────────────────────────

  /// Send a friend request. Caller becomes `user_id`, target `friend_id`,
  /// status 'pending'. The recipient must accept via [acceptFriend].
  Future<void> requestFriend(String friendId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) throw const AuthException('Not signed in');
    if (me == friendId) throw ArgumentError('Cannot friend yourself');

    await _supabase.from('friendships').upsert({
      'user_id': me,
      'friend_id': friendId,
      'status': 'pending',
    }, onConflict: 'user_id,friend_id');
  }

  /// Recipient accepts. Inserts mirror row so queries from either side
  /// only need a single eq on user_id.
  Future<void> acceptFriend(String requesterId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) throw const AuthException('Not signed in');

    await _supabase
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('user_id', requesterId)
        .eq('friend_id', me);

    // Mirror row from me → requester for symmetric reads.
    await _supabase.from('friendships').upsert({
      'user_id': me,
      'friend_id': requesterId,
      'status': 'accepted',
    }, onConflict: 'user_id,friend_id');

    // First-friend + 10-friends social achievements.
    await _maybeUnlockSocialAchievements();
  }

  /// Idempotent — checks counts and inserts achievement rows if eligible.
  /// All inserts ON CONFLICT (PK) DO NOTHING via try/catch on unique_violation.
  Future<void> _maybeUnlockSocialAchievements() async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return;
    try {
      final friends = await _supabase
          .from('friendships')
          .select('friend_id')
          .eq('user_id', me)
          .eq('status', 'accepted');
      final count = (friends as List).length;

      final toUnlock = <String>[];
      if (count >= 1) toUnlock.add('first_friend');
      if (count >= 10) toUnlock.add('ten_friends');

      for (final code in toUnlock) {
        try {
          await _supabase.from('user_achievements').insert({
            'user_id': me,
            'achievement_code': code,
          });
        } on PostgrestException catch (e) {
          if (e.code != '23505') rethrow; // ignore "already unlocked"
        }
      }
    } catch (e, st) {
      _log.w('Social achievement check failed', error: e, stackTrace: st);
    }
  }

  Future<void> removeFriend(String friendId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) throw const AuthException('Not signed in');

    // Delete both directions.
    await _supabase
        .from('friendships')
        .delete()
        .or('and(user_id.eq.$me,friend_id.eq.$friendId),and(user_id.eq.$friendId,friend_id.eq.$me)');
  }

  Future<List<String>> friendIds() async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return const [];

    final rows = await _supabase
        .from('friendships')
        .select('friend_id')
        .eq('user_id', me)
        .eq('status', 'accepted');

    return (rows as List).map((r) => r['friend_id'] as String).toList();
  }

  /// Find profiles by username or display_name. Only the public columns
  /// (id, display_name, username, avatar_url) come back via the
  /// `user_profiles_public` view.
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final me = _supabase.auth.currentUser?.id;

    final rows = await _supabase
        .from('user_profiles_public')
        .select('id, display_name, username, avatar_url')
        .or('username.ilike.%$q%,display_name.ilike.%$q%')
        .limit(25);

    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .where((r) => r['id'] != me)
        .toList();
  }

  Future<List<String>> pendingIncoming() async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return const [];

    final rows = await _supabase
        .from('friendships')
        .select('user_id')
        .eq('friend_id', me)
        .eq('status', 'pending');

    return (rows as List).map((r) => r['user_id'] as String).toList();
  }

  // ── Activity feed (friends) ────────────────────────────────────────

  /// Feed = recent activities from accepted friends, newest first.
  /// Cursor pagination via [before] (the previous page's last start_time).
  /// Returns lean Activity records (no raw_gps_points).
  Future<List<Activity>> friendsFeed({
    DateTime? before,
    int limit = 20,
  }) async {
    final ids = await friendIds();
    if (ids.isEmpty) return const [];

    var query = _supabase
        .from('activities')
        .select(
          'id, user_id, activity_name, activity_type, description, '
          'distance_meters, duration_seconds, avg_pace_min_per_km, max_speed_kmh, '
          'elevation_gain_meters, elevation_loss_meters, '
          'avg_heart_rate, max_heart_rate, start_time, end_time, '
          'is_private, created_at, kudos_count',
        )
        .inFilter('user_id', ids)
        .eq('is_private', false);

    if (before != null) {
      query = query.lt('start_time', before.toUtc().toIso8601String());
    }

    final rows = await query
        .order('start_time', ascending: false)
        .limit(limit.clamp(1, 50));

    return (rows as List)
        .map((j) => Activity.fromSupabaseJson(j as Map<String, dynamic>))
        .toList();
  }

  // ── Kudos ──────────────────────────────────────────────────────────

  Future<void> addKudos(String activityId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) throw const AuthException('Not signed in');

    try {
      await _supabase.from('kudos').insert({
        'activity_id': activityId,
        'user_id': me,
      });
      // First-kudos-given achievement (fail-quiet on duplicate).
      try {
        await _supabase.from('user_achievements').insert({
          'user_id': me,
          'achievement_code': 'first_kudos_given',
        });
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }
    } on PostgrestException catch (e) {
      // 23505 = unique_violation (already kudo'd) — treat as success.
      if (e.code == '23505') return;
      rethrow;
    }
  }

  Future<void> removeKudos(String activityId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) throw const AuthException('Not signed in');

    await _supabase
        .from('kudos')
        .delete()
        .eq('activity_id', activityId)
        .eq('user_id', me);
  }

  /// Has the current user kudo'd this activity?
  Future<bool> hasKudos(String activityId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return false;
    final row = await _supabase
        .from('kudos')
        .select('user_id')
        .eq('activity_id', activityId)
        .eq('user_id', me)
        .maybeSingle();
    return row != null;
  }
}
