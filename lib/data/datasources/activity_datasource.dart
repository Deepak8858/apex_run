import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/activity.dart';

/// Lean column projection for list/feed views.
///
/// `raw_gps_points` is intentionally OMITTED — a long activity can carry
/// thousands of GPS points (~MBs of JSON). The detail screen calls
/// [ActivityDataSource.getActivityById] for the full payload.
const _activityListColumns =
    'id, user_id, activity_name, activity_type, description, '
    'distance_meters, duration_seconds, avg_pace_min_per_km, max_speed_kmh, '
    'elevation_gain_meters, elevation_loss_meters, '
    'avg_heart_rate, max_heart_rate, start_time, end_time, '
    'is_private, created_at';

class ActivityDataSource {
  ActivityDataSource(this._supabase);

  final SupabaseClient _supabase;

  /// Create a new activity using RPC function for PostGIS support.
  Future<String> createActivity(Activity activity) async {
    final response = await _supabase.rpc(
      'insert_activity',
      params: activity.toSupabaseInsertParams(),
    );
    return response as String;
  }

  /// Cursor-paginated list of the current user's activities.
  ///
  /// Pass [before] = the previous page's last `startTime` to fetch the next
  /// page. Stable across new inserts (unlike offset). [limit] is capped at 50.
  Future<List<Activity>> getActivitiesPage({
    DateTime? before,
    int limit = 20,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final capped = limit.clamp(1, 50);

    var query = _supabase
        .from('activities')
        .select(_activityListColumns)
        .eq('user_id', userId);

    if (before != null) {
      query = query.lt('start_time', before.toUtc().toIso8601String());
    }

    final response = await query
        .order('start_time', ascending: false)
        .limit(capped);

    return (response as List)
        .map((json) => Activity.fromSupabaseJson(json))
        .toList();
  }

  /// Backwards-compatible shim — prefer [getActivitiesPage] in new code.
  @Deprecated('Use getActivitiesPage with cursor pagination')
  Future<List<Activity>> getActivities({
    int limit = 20,
    int offset = 0,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('activities')
        .select(_activityListColumns)
        .eq('user_id', userId)
        .order('start_time', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => Activity.fromSupabaseJson(json))
        .toList();
  }

  /// Full activity row including GPS points and form-analysis blobs.
  Future<Activity> getActivityById(String id) async {
    final response = await _supabase
        .from('activities')
        .select()
        .eq('id', id)
        .single();

    return Activity.fromSupabaseJson(response);
  }

  Future<void> deleteActivity(String id) async {
    await _supabase.from('activities').delete().eq('id', id);
  }

  /// Activities between two dates — used for weekly stats. Projection
  /// excludes `raw_gps_points` since stats only need scalar columns.
  Future<List<Activity>> getActivitiesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('activities')
        .select(_activityListColumns)
        .eq('user_id', userId)
        .gte('start_time', start.toUtc().toIso8601String())
        .lte('start_time', end.toUtc().toIso8601String())
        .order('start_time', ascending: false);

    return (response as List)
        .map((json) => Activity.fromSupabaseJson(json))
        .toList();
  }

  /// Total count of the current user's activities.
  ///
  /// supabase-flutter 2.x removed `FetchOptions(head: true)`; the most portable
  /// option without a server-side RPC is to fetch the id list (small payload)
  /// and use its length. If profile pages start serving thousands of users
  /// at once, replace with a `count_user_activities(uid)` RPC.
  Future<int> getActivityCount() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('activities')
        .select('id')
        .eq('user_id', userId);
    return (response as List).length;
  }
}
