/// Heart Rate Variability data model.
///
/// HRV is a key recovery metric — higher HRV indicates better recovery.
/// Used by the AI Coach for daily training plan calibration.
class HrvData {
  /// RMSSD (Root Mean Square of Successive Differences) in ms
  final double rmssd;

  /// SDNN (Standard Deviation of NN intervals) in ms
  final double? sdnn;

  /// Average resting heart rate in BPM
  final int restingHeartRate;

  /// HRV score normalized to 0-100
  final int hrvScore;

  /// Recovery status based on HRV trends
  final RecoveryStatus recoveryStatus;

  /// Sleep quality score (0-100)
  final int? sleepQualityScore;

  /// Total sleep duration in minutes
  final int? sleepDurationMinutes;

  /// Deep sleep percentage (0.0-1.0)
  final double? deepSleepRatio;

  /// Morning readiness score combining HRV + sleep + trends
  final int? readinessScore;

  /// 7-day rolling average RMSSD
  final double? weeklyAvgRmssd;

  /// Measurement timestamp
  final DateTime measuredAt;

  /// Source of the HRV data
  final HrvSource source;

  const HrvData({
    required this.rmssd,
    this.sdnn,
    required this.restingHeartRate,
    required this.hrvScore,
    required this.recoveryStatus,
    this.sleepQualityScore,
    this.sleepDurationMinutes,
    this.deepSleepRatio,
    this.readinessScore,
    this.weeklyAvgRmssd,
    required this.measuredAt,
    this.source = HrvSource.manual,
  });

  factory HrvData.fromSupabaseJson(Map<String, dynamic> json) {
    return HrvData(
      rmssd: (json['rmssd'] as num).toDouble(),
      sdnn: (json['sdnn'] as num?)?.toDouble(),
      restingHeartRate: json['resting_heart_rate'] as int,
      hrvScore: json['hrv_score'] as int,
      recoveryStatus: RecoveryStatus.values.firstWhere(
        (e) => e.name == (json['recovery_status'] as String? ?? 'moderate'),
        orElse: () => RecoveryStatus.moderate,
      ),
      sleepQualityScore: json['sleep_quality_score'] as int?,
      sleepDurationMinutes: json['sleep_duration_minutes'] as int?,
      deepSleepRatio: (json['deep_sleep_ratio'] as num?)?.toDouble(),
      readinessScore: json['readiness_score'] as int?,
      weeklyAvgRmssd: (json['weekly_avg_rmssd'] as num?)?.toDouble(),
      measuredAt: DateTime.parse(json['measured_at'] as String),
      source: HrvSource.values.firstWhere(
        (e) => e.name == (json['source'] as String? ?? 'manual'),
        orElse: () => HrvSource.manual,
      ),
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'rmssd': rmssd,
      'sdnn': sdnn,
      'resting_heart_rate': restingHeartRate,
      'hrv_score': hrvScore,
      'recovery_status': recoveryStatus.name,
      'sleep_quality_score': sleepQualityScore,
      'sleep_duration_minutes': sleepDurationMinutes,
      'deep_sleep_ratio': deepSleepRatio,
      'readiness_score': readinessScore,
      'weekly_avg_rmssd': weeklyAvgRmssd,
      'measured_at': measuredAt.toIso8601String(),
      'source': source.name,
    };
  }

  /// Determine if the athlete should train hard today
  bool get canTrainHard =>
      recoveryStatus == RecoveryStatus.optimal ||
      recoveryStatus == RecoveryStatus.good;

  /// Training recommendation based on HRV
  String get trainingRecommendation {
    switch (recoveryStatus) {
      case RecoveryStatus.optimal:
        return 'Full recovery — great day for quality training or race.';
      case RecoveryStatus.good:
        return 'Well recovered — moderate to hard training is fine.';
      case RecoveryStatus.moderate:
        return 'Easy to moderate effort recommended today.';
      case RecoveryStatus.low:
        return 'Low recovery — prioritize light running or rest.';
      case RecoveryStatus.critical:
        return 'Very low recovery — complete rest day recommended.';
    }
  }
}

/// Recovery status derived from HRV trends
enum RecoveryStatus {
  /// HRV well above baseline — peak readiness
  optimal,

  /// HRV near or slightly above baseline
  good,

  /// HRV near baseline — normal recovery
  moderate,

  /// HRV below baseline — need recovery
  low,

  /// HRV significantly below baseline — rest required
  critical,
}

/// Source of HRV measurement
enum HrvSource {
  /// Apple HealthKit
  healthKit,

  /// Google Health Connect (formerly Google Fit)
  healthConnect,

  /// Garmin Connect API
  garmin,

  /// Whoop strap
  whoop,

  /// Manual entry
  manual,
}
