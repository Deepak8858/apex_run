import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pedometer/pedometer.dart';
import '../../domain/models/daily_activity.dart';

/// Service for tracking steps while the app is in the foreground.
///
/// Uses the pedometer package for real-time step counting and
/// persists daily totals to Hive for historical trends.
class StepTrackingService {
  static const String _boxName = 'daily_activity';

  // User body metrics for calorie/distance estimation
  double _heightCm;
  double _weightKg;
  int _stepGoal;

  // Internal state
  int _sessionStartSteps = 0;
  int _todayAccumulatedSteps = 0;
  bool _initialized = false;
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianSubscription;

  // Live stream controller
  final _activityController = StreamController<DailyActivity>.broadcast();

  // Current pedestrian status (walking/stopped)
  String _pedestrianStatus = 'stopped';

  // Active minutes tracking
  DateTime? _lastActiveTimestamp;
  int _todayActiveMinutes = 0;

  StepTrackingService({
    double heightCm = 170,
    double weightKg = 70,
    int stepGoal = 10000,
  })  : _heightCm = heightCm,
        _weightKg = weightKg,
        _stepGoal = stepGoal;

  /// Update user metrics (called when profile changes)
  void updateMetrics({
    double? heightCm,
    double? weightKg,
    int? stepGoal,
  }) {
    if (heightCm != null) _heightCm = heightCm;
    if (weightKg != null) _weightKg = weightKg;
    if (stepGoal != null) _stepGoal = stepGoal;
    _emitCurrentActivity();
  }

  /// Stream of live activity updates
  Stream<DailyActivity> get activityStream => _activityController.stream;

  /// Initialize the service — call once at app start
  Future<void> initialize() async {
    if (_initialized) return;

    await Hive.openBox<Map>(_boxName);

    // Load today's accumulated steps from storage
    final today = _todayKey();
    final box = Hive.box<Map>(_boxName);
    final stored = box.get(today);
    if (stored != null) {
      _todayAccumulatedSteps = (stored['steps'] as int?) ?? 0;
      _todayActiveMinutes = (stored['activeMinutes'] as int?) ?? 0;
    }

    _initialized = true;
    _startListening();
  }

  void _startListening() {
    try {
      // Step count stream
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
      );

      // Pedestrian status stream (walking/stopped)
      _pedestrianSubscription = Pedometer.pedestrianStatusStream.listen(
        _onPedestrianStatus,
        onError: (e) => debugPrint('Pedestrian status error: $e'),
      );
    } catch (e) {
      debugPrint('Pedometer not available: $e');
    }
  }

  void _onStepCount(StepCount event) {
    if (_sessionStartSteps == 0) {
      // First reading in this session — set baseline
      _sessionStartSteps = event.steps;
    }

    final sessionSteps = event.steps - _sessionStartSteps;
    final totalSteps = _todayAccumulatedSteps + sessionSteps;

    _updateActiveMinutes();
    _emitActivity(totalSteps);
    _persistToday(totalSteps);
  }

  void _onStepCountError(dynamic error) {
    debugPrint('Step count error: $error');
  }

  void _onPedestrianStatus(PedestrianStatus event) {
    _pedestrianStatus = event.status;
    if (_pedestrianStatus == 'walking') {
      _lastActiveTimestamp ??= DateTime.now();
    } else {
      _updateActiveMinutes();
      _lastActiveTimestamp = null;
    }
  }

  void _updateActiveMinutes() {
    if (_lastActiveTimestamp != null) {
      final now = DateTime.now();
      final diff = now.difference(_lastActiveTimestamp!).inMinutes;
      if (diff > 0) {
        _todayActiveMinutes += diff;
        _lastActiveTimestamp = now;
      }
    }
  }

  void _emitActivity(int totalSteps) {
    final activity = _createActivity(totalSteps);
    _activityController.add(activity);
  }

  void _emitCurrentActivity() {
    final box = Hive.box<Map>(_boxName);
    final stored = box.get(_todayKey());
    final steps = (stored?['steps'] as int?) ?? _todayAccumulatedSteps;
    _emitActivity(steps);
  }

  DailyActivity _createActivity(int totalSteps) {
    final strideLengthM = _heightCm * 0.414 / 100;
    final distanceKm = totalSteps * strideLengthM / 1000;
    final caloriesBurned = totalSteps * _weightKg * 0.0005;

    return DailyActivity(
      date: DateTime.now(),
      steps: totalSteps,
      stepGoal: _stepGoal,
      caloriesBurned: caloriesBurned,
      distanceKm: distanceKm,
      activeMinutes: _todayActiveMinutes,
    );
  }

  Future<void> _persistToday(int totalSteps) async {
    final box = Hive.box<Map>(_boxName);
    final strideLengthM = _heightCm * 0.414 / 100;
    final distanceKm = totalSteps * strideLengthM / 1000;
    final caloriesBurned = totalSteps * _weightKg * 0.0005;

    await box.put(_todayKey(), {
      'steps': totalSteps,
      'stepGoal': _stepGoal,
      'caloriesBurned': caloriesBurned,
      'distanceKm': distanceKm,
      'activeMinutes': _todayActiveMinutes,
      'date': DateTime.now().toIso8601String(),
    });
  }

  /// Get today's current activity
  DailyActivity getTodayActivity() {
    final box = Hive.box<Map>(_boxName);
    final stored = box.get(_todayKey());
    if (stored != null) {
      return DailyActivity(
        date: DateTime.now(),
        steps: (stored['steps'] as int?) ?? 0,
        stepGoal: (stored['stepGoal'] as int?) ?? _stepGoal,
        caloriesBurned: (stored['caloriesBurned'] as num?)?.toDouble() ?? 0,
        distanceKm: (stored['distanceKm'] as num?)?.toDouble() ?? 0,
        activeMinutes: (stored['activeMinutes'] as int?) ?? 0,
      );
    }
    return DailyActivity(date: DateTime.now(), stepGoal: _stepGoal);
  }

  /// Get activity history for a date range
  List<DailyActivity> getHistory({int days = 7}) {
    final box = Hive.box<Map>(_boxName);
    final result = <DailyActivity>[];

    for (var i = days - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = _dateKey(date);
      final stored = box.get(key);

      if (stored != null) {
        result.add(DailyActivity(
          date: date,
          steps: (stored['steps'] as int?) ?? 0,
          stepGoal: (stored['stepGoal'] as int?) ?? _stepGoal,
          caloriesBurned: (stored['caloriesBurned'] as num?)?.toDouble() ?? 0,
          distanceKm: (stored['distanceKm'] as num?)?.toDouble() ?? 0,
          activeMinutes: (stored['activeMinutes'] as int?) ?? 0,
        ));
      } else {
        result.add(DailyActivity(date: date, stepGoal: _stepGoal));
      }
    }

    return result;
  }

  String _todayKey() => _dateKey(DateTime.now());

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Dispose resources
  void dispose() {
    _stepSubscription?.cancel();
    _pedestrianSubscription?.cancel();
    _activityController.close();
  }
}
