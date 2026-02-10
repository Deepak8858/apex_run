import 'package:freezed_annotation/freezed_annotation.dart';
import 'gps_point.dart';

part 'activity.freezed.dart';
part 'activity.g.dart';

@freezed
class Activity with _$Activity {
  const Activity._();

  const factory Activity({
    String? id,
    required String userId,
    required String activityName,
    @Default('run') String activityType,
    String? description,
    required double distanceMeters,
    required int durationSeconds,
    double? avgPaceMinPerKm,
    double? maxSpeedKmh,
    double? elevationGainMeters,
    double? elevationLossMeters,
    int? avgHeartRate,
    int? maxHeartRate,
    required DateTime startTime,
    DateTime? endTime,
    @Default([]) List<GpsPoint> rawGpsPoints,
    @Default(false) bool isPrivate,
    DateTime? createdAt,
  }) = _Activity;

  factory Activity.fromJson(Map<String, dynamic> json) =>
      _$ActivityFromJson(json);

  factory Activity.fromSupabaseJson(Map<String, dynamic> json) {
    final rawPoints = json['raw_gps_points'];
    List<GpsPoint> gpsPoints = [];
    if (rawPoints is List) {
      gpsPoints = rawPoints
          .map((p) => GpsPoint.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    }

    return Activity(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      activityName: json['activity_name'] as String,
      activityType: (json['activity_type'] as String?) ?? 'run',
      description: json['description'] as String?,
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      durationSeconds: json['duration_seconds'] as int,
      avgPaceMinPerKm: (json['avg_pace_min_per_km'] as num?)?.toDouble(),
      maxSpeedKmh: (json['max_speed_kmh'] as num?)?.toDouble(),
      elevationGainMeters:
          (json['elevation_gain_meters'] as num?)?.toDouble(),
      elevationLossMeters:
          (json['elevation_loss_meters'] as num?)?.toDouble(),
      avgHeartRate: json['avg_heart_rate'] as int?,
      maxHeartRate: json['max_heart_rate'] as int?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      rawGpsPoints: gpsPoints,
      isPrivate: (json['is_private'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toSupabaseInsertParams() {
    return {
      'p_user_id': userId,
      'p_activity_name': activityName,
      'p_activity_type': activityType,
      'p_route_path_wkt': _buildWktLineString(),
      'p_distance_meters': distanceMeters,
      'p_duration_seconds': durationSeconds,
      'p_avg_pace': avgPaceMinPerKm,
      'p_max_speed': maxSpeedKmh,
      'p_elevation_gain': elevationGainMeters,
      'p_elevation_loss': elevationLossMeters,
      'p_avg_heart_rate': avgHeartRate,
      'p_max_heart_rate': maxHeartRate,
      'p_start_time': startTime.toUtc().toIso8601String(),
      'p_end_time': endTime?.toUtc().toIso8601String(),
      'p_raw_gps_points':
          rawGpsPoints.map((p) => p.toJson()).toList(),
      'p_is_private': isPrivate,
    };
  }

  String _buildWktLineString() {
    if (rawGpsPoints.length < 2) {
      return 'SRID=4326;LINESTRING(0 0, 0 0)';
    }
    final coords = rawGpsPoints
        .map((p) => '${p.longitude} ${p.latitude}')
        .join(', ');
    return 'SRID=4326;LINESTRING($coords)';
  }

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (avgPaceMinPerKm == null || avgPaceMinPerKm == 0) return '--:--';
    final totalSeconds = (avgPaceMinPerKm! * 60).round();
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')} /km';
  }
}
