import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
class UserProfile with _$UserProfile {
  const UserProfile._();

  const factory UserProfile({
    required String id,
    String? displayName,
    String? username,
    String? avatarUrl,
    String? bio,
    double? homeLatitude,
    double? homeLongitude,
    double? heightCm,
    double? weightKg,
    int? age,
    String? gender,
    String? fitnessGoal,
    @Default(10000) int dailyStepGoal,
    @Default(false) bool profileCompleted,
    @Default(200) int privacyRadiusMeters,
    @Default('km') String preferredDistanceUnit,
    @Default('min_per_km') String preferredPaceFormat,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  factory UserProfile.fromSupabaseJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      homeLatitude: (json['home_latitude'] as num?)?.toDouble(),
      homeLongitude: (json['home_longitude'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      fitnessGoal: json['fitness_goal'] as String?,
      dailyStepGoal: (json['daily_step_goal'] as int?) ?? 10000,
      profileCompleted: (json['profile_completed'] as bool?) ?? false,
      privacyRadiusMeters: (json['privacy_radius_meters'] as int?) ?? 200,
      preferredDistanceUnit:
          (json['preferred_distance_unit'] as String?) ?? 'km',
      preferredPaceFormat:
          (json['preferred_pace_format'] as String?) ?? 'min_per_km',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'display_name': displayName,
      'username': username,
      'avatar_url': avatarUrl,
      'bio': bio,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'age': age,
      'gender': gender,
      'fitness_goal': fitnessGoal,
      'daily_step_goal': dailyStepGoal,
      'profile_completed': profileCompleted,
      'privacy_radius_meters': privacyRadiusMeters,
      'preferred_distance_unit': preferredDistanceUnit,
      'preferred_pace_format': preferredPaceFormat,
    };
  }

  bool get hasHomeLocation =>
      homeLatitude != null && homeLongitude != null;

  /// Calculate stride length in meters from height
  double get strideLengthMeters => (heightCm ?? 170) * 0.414 / 100;

  /// Calculate calories burned per step based on weight
  double get caloriesPerStep => (weightKg ?? 70) * 0.0005;
}
