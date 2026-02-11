import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/planned_workout.dart';

class WorkoutDataSource {
  final SupabaseClient _supabase;

  WorkoutDataSource(this._supabase);

  /// Create a planned workout
  Future<PlannedWorkout> createWorkout(PlannedWorkout workout) async {
    final response = await _supabase
        .from('planned_workouts')
        .insert(workout.toSupabaseJson())
        .select()
        .single();

    return PlannedWorkout.fromSupabaseJson(response);
  }

  /// Get upcoming workouts (not completed, future dates)
  Future<List<PlannedWorkout>> getUpcomingWorkouts(String userId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final response = await _supabase
        .from('planned_workouts')
        .select()
        .eq('user_id', userId)
        .eq('is_completed', false)
        .gte('planned_date', today)
        .order('planned_date', ascending: true)
        .limit(10);

    return (response as List)
        .map((json) => PlannedWorkout.fromSupabaseJson(json))
        .toList();
  }

  /// Get workout history
  Future<List<PlannedWorkout>> getWorkoutHistory(
    String userId, {
    int limit = 20,
  }) async {
    final response = await _supabase
        .from('planned_workouts')
        .select()
        .eq('user_id', userId)
        .order('planned_date', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => PlannedWorkout.fromSupabaseJson(json))
        .toList();
  }

  /// Get today's workout
  Future<PlannedWorkout?> getTodaysWorkout(String userId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final response = await _supabase
        .from('planned_workouts')
        .select()
        .eq('user_id', userId)
        .eq('planned_date', today)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return PlannedWorkout.fromSupabaseJson(response);
  }

  /// Mark workout as completed
  Future<void> markCompleted(
      String workoutId, String activityId) async {
    await _supabase.from('planned_workouts').update({
      'is_completed': true,
      'completed_activity_id': activityId,
    }).eq('id', workoutId);
  }

  /// Delete a workout
  Future<void> deleteWorkout(String workoutId) async {
    await _supabase
        .from('planned_workouts')
        .delete()
        .eq('id', workoutId);
  }
}
