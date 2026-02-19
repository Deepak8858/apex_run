import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/step_tracking_service.dart';
import '../../domain/models/daily_activity.dart';
import 'app_providers.dart';

// ============================================================
// Step Tracking Service Provider (singleton)
// ============================================================

final stepTrackingServiceProvider = Provider<StepTrackingService>((ref) {
  final profile = ref.watch(profileControllerProvider).valueOrNull;

  final service = StepTrackingService(
    heightCm: profile?.heightCm ?? 170,
    weightKg: profile?.weightKg ?? 70,
    stepGoal: profile?.dailyStepGoal ?? 10000,
  );

  // Initialize the service
  service.initialize();

  ref.onDispose(() => service.dispose());
  return service;
});

// ============================================================
// Live Activity Stream
// ============================================================

final todayActivityProvider = StreamProvider<DailyActivity>((ref) {
  final service = ref.watch(stepTrackingServiceProvider);
  // Emit current state first, then stream updates
  try {
    final current = service.getTodayActivity();
    return Stream.value(current)
        .asyncExpand((_) => service.activityStream);
  } catch (_) {
    // If box isn't ready yet, just listen to the stream
    return service.activityStream;
  }
});

/// Today's activity snapshot (non-streaming, for initial display)
final todayActivitySnapshotProvider = Provider<DailyActivity>((ref) {
  final service = ref.watch(stepTrackingServiceProvider);
  try {
    return service.getTodayActivity();
  } catch (_) {
    // Return default if Hive box isn't ready yet
    return DailyActivity(date: DateTime.now());
  }
});

// ============================================================
// Historical Data Providers
// ============================================================

final weeklyActivityProvider = Provider<List<DailyActivity>>((ref) {
  final service = ref.watch(stepTrackingServiceProvider);
  try {
    return service.getHistory(days: 7);
  } catch (_) {
    return [];
  }
});

final monthlyActivityProvider = Provider<List<DailyActivity>>((ref) {
  final service = ref.watch(stepTrackingServiceProvider);
  try {
    return service.getHistory(days: 30);
  } catch (_) {
    return [];
  }
});

// ============================================================
// Step Goal Provider
// ============================================================

final stepGoalProvider = Provider<int>((ref) {
  final profile = ref.watch(profileControllerProvider).valueOrNull;
  return profile?.dailyStepGoal ?? 10000;
});
