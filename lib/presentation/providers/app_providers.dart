import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/activity_datasource.dart';
import '../../data/datasources/workout_datasource.dart';
import '../../data/datasources/coaching_datasource.dart';
import '../../data/datasources/profile_datasource.dart';
import '../../data/datasources/segment_datasource.dart';
import '../../data/datasources/social_datasource.dart';
import '../../data/services/achievement_service.dart';
import '../../data/services/adaptive_plan_service.dart';
import '../../data/services/audio_coach_service.dart';
import '../../data/services/challenge_service.dart';
import '../../data/services/deep_link_service.dart';
import '../../data/services/highlight_reel_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/recovery_score_service.dart';
import '../../data/services/referral_service.dart';
import '../../data/services/streak_service.dart';
import '../../data/services/subscription_service.dart';
import '../../core/network/dio_client.dart';
import '../../domain/models/achievement.dart';
import '../../domain/models/subscription_tier.dart';
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

// ============================================================
// Service Providers (Phase 3)
// ============================================================

final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService(ref.watch(supabaseClientProvider));
});

final audioCoachServiceProvider = Provider<AudioCoachService>((ref) {
  final svc = AudioCoachService();
  ref.onDispose(svc.dispose);
  return svc;
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final svc = NotificationService(ref.watch(supabaseClientProvider));
  ref.onDispose(svc.dispose);
  return svc;
});

// ============================================================
// Subscription / Entitlements (Phase 4)
// ============================================================

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(ref.watch(supabaseClientProvider));
});

/// Stream of current entitlements; updates live as RevenueCat webhook
/// writes to Supabase. Defaults to free tier on cold start.
final entitlementsProvider = StreamProvider<Entitlements>((ref) {
  final svc = ref.watch(subscriptionServiceProvider);
  return svc.watch();
});

// ============================================================
// Social (Phase 4)
// ============================================================

final socialDataSourceProvider = Provider<SocialDataSource>((ref) {
  return SocialDataSource(ref.watch(supabaseClientProvider));
});

final friendsFeedProvider = FutureProvider.autoDispose((ref) async {
  final ds = ref.watch(socialDataSourceProvider);
  return ds.friendsFeed(limit: 25);
});

final pendingFriendRequestsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  return ref.watch(socialDataSourceProvider).pendingIncoming();
});

// ============================================================
// Achievements (Phase 4)
// ============================================================

final achievementServiceProvider = Provider<AchievementService>((ref) {
  return AchievementService(ref.watch(supabaseClientProvider));
});

final achievementCatalogProvider = FutureProvider<List<Achievement>>((
  ref,
) async {
  return ref.watch(achievementServiceProvider).catalog();
});

final myAchievementsProvider =
    FutureProvider.autoDispose<List<UnlockedAchievement>>((ref) async {
      return ref.watch(achievementServiceProvider).myUnlocked(limit: 20);
    });

// ============================================================
// Challenges (Phase 5)
// ============================================================

final challengeServiceProvider = Provider<ChallengeService>((ref) {
  return ChallengeService(ref.watch(supabaseClientProvider));
});

final activeChallengesProvider = FutureProvider.autoDispose<List<Challenge>>((
  ref,
) async {
  final svc = ref.watch(challengeServiceProvider);
  await svc.autoEnrollActive();
  return svc.activeWithProgress();
});

// ============================================================
// Highlight reels (Phase 5)
// ============================================================

final highlightReelServiceProvider = Provider<HighlightReelService>((ref) {
  return HighlightReelService();
});

// ============================================================
// Referrals + Recovery + Deep Links (Phase 5)
// ============================================================

final referralServiceProvider = Provider<ReferralService>((ref) {
  return ReferralService(ref.watch(supabaseClientProvider));
});

final myReferralCodeProvider = FutureProvider.autoDispose<String?>((ref) async {
  return ref.watch(referralServiceProvider).myCode();
});

final recoveryScoreServiceProvider = Provider<RecoveryScoreService>((ref) {
  return RecoveryScoreService(ref.watch(supabaseClientProvider));
});

final adaptivePlanServiceProvider = Provider<AdaptivePlanService>((ref) {
  return AdaptivePlanService();
});

final todayRecoveryProvider = FutureProvider.autoDispose<RecoveryScore?>((
  ref,
) async {
  final svc = ref.watch(recoveryScoreServiceProvider);
  final existing = await svc.latestForToday();
  if (existing != null) return existing;

  // Recompute on demand from last-28-day activities when no row yet.
  final supabase = ref.watch(supabaseClientProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return null;
  final since = DateTime.now().subtract(const Duration(days: 28));
  final rows = await supabase
      .from('activities')
      .select(
        'id, user_id, activity_name, activity_type, distance_meters, '
        'duration_seconds, avg_pace_min_per_km, max_speed_kmh, '
        'elevation_gain_meters, elevation_loss_meters, '
        'avg_heart_rate, max_heart_rate, start_time, end_time, '
        'is_private, created_at',
      )
      .eq('user_id', user.id)
      .gte('start_time', since.toUtc().toIso8601String());
  final activities = (rows as List)
      .map((j) => Activity.fromSupabaseJson(j as Map<String, dynamic>))
      .toList();
  return svc.computeAndPersist(last28Days: activities);
});

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final svc = DeepLinkService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Activity data source for detail screen (delete, etc.)
final activityDataSourceForDetailProvider = Provider<ActivityDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ActivityDataSource(supabase);
});

/// Single activity detail provider
final activityDetailProvider = FutureProvider.autoDispose
    .family<Activity, String>((ref, id) async {
      final supabase = ref.watch(supabaseClientProvider);
      final ds = ActivityDataSource(supabase);
      return ds.getActivityById(id);
    });

// ============================================================
// Profile Providers
// ============================================================

final userProfileProvider = FutureProvider.autoDispose<UserProfile?>((
  ref,
) async {
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

final recentActivitiesProvider = FutureProvider.autoDispose<List<Activity>>((
  ref,
) async {
  final supabase = ref.watch(supabaseClientProvider);
  final ds = ActivityDataSource(supabase);
  return ds.getActivitiesPage(limit: 5);
});

final weeklyStatsProvider = FutureProvider.autoDispose<WeeklyStats>((
  ref,
) async {
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

final todaysWorkoutProvider = FutureProvider.autoDispose<PlannedWorkout?>((
  ref,
) async {
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
  final bool isGeneratingPlan;
  final PlannedWorkout? generatedWorkout;
  final AdaptivePlanSummary? planSummary;
  final String? coachingInsight;
  final String? errorMessage;

  const CoachState({
    this.isGenerating = false,
    this.isGeneratingPlan = false,
    this.generatedWorkout,
    this.planSummary,
    this.coachingInsight,
    this.errorMessage,
  });

  CoachState copyWith({
    bool? isGenerating,
    bool? isGeneratingPlan,
    PlannedWorkout? generatedWorkout,
    AdaptivePlanSummary? planSummary,
    String? coachingInsight,
    String? errorMessage,
  }) {
    return CoachState(
      isGenerating: isGenerating ?? this.isGenerating,
      isGeneratingPlan: isGeneratingPlan ?? this.isGeneratingPlan,
      generatedWorkout: generatedWorkout ?? this.generatedWorkout,
      planSummary: planSummary ?? this.planSummary,
      coachingInsight: coachingInsight ?? this.coachingInsight,
      errorMessage: errorMessage,
    );
  }
}

class CoachController extends StateNotifier<CoachState> {
  final Ref _ref;

  CoachController(this._ref) : super(const CoachState());

  Future<void> generateAdaptivePlan({
    TrainingPlanGoal goal = TrainingPlanGoal.tenK,
    int weeks = 4,
  }) async {
    final user = _ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'Please sign in to build a plan');
      return;
    }

    state = state.copyWith(isGeneratingPlan: true, errorMessage: null);

    try {
      final supabase = _ref.read(supabaseClientProvider);
      final activityDs = ActivityDataSource(supabase);
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final recentActivities = await activityDs.getActivitiesBetween(
        weekAgo,
        now,
      );
      final weeklyStats = WeeklyStats.fromActivities(recentActivities);

      int? recoveryScore;
      try {
        recoveryScore = (await _ref.read(todayRecoveryProvider.future))?.score;
      } catch (_) {
        recoveryScore = null;
      }

      final trainingDays = weeklyStats.runCount >= 4
          ? const [
              DateTime.monday,
              DateTime.tuesday,
              DateTime.thursday,
              DateTime.saturday,
            ]
          : const [DateTime.monday, DateTime.wednesday, DateTime.saturday];

      final plan = _ref
          .read(adaptivePlanServiceProvider)
          .generatePlan(
            AdaptivePlanOptions(
              userId: user.id,
              goal: goal,
              startDate: now.add(const Duration(days: 1)),
              weeks: weeks,
              trainingWeekdays: trainingDays,
              currentWeeklyDistanceMeters: weeklyStats.totalDistanceMeters,
              recoveryScore: recoveryScore,
            ),
          );

      await _ref.read(workoutDataSourceProvider).createWorkouts(plan.workouts);

      state = state.copyWith(
        isGeneratingPlan: false,
        planSummary: plan.summary,
      );
      _ref.invalidate(todaysWorkoutProvider);
      _ref.invalidate(upcomingWorkoutsProvider);
    } catch (e) {
      state = state.copyWith(
        isGeneratingPlan: false,
        errorMessage: 'Failed to build plan: ${_friendlyError(e)}',
      );
    }
  }

  Future<void> generateDailyWorkout() async {
    final user = _ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'Please sign in to generate workouts',
      );
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

        state = state.copyWith(isGenerating: false, generatedWorkout: saved);
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
        recentActivities = await activityDs.getActivitiesBetween(weekAgo, now);
      } catch (_) {
        // Continue with empty list
      }

      final coachingDs = _ref.read(coachingDataSourceProvider);
      final insight = await coachingDs.getCoachingInsight(
        recentActivities: recentActivities,
      );

      state = state.copyWith(isGenerating: false, coachingInsight: insight);
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

final segmentsProvider = FutureProvider<List<Segment>>((ref) async {
  final ds = ref.watch(segmentDataSourceProvider);
  return await ds.getSegments();
});

final segmentLeaderboardProvider =
    FutureProvider.family<List<SegmentEffort>, String>((ref, segmentId) async {
      final ds = ref.watch(segmentDataSourceProvider);
      return ds.getLeaderboard(segmentId);
    });

final selectedSegmentProvider = StateProvider<Segment?>((ref) => null);
