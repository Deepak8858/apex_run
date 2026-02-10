import 'package:freezed_annotation/freezed_annotation.dart';

part 'planned_workout.freezed.dart';
part 'planned_workout.g.dart';

@freezed
class PlannedWorkout with _$PlannedWorkout {
  const PlannedWorkout._();

  const factory PlannedWorkout({
    String? id,
    required String userId,
    required String workoutType,
    required String description,
    double? targetDistanceMeters,
    int? targetDurationMinutes,
    String? coachingRationale,
    required DateTime plannedDate,
    @Default(false) bool isCompleted,
    String? completedActivityId,
    DateTime? createdAt,
  }) = _PlannedWorkout;

  factory PlannedWorkout.fromJson(Map<String, dynamic> json) =>
      _$PlannedWorkoutFromJson(json);

  factory PlannedWorkout.fromSupabaseJson(Map<String, dynamic> json) {
    return PlannedWorkout(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      workoutType: json['workout_type'] as String,
      description: json['description'] as String,
      targetDistanceMeters:
          (json['target_distance_meters'] as num?)?.toDouble(),
      targetDurationMinutes: json['target_duration_minutes'] as int?,
      coachingRationale: json['coaching_rationale'] as String?,
      plannedDate: DateTime.parse(json['planned_date'] as String),
      isCompleted: (json['is_completed'] as bool?) ?? false,
      completedActivityId: json['completed_activity_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'user_id': userId,
      'workout_type': workoutType,
      'description': description,
      'target_distance_meters': targetDistanceMeters,
      'target_duration_minutes': targetDurationMinutes,
      'coaching_rationale': coachingRationale,
      'planned_date': plannedDate.toIso8601String().split('T').first,
      'is_completed': isCompleted,
      'completed_activity_id': completedActivityId,
    };
  }

  String get formattedType {
    switch (workoutType) {
      case 'easy':
        return 'Easy Run';
      case 'tempo':
        return 'Tempo Run';
      case 'intervals':
        return 'Intervals';
      case 'long_run':
        return 'Long Run';
      case 'recovery':
        return 'Recovery';
      case 'race':
        return 'Race';
      default:
        return workoutType;
    }
  }

  String? get formattedTargetDistance {
    if (targetDistanceMeters == null) return null;
    if (targetDistanceMeters! >= 1000) {
      return '${(targetDistanceMeters! / 1000).toStringAsFixed(1)} km';
    }
    return '${targetDistanceMeters!.toStringAsFixed(0)} m';
  }

  String? get formattedTargetDuration {
    if (targetDurationMinutes == null) return null;
    if (targetDurationMinutes! >= 60) {
      final hours = targetDurationMinutes! ~/ 60;
      final mins = targetDurationMinutes! % 60;
      return '${hours}h ${mins}m';
    }
    return '${targetDurationMinutes}m';
  }
}
