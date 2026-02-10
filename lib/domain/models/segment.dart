import 'package:freezed_annotation/freezed_annotation.dart';

part 'segment.freezed.dart';
part 'segment.g.dart';

@freezed
class Segment with _$Segment {
  const Segment._();

  const factory Segment({
    String? id,
    required String name,
    String? description,
    required double distanceMeters,
    double? elevationGainMeters,
    String? creatorId,
    @Default(false) bool isVerified,
    @Default('run') String activityType,
    @Default(0) int totalAttempts,
    @Default(0) int uniqueAthletes,
    DateTime? createdAt,
  }) = _Segment;

  factory Segment.fromJson(Map<String, dynamic> json) =>
      _$SegmentFromJson(json);

  factory Segment.fromSupabaseJson(Map<String, dynamic> json) {
    return Segment(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      elevationGainMeters:
          (json['elevation_gain_meters'] as num?)?.toDouble(),
      creatorId: json['creator_id'] as String?,
      isVerified: (json['is_verified'] as bool?) ?? false,
      activityType: (json['activity_type'] as String?) ?? 'run',
      totalAttempts: (json['total_attempts'] as int?) ?? 0,
      uniqueAthletes: (json['unique_athletes'] as int?) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }
}
