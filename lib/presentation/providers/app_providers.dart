import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/activity_datasource.dart';
import '../../data/datasources/workout_datasource.dart';
import '../../data/datasources/coaching_datasource.dart';
import '../../data/datasources/profile_datasource.dart';
import '../../data/datasources/segment_datasource.dart';
import '../../core/network/dio_client.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/weekly_stats.dart';
import '../../domain/models/planned_workout.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/segment.dart';
import '../../domain/models/segment_effort.dart';
import 'auth_provider.dart';

// ============================================================
// Data Source Providers
// ============================================================

final profileDataSourceProvider = Provider<ProfileDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ProfileDataSource(supabase);
});

final workoutDataSourceProvider = Provider<WorkoutDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return WorkoutDataSource(supabase);
});

final coachingDataSourceProvider = Provider<CoachingDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return CoachingDataSource(supabase: supabase);
});

final segmentDataSourceProvider = Provider<SegmentDataSource>((ref) {
  return SegmentDataSource(DioClient.instance);
});

/// Activity data source for detail screen (delete, etc.)
final activityDataSourceForDetailProvider =
    Provider<ActivityDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ActivityDataSource(supabase);
});

/// Single activity detail provider
final activityDetailProvider =
    FutureProvider.autoDispose.family<Activity, String>((ref, id) async {
  final supabase = ref.watch(supabaseClientProvider);
  final ds = ActivityDataSource(supabase);
  return ds.getActivityById(id);
});

// ============================================================
// Profile Providers
// ============================================================

final userProfileProvider = FutureProvider.autoDispose<UserProfile?>((ref) async {
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  if (user == null) return null;
  final ds = ref.watch(profileDataSourceProvider);
  return ds.getProfile(user.id);
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<UserProfile?>>((ref) {
  return ProfileController(ref);
});

class ProfileController extends StateNotifier<AsyncValue<UserProfile?>> {
  final Ref _ref;

  ProfileController(this._ref) : super(const AsyncValue.loading()) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      final ds = _ref.read(profileDataSourceProvider);
      final profile = await ds.getProfile(user.id);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    double? heightCm,
    double? weightKg,
    int? age,
    String? gender,
    String? fitnessGoal,
    int? dailyStepGoal,
    bool? profileCompleted,
    int? privacyRadiusMeters,
    String? preferredDistanceUnit,
    String? preferredPaceFormat,
  }) async {
    final user = _ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    try {
      final ds = _ref.read(profileDataSourceProvider);
      final updated = await ds.updateProfile(
        userId: user.id,
        displayName: displayName,
        username: username,
        bio: bio,
        heightCm: heightCm,
        weightKg: weightKg,
        age: age,
        gender: gender,
        fitnessGoal: fitnessGoal,
        dailyStepGoal: dailyStepGoal,
        profileCompleted: profileCompleted,
        privacyRadiusMeters: privacyRadiusMeters,
        preferredDistanceUnit: preferredDistanceUnit,
        preferredPaceFormat: preferredPaceFormat,
      );
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> upsertProfile(UserProfile profile) async {
    try {
      final ds = _ref.read(profileDataSourceProvider);
      final result = await ds.upsertProfile(profile);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _loadProfile();
}

// ============================================================
// Activity Providers
// ============================================================

/// Reimport activityDataSourceProvider if not already defined elsewhere
/// (it's in tracking_provider.dart, re-exported here for convenience)

final recentActivitiesProvider =
    FutureProvider.autoDispose<List<Activity>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final ds = ActivityDataSource(supabase);
  return ds.getActivities(limit: 5);
});

final weeklyStatsProvider =
    FutureProvider.autoDispose<WeeklyStats>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final ds = ActivityDataSource(supabase);
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final startOfWeek = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final activities = await ds.getActivitiesBetween(startOfWeek, now);
  return WeeklyStats.fromActivities(activities);
});

final activityCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final ds = ActivityDataSource(supabase);
  return ds.getActivityCount();
});

// ============================================================
// Workout/Coaching Providers
// ============================================================

final todaysWorkoutProvider =
    FutureProvider.autoDispose<PlannedWorkout?>((ref) async {
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  if (user == null) return null;
  try {
    final ds = ref.watch(workoutDataSourceProvider);
    return await ds.getTodaysWorkout(user.id);
  } catch (e) {
    debugPrint('todaysWorkoutProvider error: $e');
    return null;
  }
});

final upcomingWorkoutsProvider =
    FutureProvider.autoDispose<List<PlannedWorkout>>((ref) async {
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  if (user == null) return [];
  try {
    final ds = ref.watch(workoutDataSourceProvider);
    return await ds.getUpcomingWorkouts(user.id);
  } catch (e) {
    debugPrint('upcomingWorkoutsProvider error: $e');
    return [];
  }
});

final coachControllerProvider =
    StateNotifierProvider<CoachController, CoachState>((ref) {
  return CoachController(ref);
});

class CoachState {
  final bool isGenerating;
  final PlannedWorkout? generatedWorkout;
  final String? coachingInsight;
  final String? errorMessage;

  const CoachState({
    this.isGenerating = false,
    this.generatedWorkout,
    this.coachingInsight,
    this.errorMessage,
  });

  CoachState copyWith({
    bool? isGenerating,
    PlannedWorkout? generatedWorkout,
    String? coachingInsight,
    String? errorMessage,
  }) {
    return CoachState(
      isGenerating: isGenerating ?? this.isGenerating,
      generatedWorkout: generatedWorkout ?? this.generatedWorkout,
      coachingInsight: coachingInsight ?? this.coachingInsight,
      errorMessage: errorMessage,
    );
  }
}

class CoachController extends StateNotifier<CoachState> {
  final Ref _ref;

  CoachController(this._ref) : super(const CoachState());

  Future<void> generateDailyWorkout() async {
    final user = _ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'Please sign in to generate workouts');
      return;
    }

    state = state.copyWith(isGenerating: true, errorMessage: null);

    try {
      // Fetch recent activities for AI context
      final supabase = _ref.read(supabaseClientProvider);
      final activityDs = ActivityDataSource(supabase);
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      List<Activity> recentActivities = [];
      try {
        recentActivities = await activityDs.getActivitiesBetween(weekAgo, now);
      } catch (_) {
        // Continue with empty activities — AI/fallback can handle it
      }

      final weeklyStats = WeeklyStats.fromActivities(recentActivities);

      // Generate workout via Gemini (with smart fallback)
      final coachingDs = _ref.read(coachingDataSourceProvider);
      final workout = await coachingDs.generateDailyWorkout(
        userId: user.id,
        recentActivities: recentActivities,
        weeklyStats: weeklyStats,
      );

      if (workout != null) {
        // Try to save to Supabase (may fail if table doesn't exist)
        PlannedWorkout? saved;
        try {
          final workoutDs = _ref.read(workoutDataSourceProvider);
          saved = await workoutDs.createWorkout(workout);
        } catch (e) {
          // Save failed — still show the generated workout
          debugPrint('Failed to save workout: $e');
          saved = workout;
        }

        state = state.copyWith(
          isGenerating: false,
          generatedWorkout: saved,
        );
        // Refresh the today's workout provider
        _ref.invalidate(todaysWorkoutProvider);
        _ref.invalidate(upcomingWorkoutsProvider);
      } else {
        state = state.copyWith(
          isGenerating: false,
          errorMessage: 'Could not generate a workout. Try again.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'Failed to generate workout: ${_friendlyError(e)}',
      );
    }
  }

  Future<void> getCoachingInsight() async {
    state = state.copyWith(isGenerating: true, errorMessage: null);

    try {
      final supabase = _ref.read(supabaseClientProvider);
      final activityDs = ActivityDataSource(supabase);
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      List<Activity> recentActivities = [];
      try {
        recentActivities =
            await activityDs.getActivitiesBetween(weekAgo, now);
      } catch (_) {
        // Continue with empty list
      }

      final coachingDs = _ref.read(coachingDataSourceProvider);
      final insight = await coachingDs.getCoachingInsight(
        recentActivities: recentActivities,
      );

      state = state.copyWith(
        isGenerating: false,
        coachingInsight: insight,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'Failed to get coaching insight: ${_friendlyError(e)}',
      );
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('NetworkException')) {
      return 'Network connection failed. Check your internet.';
    }
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Please sign in again.';
    }
    if (msg.contains('API key')) {
      return 'AI service configuration error.';
    }
    if (msg.length > 100) return '${msg.substring(0, 100)}...';
    return msg;
  }
}

// ============================================================
// Segment / Leaderboard Providers
// ============================================================

final segmentsProvider =
    FutureProvider<List<Segment>>((ref) async {
  final ds = ref.watch(segmentDataSourceProvider);
  return await ds.getSegments();
});

final segmentLeaderboardProvider = FutureProvider
    .family<List<SegmentEffort>, String>((ref, segmentId) async {
  final ds = ref.watch(segmentDataSourceProvider);
  return ds.getLeaderboard(segmentId);
});

final selectedSegmentProvider = StateProvider<Segment?>((ref) => null);
