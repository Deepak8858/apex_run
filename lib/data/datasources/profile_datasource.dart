import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/user_profile.dart';

class ProfileDataSource {
  final SupabaseClient _supabase;

  ProfileDataSource(this._supabase);

  /// Get user profile by ID
  Future<UserProfile?> getProfile(String userId) async {
    final response = await _supabase
        .from('user_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return UserProfile.fromSupabaseJson(response);
  }

  /// Create or update user profile
  Future<UserProfile> upsertProfile(UserProfile profile) async {
    final response = await _supabase
        .from('user_profiles')
        .upsert(profile.toSupabaseJson())
        .select()
        .single();

    return UserProfile.fromSupabaseJson(response);
  }

  /// Update home location using RPC for PostGIS Point
  Future<void> updateHomeLocation(
    String userId,
    double lat,
    double lng,
  ) async {
    await _supabase.rpc(
      'update_home_location',
      params: {
        'p_user_id': userId,
        'p_lat': lat,
        'p_lng': lng,
      },
    );
  }

  /// Update profile fields (without home location)
  Future<UserProfile> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? avatarUrl,
    int? privacyRadiusMeters,
    String? preferredDistanceUnit,
    String? preferredPaceFormat,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (privacyRadiusMeters != null) {
      updates['privacy_radius_meters'] = privacyRadiusMeters;
    }
    if (preferredDistanceUnit != null) {
      updates['preferred_distance_unit'] = preferredDistanceUnit;
    }
    if (preferredPaceFormat != null) {
      updates['preferred_pace_format'] = preferredPaceFormat;
    }

    final response = await _supabase
        .from('user_profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return UserProfile.fromSupabaseJson(response);
  }
}
