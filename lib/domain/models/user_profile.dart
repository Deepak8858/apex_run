import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
class UserProfile with _$UserProfile {
  const UserProfile._();

  const factory UserProfile({
    required String id,
    String? displayName,
    String? avatarUrl,
    String? bio,
    double? homeLatitude,
    double? homeLongitude,
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
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      homeLatitude: (json['home_latitude'] as num?)?.toDouble(),
      homeLongitude: (json['home_longitude'] as num?)?.toDouble(),
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
      'avatar_url': avatarUrl,
      'bio': bio,
      'privacy_radius_meters': privacyRadiusMeters,
      'preferred_distance_unit': preferredDistanceUnit,
      'preferred_pace_format': preferredPaceFormat,
    };
  }

  bool get hasHomeLocation =>
      homeLatitude != null && homeLongitude != null;
}
