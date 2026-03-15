import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/env.dart';

/// Models for the Agentic Recovery Sync
class RecoveryRequest {
  final String userId;
  final double hrvRmssd;
  final int sleepScore;
  final int restingHeartRate;
  final String hydrationStatus;
  final double yesterdayTrainingLoad;

  RecoveryRequest({
    required this.userId,
    required this.hrvRmssd,
    required this.sleepScore,
    required this.restingHeartRate,
    this.hydrationStatus = 'optimal',
    required this.yesterdayTrainingLoad,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'hrv_rmssd': hrvRmssd,
    'sleep_score': sleepScore,
    'resting_heart_rate': restingHeartRate,
    'hydration_status': hydrationStatus,
    'yesterday_training_load': yesterdayTrainingLoad,
  };
}

class RecoveryResponse {
  final String userId;
  final double recoveryScore;
  final String recoveryStatus;
  final double workoutModifier;
  final String recommendation;

  RecoveryResponse({
    required this.userId,
    required this.recoveryScore,
    required this.recoveryStatus,
    required this.workoutModifier,
    required this.recommendation,
  });

  factory RecoveryResponse.fromJson(Map<String, dynamic> json) => RecoveryResponse(
    userId: json['user_id'],
    recoveryScore: (json['recovery_score'] as num).toDouble(),
    recoveryStatus: json['recovery_status'],
    workoutModifier: (json['workout_modifier'] as num).toDouble(),
    recommendation: json['recommendation'],
  );
}

/// Models for Ghost Social Racing
class ActivityPoint {
  final int timeS;
  final double distM;
  final double? lat;
  final double? lng;

  ActivityPoint({
    required this.timeS,
    required this.distM,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson() => {
    'time_s': timeS,
    'dist_m': distM,
    'lat': lat,
    'lng': lng,
  };
}

class GhostMatchRequest {
  final int userElapsedS;
  final double userDistM;
  final List<ActivityPoint> ghostStream;

  GhostMatchRequest({
    required this.userElapsedS,
    required this.userDistM,
    required this.ghostStream,
  });

  Map<String, dynamic> toJson() => {
    'user_elapsed_s': userElapsedS,
    'user_dist_m': userDistM,
    'ghost_stream': ghostStream.map((p) => p.toJson()).toList(),
  };
}

class GhostStatusResponse {
  final double ghostDistM;
  final double gapM;
  final String status;

  GhostStatusResponse({
    required this.ghostDistM,
    required this.gapM,
    required this.status,
  });

  factory GhostStatusResponse.fromJson(Map<String, dynamic> json) => GhostStatusResponse(
    ghostDistM: (json['ghost_dist_m'] as num).toDouble(),
    gapM: (json['gap_m'] as num).toDouble(),
    status: json['status'],
  );
}

/// Models for Dynamic Risk-Aware Routing
class RouteSegment {
  final String id;
  final String name;
  final double distanceM;
  final double elevationGainM;
  final String surfaceType;

  RouteSegment({
    required this.id,
    required this.name,
    required this.distanceM,
    required this.elevationGainM,
    required this.surfaceType,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'distance_m': distanceM,
    'elevation_gain_m': elevationGainM,
    'surface_type': surfaceType,
  };
}

class RiskAwareRouteRequest {
  final String userId;
  final double gaitFatigueScore;
  final double targetDistanceM;
  final List<RouteSegment> candidateSegments;

  RiskAwareRouteRequest({
    required this.userId,
    required this.gaitFatigueScore,
    required this.targetDistanceM,
    required this.candidateSegments,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'gait_fatigue_score': gaitFatigueScore,
    'target_distance_m': targetDistanceM,
    'candidate_segments': candidateSegments.map((s) => s.toJson()).toList(),
  };
}

class RiskAwareRouteResponse {
  final String selectedRouteId;
  final String riskLevel;
  final String reasoning;
  final bool safetyModifierApplied;

  RiskAwareRouteResponse({
    required this.selectedRouteId,
    required this.riskLevel,
    required this.reasoning,
    required this.safetyModifierApplied,
  });

  factory RiskAwareRouteResponse.fromJson(Map<String, dynamic> json) => RiskAwareRouteResponse(
    selectedRouteId: json['selected_route_id'],
    riskLevel: json['risk_level'],
    reasoning: json['reasoning'],
    safetyModifierApplied: json['safety_modifier_applied'],
  );
}

/// Models for Autonomous Training Lifecycle
class ActivitySummaryRequest {
  final String userId;
  final double distanceKm;
  final double durationMins;
  final int avgHr;
  final int calories;
  final double intensityScore;

  ActivitySummaryRequest({
    required this.userId,
    required this.distanceKm,
    required this.durationMins,
    required this.avgHr,
    required this.calories,
    required this.intensityScore,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'distance_km': distanceKm,
    'duration_mins': durationMins,
    'avg_hr': avgHr,
    'calories': calories,
    'intensity_score': intensityScore,
  };
}

class ActivitySummaryResponse {
  final String summary;
  final String impactOnGoal;
  final int suggestedRestHours;
  final double? stiffnessIndex;
  final double? kneeFlexion;

  ActivitySummaryResponse({
    required this.summary,
    required this.impactOnGoal,
    required this.suggestedRestHours,
    this.stiffnessIndex,
    this.kneeFlexion,
  });

  factory ActivitySummaryResponse.fromJson(Map<String, dynamic> json) => ActivitySummaryResponse(
    summary: json['summary'],
    impactOnGoal: json['impact_on_goal'],
    suggestedRestHours: json['suggested_rest_hours'],
    stiffnessIndex: (json['stiffness_index'] as num?)?.toDouble(),
    kneeFlexion: (json['knee_flexion'] as num?)?.toDouble(),
  );
}

/// Models for Gait Biomechanics Analysis
class GaitInferenceRequest {
  final double groundContactTimeMs;
  final double verticalOscillationCm;
  final int cadenceSpm;
  final double forwardLeanDegrees;
  final double hipDropDegrees;
  final double stiffnessIndex;
  final double peakKneeFlexion;

  GaitInferenceRequest({
    required this.groundContactTimeMs,
    required this.verticalOscillationCm,
    required this.cadenceSpm,
    required this.forwardLeanDegrees,
    required this.hipDropDegrees,
    required this.stiffnessIndex,
    required this.peakKneeFlexion,
  });

  Map<String, dynamic> toJson() => {
    'ground_contact_time_ms': groundContactTimeMs,
    'vertical_oscillation_cm': verticalOscillationCm,
    'cadence_spm': cadenceSpm,
    'forward_lean_degrees': forwardLeanDegrees,
    'hip_drop_degrees': hipDropDegrees,
    'stiffness_index': stiffnessIndex,
    'peak_knee_flexion': peakKneeFlexion,
  };
}

/// Service for the new Agentic Core features of ApexRun
class AgentService {
  late final Dio _dio;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    _dio = Dio(
      BaseOptions(
        baseUrl: Env.mlServiceUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    _initialized = true;
  }

  /// Feature 1: Agentic Recovery Sync
  Future<RecoveryResponse?> analyzeRecovery(RecoveryRequest request) async {
    try {
      final response = await _dio.post(
        '/api/v1/recovery/analyze',
        data: request.toJson(),
      );
      if (response.statusCode == 200) {
        return RecoveryResponse.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('AgentService: Recovery analysis failed — $e');
    }
    return null;
  }

  /// Feature 2: Ghost Social Racing
  Future<GhostStatusResponse?> syncGhost(GhostMatchRequest request) async {
    try {
      final response = await _dio.post(
        '/api/v1/ghost/sync',
        data: request.toJson(),
      );
      if (response.statusCode == 200) {
        return GhostStatusResponse.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('AgentService: Ghost sync failed — $e');
    }
    return null;
  }

  /// Feature 3: Dynamic Risk-Aware Routing
  Future<RiskAwareRouteResponse?> analyzeRouteRisk(RiskAwareRouteRequest request) async {
    try {
      final response = await _dio.post(
        '/api/v1/routing/analyze',
        data: request.toJson(),
      );
      if (response.statusCode == 200) {
        return RiskAwareRouteResponse.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('AgentService: Route risk analysis failed — $e');
    }
    return null;
  }

  /// Feature 4: Autonomous Training Lifecycle
  Future<ActivitySummaryResponse?> summarizeActivity(ActivitySummaryRequest request) async {
    try {
      final response = await _dio.post(
        '/api/v1/lifecycle/summarize',
        data: request.toJson(),
      );
      if (response.statusCode == 200) {
        return ActivitySummaryResponse.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('AgentService: Activity summary failed — $e');
    }
    return null;
  }

  /// Feature 5: Advanced Gait Biomechanics Analysis
  Future<Map<String, dynamic>?> analyzeGait(GaitInferenceRequest request) async {
    try {
      final response = await _dio.post(
        '/api/v1/gait/analyze-advanced',
        data: request.toJson(),
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      debugPrint('AgentService: Gait analysis failed — $e');
    }
    return null;
  }
}
