import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/env.dart';

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

  /// Whether the service has been initialized
  bool get isInitialized => _initialized;

  /// Initialize the service — load normalization params if available
  Future<void> initialize() async {
    if (_initialized) return;

    _dio = Dio(
      BaseOptions(
        baseUrl: Env.mlServiceUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    try {
      for (final model in TFLiteModel.values) {
        await _loadNormalizationParams(model);
      }
      debugPrint('TFLiteModelService: Initialized with ${_normParams.length} models');
    } catch (e) {
      debugPrint('TFLiteModelService: Init warning — $e');
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

  /// Run prediction using server-side TFLite inference (fallback)
  ///
  /// Returns interpreted results as a Map.
  /// Falls back to rule-based prediction if server is unavailable.
  Future<Map<String, dynamic>> predict(
    TFLiteModel model,
    List<double> features,
  ) async {
    try {
      return await _serverInference(model, features);
    } catch (e) {
      debugPrint('TFLiteModelService: Server inference failed — using rules: $e');
      return _ruleBasedFallback(model, features);
    }
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

  /// Gait form scoring fallback (mirrors tflite_builder.py heuristic)
  Map<String, dynamic> _gaitFormFallback(List<double> features) {
    if (features.length < 8) return {'form_score': 50.0, 'level': 'unknown'};

    final gct = features[0];
    final cadence = features[2];
    final hipDrop = features[5];
    final armSym = features[6];

    double score = 0;
    score += 30 * ((cadence - 140) / 60).clamp(0.0, 1.0);
    score += 20 * ((300 - gct) / 120).clamp(0.0, 1.0);
    score += 15 * ((12 - features[1]) / 7).clamp(0.0, 1.0); // osc
    score += 10 * ((10 - hipDrop) / 8).clamp(0.0, 1.0);
    score += 10 * ((armSym - 70) / 30).clamp(0.0, 1.0);
    score = score.clamp(0, 100);

    final level = score >= 80
        ? 'excellent'
        : score >= 60
            ? 'good'
            : score >= 40
                ? 'needs_work'
                : 'poor';

    return {'form_score': score.roundToDouble(), 'level': level};
  }

  /// Injury risk fallback
  Map<String, dynamic> _injuryRiskFallback(List<double> features) {
    if (features.length < 7) return {'risk_level': 'unknown'};

    final gct = features[0];
    final cadence = features[2];
    final hipDrop = features[4];
    final acwr = features[6];

    double risk = 0;
    risk += 0.15 * ((gct - 250) / 100).clamp(0.0, 1.0);
    risk += 0.15 * ((features[1] - 10) / 5).clamp(0.0, 1.0); // osc
    risk += 0.15 * ((170 - cadence) / 30).clamp(0.0, 1.0);
    risk += 0.15 * ((hipDrop - 6) / 6).clamp(0.0, 1.0);
    risk += 0.2 * ((acwr - 1.3) / 0.7).clamp(0.0, 1.0);

    final level = risk >= 0.6 ? 'high' : risk >= 0.3 ? 'moderate' : 'low';

    return {
      'risk_level': level,
      'confidence': ((1 - (risk - risk.roundToDouble()).abs()) * 100).roundToDouble(),
    };
  }

  /// Performance prediction fallback (Riegel's formula)
  Map<String, dynamic> _performanceFallback(List<double> features) {
    if (features.length < 2) return {'predicted_5k': 'N/A'};

    final pace = features[1]; // avg_pace_min_per_km
    final racePace = pace * 0.88;
    final t5k = (racePace * 5 * 60).round();
    final mins = t5k ~/ 60;
    final secs = t5k % 60;

    final t10k = (t5k * math.pow(10 / 5.0, 1.06)).round();
    final tHalf = (t5k * math.pow(21.1 / 5.0, 1.06)).round();
    final tMarathon = (t5k * math.pow(42.2 / 5.0, 1.06)).round();

    return {
      'predicted_5k': '$mins:${secs.toString().padLeft(2, '0')}',
      'predicted_5k_seconds': t5k,
      'predicted_10k_seconds': t10k,
      'predicted_half_marathon_seconds': tHalf,
      'predicted_marathon_seconds': tMarathon,
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
