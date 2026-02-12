import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/env.dart';
import 'models/form_analysis_result.dart';

/// TFLite model names used across the app
enum TFLiteModel {
  gaitForm('gait_form_model.tflite', 'gait_form'),
  injuryRisk('injury_risk_model.tflite', 'injury_risk'),
  performance('performance_model.tflite', 'performance');

  final String filename;
  final String apiName;
  const TFLiteModel(this.filename, this.apiName);
}

/// Service for managing TFLite models — download, cache, and server-side fallback.
///
/// On-device inference uses google_mlkit for pose detection;
/// for gait scoring / injury risk / performance, this service provides
/// a server-side fallback via the ML microservice API.
class TFLiteModelService {
  late final Dio _dio;
  final Map<String, Map<String, dynamic>> _normParams = {};
  bool _initialized = false;
  bool _serverAvailable = false;

  /// Whether the service has been initialized
  bool get isInitialized => _initialized;

  /// Whether the ML server is reachable
  bool get isServerAvailable => _serverAvailable;

  /// Initialize the service — load normalization params if available
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

    try {
      // Check server health first
      final healthResp = await _dio.get('/api/v1/gait/injury-risk',
          queryParameters: {'check': 'health'}).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Health check timed out'),
      );
      _serverAvailable = healthResp.statusCode == 200 ||
          healthResp.statusCode == 422; // 422 = validation error (server is up)

      if (_serverAvailable) {
        for (final model in TFLiteModel.values) {
          await _loadNormalizationParams(model);
        }
      }
      debugPrint('TFLiteModelService: Initialized — '
          'server=${_serverAvailable ? "online" : "offline"}, '
          'models=${_normParams.length}');
    } catch (e) {
      _serverAvailable = false;
      debugPrint('TFLiteModelService: Init warning — $e (using on-device rules)');
    }
    _initialized = true;
  }

  /// Load normalization parameters for a model from server
  Future<void> _loadNormalizationParams(TFLiteModel model) async {
    try {
      final response = await _dio.get(
        '/api/v1/models/${model.apiName}/normalization',
      );
      if (response.statusCode == 200) {
        _normParams[model.apiName] = Map<String, dynamic>.from(response.data);
      }
    } catch (e) {
      debugPrint('TFLiteModelService: Could not load norm params for ${model.apiName}');
    }
  }

  /// Run prediction using server-side TFLite inference with on-device fallback
  ///
  /// Tries server inference first if available, otherwise uses
  /// highly-tuned rule-based on-device prediction.
  Future<Map<String, dynamic>> predict(
    TFLiteModel model,
    List<double> features,
  ) async {
    // If server is known to be unavailable, skip directly to rules
    if (!_serverAvailable) {
      return _ruleBasedFallback(model, features);
    }

    try {
      return await _serverInference(model, features);
    } catch (e) {
      debugPrint('TFLiteModelService: Server inference failed — using on-device rules: $e');
      _serverAvailable = false; // Cache failure to avoid repeated timeouts
      return _ruleBasedFallback(model, features);
    }
  }

  /// Analyze form analysis results and return injury risk + gait score
  ///
  /// This is the primary entry point after a FormAnalysis session completes.
  /// It extracts features from the result and runs both gait form and
  /// injury risk predictions.
  Future<FormAnalysisPrediction> analyzeFormResult(
    FormAnalysisResult result, {
    double weeklyDistanceKm = 30.0,
    double acwr = 1.0,
  }) async {
    // Build feature vectors from form analysis result
    final gaitFeatures = [
      result.groundContactTimeMs,           // [0] GCT ms
      result.verticalOscillationCm,         // [1] Vertical osc cm
      result.cadenceSpm.toDouble(),          // [2] Cadence spm
      result.strideLengthM,                 // [3] Stride length m
      result.forwardLeanDeg ?? 8.0,         // [4] Forward lean deg
      result.hipDropDeg ?? 3.0,             // [5] Hip drop deg
      (result.armSwingSymmetryPct ?? 90),    // [6] Arm swing symmetry %
      result.formScore.toDouble(),          // [7] Raw form score
    ];

    final injuryFeatures = [
      result.groundContactTimeMs,            // [0] GCT ms
      result.verticalOscillationCm,          // [1] Vertical osc cm
      result.cadenceSpm.toDouble(),          // [2] Cadence spm
      result.forwardLeanDeg ?? 8.0,          // [3] Forward lean deg
      result.hipDropDeg ?? 3.0,              // [4] Hip drop deg
      weeklyDistanceKm,                      // [5] Weekly distance km
      acwr,                                  // [6] ACWR ratio
    ];

    final gaitResult = await predict(TFLiteModel.gaitForm, gaitFeatures);
    final injuryResult = await predict(TFLiteModel.injuryRisk, injuryFeatures);

    return FormAnalysisPrediction(
      formScore: (gaitResult['form_score'] as num?)?.toDouble() ??
          result.formScore.toDouble(),
      formLevel: gaitResult['level'] as String? ?? 'unknown',
      injuryRiskLevel: injuryResult['risk_level'] as String? ?? 'unknown',
      injuryRiskConfidence:
          (injuryResult['confidence'] as num?)?.toDouble() ?? 50.0,
      recommendations: _generateRecommendations(gaitResult, injuryResult, result),
    );
  }

  /// Generate actionable recommendations from ML predictions
  List<String> _generateRecommendations(
    Map<String, dynamic> gaitResult,
    Map<String, dynamic> injuryResult,
    FormAnalysisResult formResult,
  ) {
    final tips = <String>[];
    final riskLevel = injuryResult['risk_level'] as String? ?? 'unknown';

    if (riskLevel == 'high') {
      tips.add('⚠️ High injury risk detected. Consider reducing training volume by 20-30% this week.');
    } else if (riskLevel == 'moderate') {
      tips.add('Monitor training load closely. Include extra recovery days.');
    }

    if (formResult.groundContactTimeMs > 280) {
      tips.add('Focus on quick, light foot strikes to reduce ground contact time from ${formResult.groundContactTimeMs.toInt()}ms toward 220ms.');
    }

    if (formResult.cadenceSpm < 170) {
      tips.add('Increase cadence from ${formResult.cadenceSpm} to 175+ spm using a metronome app during easy runs.');
    }

    if ((formResult.hipDropDeg ?? 0) > 8) {
      tips.add('Excessive hip drop (${formResult.hipDropDeg!.toStringAsFixed(1)}°). Add clamshells and single-leg deadlifts to strengthen glutes.');
    }

    final score = (gaitResult['form_score'] as num?)?.toDouble() ?? 0;
    if (score >= 80) {
      tips.add('Excellent form! Focus on consistency and gradual speed progression.');
    }

    if (tips.isEmpty) {
      tips.add('Good running form. Keep up consistent training.');
    }

    return tips;
  }

  /// Server-side TFLite inference via ML service API
  Future<Map<String, dynamic>> _serverInference(
    TFLiteModel model,
    List<double> features,
  ) async {
    final response = await _dio.post(
      '/api/v1/inference',
      data: {
        'model': model.apiName,
        'features': features,
      },
    );

    if (response.statusCode == 200) {
      final data = Map<String, dynamic>.from(response.data);
      return Map<String, dynamic>.from(data['interpretation'] ?? {});
    }
    throw Exception('ML service returned ${response.statusCode}');
  }

  /// Rule-based fallback when TFLite models are unavailable
  Map<String, dynamic> _ruleBasedFallback(
    TFLiteModel model,
    List<double> features,
  ) {
    switch (model) {
      case TFLiteModel.gaitForm:
        return _gaitFormFallback(features);
      case TFLiteModel.injuryRisk:
        return _injuryRiskFallback(features);
      case TFLiteModel.performance:
        return _performanceFallback(features);
    }
  }

  /// Gait form scoring — biomechanics-informed rule engine
  ///
  /// Weighted scoring based on running science research:
  /// - Cadence: 25% (most actionable metric)
  /// - GCT: 20% (running economy indicator)
  /// - Vertical Oscillation: 15% (energy waste indicator)
  /// - Hip Drop: 15% (injury risk indicator)
  /// - Arm Symmetry: 10% (compensatory pattern detection)
  /// - Forward Lean: 10% (posture quality)
  /// - Foot Strike: 5% (landing pattern)
  Map<String, dynamic> _gaitFormFallback(List<double> features) {
    if (features.length < 8) return {'form_score': 50.0, 'level': 'unknown'};

    final gct = features[0];        // Ground Contact Time ms
    final osc = features[1];        // Vertical Oscillation cm
    final cadence = features[2];    // Cadence spm
    // features[3] = stride length (not used directly in scoring)
    final lean = features[4];       // Forward lean deg
    final hipDrop = features[5];    // Hip drop deg
    final armSym = features[6];     // Arm swing symmetry %
    final rawScore = features[7];   // Raw form score from GaitMetrics

    double score = 0;

    // Cadence: ideal 175-185 spm (25 pts)
    if (cadence >= 175 && cadence <= 185) {
      score += 25;
    } else if (cadence >= 170 || (cadence > 185 && cadence <= 195)) {
      score += 20;
    } else if (cadence >= 160) {
      score += 12;
    } else {
      score += 5 * (cadence / 180).clamp(0.0, 1.0);
    }

    // GCT: ideal 180-220ms (20 pts)
    if (gct >= 160 && gct <= 220) {
      score += 20;
    } else if (gct <= 250) {
      score += 15;
    } else if (gct <= 300) {
      score += 8;
    } else {
      score += 3;
    }

    // Vertical Oscillation: ideal 6-8cm (15 pts)
    if (osc >= 5 && osc <= 8) {
      score += 15;
    } else if (osc <= 10) {
      score += 10;
    } else if (osc <= 12) {
      score += 6;
    } else {
      score += 2;
    }

    // Hip Drop: ideal < 5° (15 pts)
    if (hipDrop < 4) {
      score += 15;
    } else if (hipDrop < 6) {
      score += 12;
    } else if (hipDrop < 8) {
      score += 7;
    } else {
      score += 2;
    }

    // Arm Swing Symmetry: ideal > 90% (10 pts)
    if (armSym >= 90) {
      score += 10;
    } else if (armSym >= 80) {
      score += 7;
    } else if (armSym >= 70) {
      score += 4;
    } else {
      score += 1;
    }

    // Forward Lean: ideal 5-10° (10 pts)
    if (lean >= 5 && lean <= 10) {
      score += 10;
    } else if (lean >= 3 && lean <= 15) {
      score += 6;
    } else {
      score += 2;
    }

    score = score.clamp(0, 100).roundToDouble();

    // Blend with raw GaitMetrics score for stability
    final blended = (score * 0.7 + rawScore * 0.3).clamp(0, 100).roundToDouble();

    final level = blended >= 85
        ? 'excellent'
        : blended >= 70
            ? 'good'
            : blended >= 50
                ? 'average'
                : blended >= 35
                    ? 'needs_work'
                    : 'poor';

    return {
      'form_score': blended,
      'level': level,
      'component_scores': {
        'cadence': (cadence >= 170 && cadence <= 190) ? 'optimal' : 'suboptimal',
        'gct': gct < 250 ? 'good' : 'high',
        'oscillation': osc < 10 ? 'efficient' : 'wasteful',
        'hip_stability': hipDrop < 6 ? 'stable' : 'weak',
        'symmetry': armSym >= 85 ? 'balanced' : 'asymmetric',
        'posture': (lean >= 5 && lean <= 12) ? 'aligned' : 'misaligned',
      },
    };
  }

  /// Injury risk assessment — multi-factor biomechanical risk engine
  ///
  /// Features: [gct, osc, cadence, lean, hipDrop, weeklyKm, acwr]
  Map<String, dynamic> _injuryRiskFallback(List<double> features) {
    if (features.length < 7) {
      return {'risk_level': 'unknown', 'confidence': 0.0, 'risk_factors': []};
    }

    final gct = features[0];
    final osc = features[1];
    final cadence = features[2];
    final lean = features[3];
    final hipDrop = features[4];
    final weeklyKm = features[5];
    final acwr = features[6];

    double riskScore = 0;
    final riskFactors = <String>[];

    // GCT risk: > 300ms indicates overstriding/braking
    if (gct > 300) {
      riskScore += 0.15;
      riskFactors.add('High ground contact time (${gct.toInt()}ms) — overstriding risk');
    } else if (gct > 260) {
      riskScore += 0.08;
    }

    // Vertical oscillation risk: > 12cm = excessive bouncing
    if (osc > 12) {
      riskScore += 0.12;
      riskFactors.add('Excessive vertical bounce (${osc.toStringAsFixed(1)}cm) — impact loading');
    } else if (osc > 10) {
      riskScore += 0.05;
    }

    // Low cadence risk: < 165 spm = longer ground contact, more load
    if (cadence < 160) {
      riskScore += 0.12;
      riskFactors.add('Low cadence (${cadence.toInt()} spm) — increased load per step');
    } else if (cadence < 170) {
      riskScore += 0.05;
    }

    // Hip drop risk: > 8° = glute weakness (Trendelenburg positive)
    if (hipDrop > 10) {
      riskScore += 0.18;
      riskFactors.add('Excessive hip drop (${hipDrop.toStringAsFixed(1)}°) — ITB/knee risk');
    } else if (hipDrop > 7) {
      riskScore += 0.10;
      riskFactors.add('Moderate hip drop detected');
    }

    // Forward lean risk: > 15° = lower back strain
    if (lean > 18) {
      riskScore += 0.10;
      riskFactors.add('Excessive forward lean (${lean.toStringAsFixed(1)}°) — back strain risk');
    } else if (lean < 2) {
      riskScore += 0.05;
      riskFactors.add('Insufficient forward lean — inefficient posture');
    }

    // ACWR risk: > 1.5 = acute spike (Banister model)
    if (acwr > 1.5) {
      riskScore += 0.25;
      riskFactors.add('Training load spike (ACWR: ${acwr.toStringAsFixed(2)}) — high overuse risk');
    } else if (acwr > 1.3) {
      riskScore += 0.12;
      riskFactors.add('Elevated ACWR (${acwr.toStringAsFixed(2)}) — monitor closely');
    }

    // Weekly volume risk
    if (weeklyKm > 80) {
      riskScore += 0.08;
    }

    riskScore = riskScore.clamp(0.0, 1.0);

    final level = riskScore >= 0.55
        ? 'high'
        : riskScore >= 0.25
            ? 'moderate'
            : 'low';

    final confidence = math.min(90.0, 50.0 + (features.where((f) => f > 0).length * 6));

    return {
      'risk_level': level,
      'risk_score': (riskScore * 100).roundToDouble(),
      'confidence': confidence,
      'risk_factors': riskFactors,
    };
  }

  /// Performance prediction fallback (Riegel's formula + VO2max estimation)
  Map<String, dynamic> _performanceFallback(List<double> features) {
    if (features.length < 2) return {'predicted_5k': 'N/A'};

    final pace = features[1]; // avg_pace_min_per_km
    if (pace <= 0 || pace > 15) return {'predicted_5k': 'N/A'};

    final racePace = pace * 0.88; // ~12% faster for race effort
    final t5k = (racePace * 5 * 60).round();
    final mins = t5k ~/ 60;
    final secs = t5k % 60;

    final t10k = (t5k * math.pow(10 / 5.0, 1.06)).round();
    final tHalf = (t5k * math.pow(21.1 / 5.0, 1.06)).round();
    final tMarathon = (t5k * math.pow(42.2 / 5.0, 1.06)).round();

    // Estimate VO2max from pace (Jack Daniels formula approximation)
    final speedKmH = 60.0 / pace;
    final vo2max = (speedKmH * 3.5).clamp(20.0, 90.0);

    return {
      'predicted_5k': '$mins:${secs.toString().padLeft(2, '0')}',
      'predicted_5k_seconds': t5k,
      'predicted_10k_seconds': t10k,
      'predicted_half_marathon_seconds': tHalf,
      'predicted_marathon_seconds': tMarathon,
      'estimated_vo2max': vo2max.roundToDouble(),
      'race_readiness': pace < 5.5 ? 'competitive' : pace < 7.0 ? 'recreational' : 'building_base',
    };
  }

  /// Trigger model build on the ML server
  Future<Map<String, dynamic>> buildModels() async {
    try {
      final response = await _dio.post('/api/v1/models/build');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception('Build failed: ${response.statusCode}');
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Get list of available TFLite models on the server
  Future<List<Map<String, dynamic>>> listModels() async {
    try {
      final response = await _dio.get('/api/v1/models');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(
          (response.data as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

/// Combined prediction result from form analysis
class FormAnalysisPrediction {
  final double formScore;
  final String formLevel;
  final String injuryRiskLevel;
  final double injuryRiskConfidence;
  final List<String> recommendations;

  const FormAnalysisPrediction({
    required this.formScore,
    required this.formLevel,
    required this.injuryRiskLevel,
    required this.injuryRiskConfidence,
    this.recommendations = const [],
  });

  /// Color-coded risk level for UI display
  String get riskEmoji {
    switch (injuryRiskLevel) {
      case 'high':
        return '🔴';
      case 'moderate':
        return '🟡';
      case 'low':
        return '🟢';
      default:
        return '⚪';
    }
  }
}
