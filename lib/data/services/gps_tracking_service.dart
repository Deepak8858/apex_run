import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/config/env.dart';
import '../../core/utils/gps_utils.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/gps_point.dart';
import '../../domain/models/tracking_metrics.dart';

/// GPS Tracking Service — Phase 4b upgrade
///
/// Background-capable GPS tracking using geolocator's platform-specific
/// settings. On Android, a foreground service notification keeps GPS alive
/// through OS Doze mode. On iOS, `allowBackgroundLocationUpdates` is set.
class GpsTrackingService {
  final List<GpsPoint> _recordedPoints = [];
  DateTime? _startTime;
  DateTime? _pauseTime;
  int _totalPausedSeconds = 0;
  TrackingState _state = TrackingState.idle;
  StreamSubscription<Position>? _positionSubscription;

  final _metricsController = StreamController<TrackingMetrics>.broadcast();

  Stream<TrackingMetrics> get metricsStream => _metricsController.stream;
  TrackingState get state => _state;
  List<GpsPoint> get recordedPoints => List.unmodifiable(_recordedPoints);

  /// Start GPS tracking — requests permissions then opens background-capable stream
  Future<void> startTracking() async {
    if (_state == TrackingState.tracking) return;

    // Ensure location permissions are granted
    await _ensurePermissions();

    _recordedPoints.clear();
    _startTime = DateTime.now();
    _pauseTime = null;
    _totalPausedSeconds = 0;
    _state = TrackingState.tracking;

    _emitMetrics();
    _startLocationStream();
    _startDurationTimer();
  }

  /// Pause tracking
  void pauseTracking() {
    if (_state != TrackingState.tracking) return;
    _state = TrackingState.paused;
    _pauseTime = DateTime.now();
    _positionSubscription?.pause();
    _emitMetrics();
  }

  /// Resume tracking
  void resumeTracking() {
    if (_state != TrackingState.paused) return;

    if (_pauseTime != null) {
      _totalPausedSeconds +=
          DateTime.now().difference(_pauseTime!).inSeconds;
    }
    _pauseTime = null;
    _state = TrackingState.tracking;
    _positionSubscription?.resume();
    _emitMetrics();
  }

  /// Stop tracking and return the completed activity
  Activity stopTracking({required String userId}) {
    _state = TrackingState.idle;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _durationTimer?.cancel();
    _durationTimer = null;

    final endTime = DateTime.now();
    final durationSeconds = _calculateDuration();

    final filteredPoints = GpsUtils.filterByAccuracy(
      _recordedPoints,
      Env.gpsAccuracyThresholdMeters.toDouble(),
    );

    final distance = GpsUtils.totalDistance(filteredPoints);
    final avgPace = GpsUtils.calculatePace(distance, durationSeconds);
    final maxSpeed = filteredPoints.isNotEmpty
        ? filteredPoints
            .map((p) => p.speed * 3.6)
            .reduce((a, b) => a > b ? a : b)
        : 0.0;
    final elevGain = GpsUtils.elevationGain(filteredPoints);
    final elevLoss = GpsUtils.elevationLoss(filteredPoints);

    final activity = Activity(
      userId: userId,
      activityName: 'Run ${DateTime.now().day}/${DateTime.now().month}',
      activityType: 'run',
      distanceMeters: distance,
      durationSeconds: durationSeconds,
      avgPaceMinPerKm: avgPace,
      maxSpeedKmh: maxSpeed,
      elevationGainMeters: elevGain,
      elevationLossMeters: elevLoss,
      startTime: _startTime!,
      endTime: endTime,
      rawGpsPoints: filteredPoints,
    );

    _emitMetrics();
    return activity;
  }

  /// Dispose resources
  void dispose() {
    _positionSubscription?.cancel();
    _durationTimer?.cancel();
    _metricsController.close();
  }

  /// Ensure location service is enabled and permissions are granted
  Future<void> _ensurePermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. Enable GPS to start tracking.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. '
        'Open app settings to grant permission.',
      );
    }

    // Request "always" permission for background tracking on mobile
    if (!kIsWeb &&
        (Platform.isAndroid || Platform.isIOS) &&
        permission == LocationPermission.whileInUse) {
      // We can still track with "while in use" + foreground service
      debugPrint(
        'GPS: "While in use" permission granted. '
        'Background tracking via foreground service.',
      );
    }
  }

  /// Start location stream with platform-specific background settings
  void _startLocationStream() {
    final locationSettings = _buildLocationSettings();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        debugPrint('GPS stream error: $error');
        // Continue tracking — individual point failures are tolerable
      },
    );
  }

  /// Build platform-specific location settings for background GPS
  LocationSettings _buildLocationSettings() {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: Env.gpsDistanceFilterMeters,
        intervalDuration: const Duration(seconds: 2),
        // Foreground notification keeps GPS alive during OS Doze
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'ApexRun — Tracking',
          notificationText: 'Recording your run in progress...',
          enableWakeLock: true,
          notificationIcon:
              AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        ),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: Env.gpsDistanceFilterMeters,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }

    // Fallback for other platforms
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: Env.gpsDistanceFilterMeters,
    );
  }

  void _onPositionUpdate(Position position) {
    if (_state != TrackingState.tracking) return;

    final point = GpsPoint.fromPosition(position);
    _recordedPoints.add(point);
    _emitMetrics();
  }

  Timer? _durationTimer;

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == TrackingState.tracking) {
        _emitMetrics();
      }
    });
  }

  int _calculateDuration() {
    if (_startTime == null) return 0;
    final elapsed = DateTime.now().difference(_startTime!).inSeconds;
    if (_state == TrackingState.paused && _pauseTime != null) {
      final currentPause =
          DateTime.now().difference(_pauseTime!).inSeconds;
      return elapsed - _totalPausedSeconds - currentPause;
    }
    return elapsed - _totalPausedSeconds;
  }

  void _emitMetrics() {
    final filteredPoints = GpsUtils.filterByAccuracy(
      _recordedPoints,
      Env.gpsAccuracyThresholdMeters.toDouble(),
    );

    final distance = GpsUtils.totalDistance(filteredPoints);
    final duration = _calculateDuration();
    final pace = GpsUtils.rollingPace(filteredPoints);
    final speed = filteredPoints.isNotEmpty
        ? filteredPoints.last.speed * 3.6
        : 0.0;

    _metricsController.add(TrackingMetrics(
      distanceMeters: distance,
      durationSeconds: duration,
      currentPaceMinPerKm: pace,
      currentSpeedKmh: speed,
      routePoints: List.from(_recordedPoints),
      state: _state,
    ));
  }
}
