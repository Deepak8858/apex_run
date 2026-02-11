import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'models/hrv_data.dart';

/// HrvService — Health Data Integration for Recovery Tracking
///
/// Integrates with Apple HealthKit (iOS) and Google Health Connect (Android)
/// to fetch Heart Rate Variability and sleep data for the AI Coach.
///
/// The AI Coach uses HRV trends to:
/// - Calibrate daily training intensity
/// - Detect overtraining early
/// - Recommend recovery days
/// - Adjust planned workout difficulty
///
/// HRV Interpretation Guide:
/// - RMSSD > 80ms: Well-recovered, ready for hard training
/// - RMSSD 50-80ms: Moderately recovered, normal training
/// - RMSSD 30-50ms: Under-recovered, easy day recommended
/// - RMSSD < 30ms: Very stressed/fatigued, rest recommended
class HrvService {
  final List<HrvData> _history = [];
  double? _baselineRmssd;
  Timer? _morningCheckTimer;
  bool _authorized = false;

  /// The health plugin instance
  final Health _health = Health();

  /// Get the latest HRV reading
  HrvData? get latestReading =>
      _history.isNotEmpty ? _history.last : null;

  /// Get the 7-day baseline RMSSD
  double? get baselineRmssd => _baselineRmssd;

  /// Request permissions for health data access
  Future<bool> requestPermissions() async {
    try {
      final types = <HealthDataType>[
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        HealthDataType.HEART_RATE,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
      ];

      // On Android, also request Health Connect permissions
      if (Platform.isAndroid) {
        await Health().configure();
      }

      _authorized = await _health.requestAuthorization(
        types,
        permissions: types.map((_) => HealthDataAccess.READ).toList(),
      );

      debugPrint('HrvService: Health permissions ${_authorized ? "granted" : "denied"}');
      return _authorized;
    } catch (e) {
      debugPrint('HrvService: Permission request failed: $e');
      return false;
    }
  }

  /// Fetch today's HRV from the platform health source
  ///
  /// On iOS: Reads from HealthKit (requires entitlements)
  /// On Android: Reads from Health Connect API
  Future<HrvData?> fetchTodaysHrv() async {
    try {
      if (!_authorized) {
        final granted = await requestPermissions();
        if (!granted) {
          debugPrint('HrvService: No health permissions — using fallback');
          return null;
        }
      }

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Fetch HRV SDNN data points from today
      final hrvData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
        startTime: midnight,
        endTime: now,
      );

      // Fetch resting heart rate
      final hrData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: midnight,
        endTime: now,
      );

      if (hrvData.isEmpty) {
        debugPrint('HrvService: No HRV data available for today');
        return null;
      }

      // Use the most recent HRV reading
      final latestHrv = hrvData.last;
      final rmssd = (latestHrv.value as NumericHealthValue).numericValue.toDouble();

      // Calculate resting HR (lowest HR reading from today)
      int restingHr = 60; // default
      if (hrData.isNotEmpty) {
        restingHr = hrData
            .map((d) => (d.value as NumericHealthValue).numericValue.toInt())
            .reduce((a, b) => a < b ? a : b);
      }

      // Normalize RMSSD to 0-100 score
      final hrvScore = _rmssdToScore(rmssd);
      final recovery = assessRecovery(rmssd);

      final data = HrvData(
        rmssd: rmssd,
        sdnn: rmssd, // SDNN approximation
        restingHeartRate: restingHr,
        hrvScore: hrvScore,
        recoveryStatus: recovery,
        readinessScore: hrvScore,
        weeklyAvgRmssd: _baselineRmssd,
        measuredAt: latestHrv.dateFrom,
        source: Platform.isIOS ? HrvSource.healthKit : HrvSource.healthConnect,
      );

      _history.add(data);
      _updateBaseline();

      debugPrint('HrvService: HRV fetched — RMSSD: ${rmssd.toStringAsFixed(1)}ms, '
          'Score: $hrvScore, Recovery: ${recovery.name}');
      return data;
    } catch (e) {
      debugPrint('HrvService: Failed to fetch HRV: $e');
      return null;
    }
  }

  /// Fetch sleep data from the platform health source
  Future<SleepSummary?> fetchLastNightSleep() async {
    try {
      if (!_authorized) {
        final granted = await requestPermissions();
        if (!granted) return null;
      }

      final now = DateTime.now();
      // Look back 12 hours for last night's sleep
      final sleepStart = now.subtract(const Duration(hours: 12));

      final sleepTypes = [
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
      ];

      final sleepData = await _health.getHealthDataFromTypes(
        types: sleepTypes,
        startTime: sleepStart,
        endTime: now,
      );

      if (sleepData.isEmpty) {
        debugPrint('HrvService: No sleep data available');
        return null;
      }

      // Calculate sleep metrics from data points
      int totalInBedMinutes = 0;
      int deepSleepMinutes = 0;
      int remSleepMinutes = 0;
      int asleepMinutes = 0;

      for (final point in sleepData) {
        final duration = point.dateTo.difference(point.dateFrom).inMinutes;
        switch (point.type) {
          case HealthDataType.SLEEP_IN_BED:
            totalInBedMinutes += duration;
            break;
          case HealthDataType.SLEEP_ASLEEP:
            asleepMinutes += duration;
            break;
          case HealthDataType.SLEEP_DEEP:
            deepSleepMinutes += duration;
            break;
          case HealthDataType.SLEEP_REM:
            remSleepMinutes += duration;
            break;
          default:
            break;
        }
      }

      // Use SLEEP_ASLEEP or SLEEP_IN_BED as total
      final totalMinutes = asleepMinutes > 0 ? asleepMinutes : totalInBedMinutes;
      if (totalMinutes < 30) return null; // Too little data

      final summary = SleepSummary(
        durationMinutes: totalMinutes,
        deepSleepRatio: totalMinutes > 0 ? deepSleepMinutes / totalMinutes : 0,
        remSleepRatio: totalMinutes > 0 ? remSleepMinutes / totalMinutes : 0,
        efficiency: totalInBedMinutes > 0 ? asleepMinutes / totalInBedMinutes : 0.85,
      );

      debugPrint('HrvService: Sleep fetched — ${totalMinutes}min total, '
          '${(summary.deepSleepRatio * 100).toInt()}% deep, '
          '${(summary.remSleepRatio * 100).toInt()}% REM');
      return summary;
    } catch (e) {
      debugPrint('HrvService: Failed to fetch sleep data: $e');
      return null;
    }
  }

  /// Convert RMSSD to 0-100 score
  int _rmssdToScore(double rmssd) {
    // Logarithmic scale: ln(RMSSD) maps well to perceived recovery
    // ln(20) ≈ 3.0 → 0 points, ln(80) ≈ 4.4 → 100 points
    if (rmssd <= 0) return 0;
    final lnRmssd = math.log(rmssd);
    final score = ((lnRmssd - 3.0) / 1.4 * 100).round();
    return score.clamp(0, 100);
  }

  /// Add a manual HRV reading (e.g., from a connected wearable)
  void addManualReading(HrvData data) {
    _history.add(data);
    _updateBaseline();
  }

  /// Calculate the morning readiness score combining HRV + sleep
  Future<int> calculateReadinessScore() async {
    final hrv = await fetchTodaysHrv();
    final sleep = await fetchLastNightSleep();

    int score = 50; // Base score

    // HRV component (up to 40 points)
    if (hrv != null && _baselineRmssd != null && _baselineRmssd! > 0) {
      final ratio = hrv.rmssd / _baselineRmssd!;
      if (ratio >= 1.1) {
        score += 40;       // Above baseline
      } else if (ratio >= 0.9) score += 30;  // Near baseline
      else if (ratio >= 0.7) score += 15;  // Below baseline
      else score += 5;                      // Well below
    } else if (hrv != null) {
      // No baseline yet — use absolute values
      if (hrv.rmssd > 70) {
        score += 35;
      } else if (hrv.rmssd > 50) score += 25;
      else if (hrv.rmssd > 30) score += 15;
      else score += 5;
    }

    // Sleep component (up to 10 points)
    if (sleep != null) {
      if (sleep.durationMinutes >= 420) score += 5; // 7+ hours
      if (sleep.deepSleepRatio >= 0.2) score += 5;  // 20%+ deep sleep
    }

    return score.clamp(0, 100);
  }

  /// Determine recovery status from HRV relative to baseline
  RecoveryStatus assessRecovery(double rmssd) {
    if (_baselineRmssd == null || _baselineRmssd! <= 0) {
      // No baseline — use absolute thresholds
      if (rmssd > 80) return RecoveryStatus.optimal;
      if (rmssd > 60) return RecoveryStatus.good;
      if (rmssd > 40) return RecoveryStatus.moderate;
      if (rmssd > 20) return RecoveryStatus.low;
      return RecoveryStatus.critical;
    }

    final ratio = rmssd / _baselineRmssd!;
    if (ratio >= 1.1) return RecoveryStatus.optimal;
    if (ratio >= 0.95) return RecoveryStatus.good;
    if (ratio >= 0.8) return RecoveryStatus.moderate;
    if (ratio >= 0.65) return RecoveryStatus.low;
    return RecoveryStatus.critical;
  }

  /// Update 7-day rolling baseline RMSSD
  void _updateBaseline() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentReadings = _history
        .where((h) => h.measuredAt.isAfter(sevenDaysAgo))
        .toList();

    if (recentReadings.length >= 3) {
      _baselineRmssd =
          recentReadings.map((h) => h.rmssd).reduce((a, b) => a + b) /
              recentReadings.length;
    }
  }

  /// Get HRV trend (positive = improving, negative = declining)
  double? getHrvTrend() {
    if (_history.length < 3) return null;

    final recent = _history.length > 7
        ? _history.sublist(_history.length - 7)
        : _history;

    // Simple linear trend
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (var i = 0; i < recent.length; i++) {
      sumX += i;
      sumY += recent[i].rmssd;
      sumXY += i * recent[i].rmssd;
      sumX2 += i * i;
    }
    final n = recent.length;
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    return slope;
  }

  /// Dispose resources
  void dispose() {
    _morningCheckTimer?.cancel();
    _history.clear();
  }
}

/// Summary of last night's sleep data
class SleepSummary {
  /// Total time in bed (minutes)
  final int durationMinutes;

  /// Ratio of deep sleep to total sleep (0.0-1.0)
  final double deepSleepRatio;

  /// Ratio of REM sleep to total sleep (0.0-1.0)
  final double remSleepRatio;

  /// Number of awakenings during the night
  final int awakenings;

  /// Sleep efficiency (actual sleep / time in bed, 0.0-1.0)
  final double efficiency;

  const SleepSummary({
    required this.durationMinutes,
    required this.deepSleepRatio,
    required this.remSleepRatio,
    this.awakenings = 0,
    this.efficiency = 0.85,
  });

  /// Sleep quality score (0-100)
  int get qualityScore {
    int score = 0;
    // Duration component (max 40)
    if (durationMinutes >= 480) {
      score += 40;       // 8+ hours
    } else if (durationMinutes >= 420) score += 35;  // 7-8 hours
    else if (durationMinutes >= 360) score += 25;  // 6-7 hours
    else score += 10;

    // Deep sleep component (max 25)
    if (deepSleepRatio >= 0.25) {
      score += 25;
    } else if (deepSleepRatio >= 0.20) score += 20;
    else if (deepSleepRatio >= 0.15) score += 15;
    else score += 5;

    // REM component (max 20)
    if (remSleepRatio >= 0.25) {
      score += 20;
    } else if (remSleepRatio >= 0.20) score += 15;
    else score += 5;

    // Efficiency component (max 15)
    if (efficiency >= 0.90) {
      score += 15;
    } else if (efficiency >= 0.85) score += 10;
    else score += 5;

    return score.clamp(0, 100);
  }
}
