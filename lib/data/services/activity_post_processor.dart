/// Production-ready activity post-processing service
/// Calls Supabase Edge Function after activity save for:
/// - Segment matching (PostGIS)
/// - Leaderboard update
/// - ACWR calculation
/// - Training load tracking
library;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';

class ActivityPostProcessor {
  final SupabaseClient _supabase;

  ActivityPostProcessor(this._supabase);

  /// Process an activity after it's been saved
  /// Returns a map with segment matches, ACWR data, etc.
  Future<Map<String, dynamic>> processActivity({
    required String activityId,
    required String userId,
    required int elapsedSeconds,
    required double avgPace,
    int? avgHeartRate,
    double? maxSpeed,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'process-activity',
        body: {
          'activity_id': activityId,
          'user_id': userId,
          'elapsed_seconds': elapsedSeconds,
          'avg_pace': avgPace,
          'avg_heart_rate': avgHeartRate,
          'max_speed': maxSpeed,
        },
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        debugPrint(
          'Activity processed: ${data['matched_segments']} segments matched, '
          'ACWR: ${data['acwr']?['acwr'] ?? 'N/A'}',
        );
        return data;
      } else {
        debugPrint('Activity processing failed: ${response.status}');
        return {'error': 'Processing failed', 'status': response.status};
      }
    } catch (e) {
      debugPrint('Activity post-processing error: $e');
      // Non-fatal — activity is already saved
      return {'error': e.toString()};
    }
  }

  /// Get user's training load and ACWR
  Future<Map<String, dynamic>?> getTrainingLoad(String userId) async {
    try {
      final response = await _supabase
          .rpc('calculate_acwr', params: {'p_user_id': userId});
      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get training load: $e');
      return null;
    }
  }

  /// Get user's weekly training summary
  Future<List<Map<String, dynamic>>> getWeeklyTrainingLoad(
    String userId, {
    int weeks = 4,
  }) async {
    try {
      final response = await _supabase.rpc('get_weekly_training_load', params: {
        'p_user_id': userId,
        'p_weeks': weeks,
      });
      return (response as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('Failed to get weekly training load: $e');
      return [];
    }
  }

  /// Get user stats summary
  Future<Map<String, dynamic>?> getUserStats(
    String userId, {
    int days = 30,
  }) async {
    try {
      final response = await _supabase.rpc('get_user_stats', params: {
        'p_user_id': userId,
        'p_days': days,
      });
      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get user stats: $e');
      return null;
    }
  }

  /// Save form analysis result via RPC
  Future<String?> saveFormAnalysis({
    required String userId,
    String? activityId,
    required double groundContactTimeMs,
    required double verticalOscillationCm,
    required int cadenceSpm,
    required double strideLengthM,
    double? forwardLeanDegrees,
    double? hipDropDegrees,
    double? armSwingSymmetry,
    String footStrike = 'midfoot',
    required int formScore,
    List<String> coachingTips = const [],
    int framesAnalyzed = 0,
    double avgLandmarkConfidence = 0,
  }) async {
    try {
      final response = await _supabase.rpc('save_form_analysis', params: {
        'p_user_id': userId,
        'p_activity_id': activityId,
        'p_ground_contact_time_ms': groundContactTimeMs,
        'p_vertical_oscillation_cm': verticalOscillationCm,
        'p_cadence_spm': cadenceSpm,
        'p_stride_length_m': strideLengthM,
        'p_forward_lean_degrees': forwardLeanDegrees,
        'p_hip_drop_degrees': hipDropDegrees,
        'p_arm_swing_symmetry': armSwingSymmetry,
        'p_foot_strike': footStrike,
        'p_form_score': formScore,
        'p_coaching_tips': coachingTips,
        'p_frames_analyzed': framesAnalyzed,
        'p_avg_landmark_confidence': avgLandmarkConfidence,
      });
      return response as String?;
    } catch (e) {
      debugPrint('Failed to save form analysis: $e');
      return null;
    }
  }

  /// Save HRV reading via RPC
  Future<String?> saveHrvReading({
    required String userId,
    required double rmssd,
    required int restingHeartRate,
    required int hrvScore,
    String recoveryStatus = 'moderate',
    double? sdnn,
    int? sleepQualityScore,
    int? sleepDurationMinutes,
    double? deepSleepRatio,
    String source = 'manual',
    DateTime? measuredAt,
  }) async {
    try {
      final response = await _supabase.rpc('save_hrv_reading', params: {
        'p_user_id': userId,
        'p_rmssd': rmssd,
        'p_resting_heart_rate': restingHeartRate,
        'p_hrv_score': hrvScore,
        'p_recovery_status': recoveryStatus,
        'p_sdnn': sdnn,
        'p_sleep_quality_score': sleepQualityScore,
        'p_sleep_duration_minutes': sleepDurationMinutes,
        'p_deep_sleep_ratio': deepSleepRatio,
        'p_source': source,
        'p_measured_at': (measuredAt ?? DateTime.now()).toUtc().toIso8601String(),
      });
      return response as String?;
    } catch (e) {
      debugPrint('Failed to save HRV reading: $e');
      return null;
    }
  }
}
