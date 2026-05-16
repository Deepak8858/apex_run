import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger/app_logger.dart';

/// Streak update via `update_streak(p_activity_date)` RPC.
///
/// Call once per saved activity; the RPC is idempotent for same-day calls.
class StreakService {
  StreakService(this._supabase);

  final SupabaseClient _supabase;
  final _log = AppLogger.tag('Streak');

  /// Returns `(streakDays, streakLongest)`. Returns `(0, 0)` if no profile.
  Future<(int, int)> markActivityCompleted(DateTime activityDate) async {
    final date = DateTime(activityDate.year, activityDate.month, activityDate.day);
    try {
      final raw = await _supabase.rpc(
        'update_streak',
        params: {'p_activity_date': _formatDate(date)},
      );
      // Postgres `RETURNS TABLE` over PostgREST returns a List<Map>.
      if (raw is List && raw.isNotEmpty) {
        final row = Map<String, dynamic>.from(raw.first as Map);
        final days = (row['streak_days'] as num?)?.toInt() ?? 0;
        final longest = (row['streak_longest'] as num?)?.toInt() ?? 0;
        _log.i('Streak now $days (best $longest)');
        return (days, longest);
      }
    } catch (e, st) {
      _log.w('update_streak failed', error: e, stackTrace: st);
    }
    return (0, 0);
  }

  /// `YYYY-MM-DD` — Postgres `date` literal format.
  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
