import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/env.dart';
import '../../core/utils/gps_utils.dart';
import '../../core/utils/permission_utils.dart';
import '../../data/datasources/activity_datasource.dart';
import '../../data/services/gps_tracking_service.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/tracking_metrics.dart';
import 'auth_provider.dart';
import 'app_providers.dart';

/// Provider for the GPS tracking service singleton
final gpsTrackingServiceProvider = Provider<GpsTrackingService>((ref) {
  final service = GpsTrackingService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider for real-time tracking metrics
final trackingMetricsProvider = StreamProvider<TrackingMetrics>((ref) {
  final service = ref.watch(gpsTrackingServiceProvider);
  return service.metricsStream;
});

/// Provider for current tracking state
final trackingStateProvider = StateProvider<TrackingState>((ref) {
  return TrackingState.idle;
});

/// Provider for ActivityDataSource
final activityDataSourceProvider = Provider<ActivityDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ActivityDataSource(supabase);
});

/// Controller for tracking actions (start/pause/resume/stop/save)
final trackingControllerProvider =
    StateNotifierProvider<TrackingController, TrackingControllerState>((ref) {
  return TrackingController(ref);
});

class TrackingControllerState {
  final TrackingState trackingState;
  final Activity? lastSavedActivity;
  final String? errorMessage;
  final bool isSaving;

  const TrackingControllerState({
    this.trackingState = TrackingState.idle,
    this.lastSavedActivity,
    this.errorMessage,
    this.isSaving = false,
  });

  TrackingControllerState copyWith({
    TrackingState? trackingState,
    Activity? lastSavedActivity,
    String? errorMessage,
    bool? isSaving,
  }) {
    return TrackingControllerState(
      trackingState: trackingState ?? this.trackingState,
      lastSavedActivity: lastSavedActivity ?? this.lastSavedActivity,
      errorMessage: errorMessage,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class TrackingController extends StateNotifier<TrackingControllerState> {
  final Ref _ref;

  TrackingController(this._ref) : super(const TrackingControllerState());

  GpsTrackingService get _service =>
      _ref.read(gpsTrackingServiceProvider);

  Future<PermissionResult> startTracking() async {
    final result = await PermissionUtils.requestLocationPermission();
    if (result != PermissionResult.granted) {
      state = state.copyWith(
        errorMessage: null,
      );
      return result;
    }

    await _service.startTracking();
    state = state.copyWith(
      trackingState: TrackingState.tracking,
      errorMessage: null,
      lastSavedActivity: null,
    );
    return PermissionResult.granted;
  }

  void pauseTracking() {
    _service.pauseTracking();
    state = state.copyWith(trackingState: TrackingState.paused);
  }

  void resumeTracking() {
    _service.resumeTracking();
    state = state.copyWith(trackingState: TrackingState.tracking);
  }

  Future<Activity?> stopAndSaveTracking() async {
    final user = _ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'Not authenticated');
      return null;
    }

    var activity = _service.stopTracking(userId: user.id);
    state = state.copyWith(
      trackingState: TrackingState.idle,
      isSaving: true,
    );

    // Phase 4d: Apply privacy shroud — blur route near user's home
    activity = _applyPrivacyShroud(activity);

    // Only save if there's meaningful data
    if (activity.distanceMeters < 10 || activity.durationSeconds < 5) {
      state = state.copyWith(
        isSaving: false,
        lastSavedActivity: activity,
      );
      return activity;
    }

    try {
      final dataSource = _ref.read(activityDataSourceProvider);
      await dataSource.createActivity(activity);
      state = state.copyWith(
        isSaving: false,
        lastSavedActivity: activity,
      );
      return activity;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save activity: $e',
        lastSavedActivity: activity,
      );
      return activity;
    }
  }

  void discardTracking() {
    if (_service.state != TrackingState.idle) {
      final user = _ref.read(supabaseClientProvider).auth.currentUser;
      _service.stopTracking(userId: user?.id ?? '');
    }
    state = const TrackingControllerState();
  }

  /// Phase 4d: Privacy shroud — blur GPS points near user's home location.
  /// Removes first/last 200m (configurable) of route data near home to
  /// protect the user's residence location.
  Activity _applyPrivacyShroud(Activity activity) {
    if (!Env.enablePrivacyShroud) return activity;
    if (activity.rawGpsPoints.isEmpty) return activity;

    try {
      final profile = _ref.read(profileControllerProvider).valueOrNull;
      if (profile == null || !profile.hasHomeLocation) return activity;

      final shroudedPoints = GpsUtils.blurNearHome(
        activity.rawGpsPoints,
        profile.homeLatitude!,
        profile.homeLongitude!,
        profile.privacyRadiusMeters.toDouble(),
      );

      if (shroudedPoints.length < 2) return activity;

      // Recalculate distance after shroud
      final newDistance = GpsUtils.totalDistance(shroudedPoints);

      return activity.copyWith(
        rawGpsPoints: shroudedPoints,
        distanceMeters: newDistance,
      );
    } catch (_) {
      // Fail silently — better to save with full route than fail
      return activity;
    }
  }
}
