import 'package:freezed_annotation/freezed_annotation.dart';

part 'segment_effort.freezed.dart';
part 'segment_effort.g.dart';

@freezed
class SegmentEffort with _$SegmentEffort {
  const SegmentEffort._();

  const factory SegmentEffort({
    String? id,
    required String segmentId,
    required String activityId,
    required String userId,
    required int elapsedSeconds,
    required double avgPaceMinPerKm,
    int? avgHeartRate,
    double? maxSpeedKmh,
    required DateTime recordedAt,
    String? displayName,
    DateTime? createdAt,
  }) = _SegmentEffort;

  factory SegmentEffort.fromJson(Map<String, dynamic> json) =>
      _$SegmentEffortFromJson(json);

  factory SegmentEffort.fromSupabaseJson(Map<String, dynamic> json) {
    return SegmentEffort(
      id: json['id'] as String?,
      segmentId: json['segment_id'] as String,
      activityId: json['activity_id'] as String,
      userId: json['user_id'] as String,
      elapsedSeconds: json['elapsed_seconds'] as int,
      avgPaceMinPerKm: (json['avg_pace_min_per_km'] as num).toDouble(),
      avgHeartRate: json['avg_heart_rate'] as int?,
      maxSpeedKmh: (json['max_speed_kmh'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      displayName: json['display_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  String get formattedTime {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    final totalSeconds = (avgPaceMinPerKm * 60).round();
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')} /km';
  }
}
