import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_activity.freezed.dart';
part 'daily_activity.g.dart';

@freezed
class DailyActivity with _$DailyActivity {
  const DailyActivity._();

  const factory DailyActivity({
    required DateTime date,
    @Default(0) int steps,
    @Default(10000) int stepGoal,
    @Default(0.0) double caloriesBurned,
    @Default(0.0) double distanceKm,
    @Default(0) int activeMinutes,
  }) = _DailyActivity;

  factory DailyActivity.fromJson(Map<String, dynamic> json) =>
      _$DailyActivityFromJson(json);

  /// Progress toward step goal (0.0 to 1.0, capped at 1.0)
  double get goalProgress => stepGoal > 0
      ? (steps / stepGoal).clamp(0.0, 1.0)
      : 0.0;

  /// Whether the step goal has been met
  bool get goalReached => steps >= stepGoal;

  /// Formatted distance string
  String get formattedDistance => distanceKm >= 1.0
      ? '${distanceKm.toStringAsFixed(1)} km'
      : '${(distanceKm * 1000).toInt()} m';

  /// Formatted calorie string
  String get formattedCalories => caloriesBurned.toInt().toString();
}
