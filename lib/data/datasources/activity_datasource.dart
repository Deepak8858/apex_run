import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/activity.dart';

class ActivityDataSource {
  final SupabaseClient _supabase;

  ActivityDataSource(this._supabase);

  /// Create a new activity using RPC function for PostGIS support
  Future<String> createActivity(Activity activity) async {
    final response = await _supabase.rpc(
      'insert_activity',
      params: activity.toSupabaseInsertParams(),
    );
    return response as String;
  }

  /// Get paginated list of user's activities
  Future<List<Activity>> getActivities({
    int limit = 20,
    int offset = 0,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('activities')
        .select()
        .eq('user_id', userId)
        .order('start_time', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => Activity.fromSupabaseJson(json))
        .toList();
  }

  /// Get a single activity by ID
  Future<Activity> getActivityById(String id) async {
    final response = await _supabase
        .from('activities')
        .select()
        .eq('id', id)
        .single();

    return Activity.fromSupabaseJson(response);
  }

  /// Delete an activity
  Future<void> deleteActivity(String id) async {
    await _supabase.from('activities').delete().eq('id', id);
  }

  /// Get activities between two dates (for weekly stats)
  Future<List<Activity>> getActivitiesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('activities')
        .select()
        .eq('user_id', userId)
        .gte('start_time', start.toUtc().toIso8601String())
        .lte('start_time', end.toUtc().toIso8601String())
        .order('start_time', ascending: false);

    return (response as List)
        .map((json) => Activity.fromSupabaseJson(json))
        .toList();
  }

  /// Get total count of user's activities
  Future<int> getActivityCount() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('activities')
        .select('id')
        .eq('user_id', userId);
    return (response as List).length;
  }
}
