import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/config/env.dart';
import 'gait_metrics_calculator.dart';
import 'models/form_analysis_result.dart';
import 'tflite_model_service.dart';

/// FormAnalyzer — On-device running form analysis using camera + MediaPipe
///
/// Pipeline:
/// 1. Camera captures runner video
/// 2. MediaPipe BlazePose extracts 33 landmarks per frame
/// 3. GaitMetricsCalculator processes landmarks into biomechanical metrics
/// 4. Results stored in FormAnalysisResult and optionally uploaded to Supabase
/// 5. TFLiteModelService runs gait scoring + injury risk prediction
///
/// Usage:
/// ```dart
/// final analyzer = FormAnalyzer();
/// analyzer.start();
/// // ... feed camera frames ...
/// final result = await analyzer.stop();
/// ```
class FormAnalyzer {
  final GaitMetricsCalculator _calculator = GaitMetricsCalculator();
  // ignore: unused_field
  TFLiteModelService? _mlService;
  bool _isAnalyzing = false;
  int _frameCount = 0;
  double _totalConfidence = 0;
  DateTime? _sessionStartTime;
  StreamController<FormAnalysisProgress>? _progressController;

  /// Whether the form analyzer is currently running
  bool get isAnalyzing => _isAnalyzing;

  /// Stream of analysis progress updates
  Stream<FormAnalysisProgress>? get progressStream =>
      _progressController?.stream;

  /// Session duration in seconds
  int get sessionDurationSec {
    if (_sessionStartTime == null) return 0;
    return DateTime.now().difference(_sessionStartTime!).inSeconds;
  }

  /// Inject TFLiteModelService for ML predictions after analysis
  set mlService(TFLiteModelService? service) => _mlService = service;

  /// Start a form analysis session
  ///
  /// Call [processCameraFrame] for each video frame during the session.
  void start() {
    if (!Env.enableFormAnalysis) {
      debugPrint('Form analysis is disabled via feature flag');
      return;
    }

    _isAnalyzing = true;
    _frameCount = 0;
    _totalConfidence = 0;
    _sessionStartTime = DateTime.now();
    _calculator.reset();
    _progressController = StreamController<FormAnalysisProgress>.broadcast();

    debugPrint('FormAnalyzer: Session started');
  }

  /// Process a single camera frame containing MediaPipe pose landmarks
  ///
  /// [landmarks] — list of 33 PoseLandmark objects from MediaPipe detection
  /// [timestampMs] — frame timestamp in milliseconds
  /// [confidence] — overall detection confidence (0.0-1.0)
  void processCameraFrame({
    required List<PoseLandmark> landmarks,
    required int timestampMs,
    double confidence = 0.8,
  }) {
    if (!_isAnalyzing) return;

    _calculator.addPoseFrame(
      landmarks: landmarks,
      timestampMs: timestampMs,
      confidence: confidence,
    );

    _frameCount++;
    _totalConfidence += confidence;

    // Emit progress every 15 frames (~0.5 seconds) for smoother UI
    if (_frameCount % 15 == 0 && _calculator.hasEnoughData) {
      _emitProgress();
    }
  }

  void _emitProgress() {
    if (_progressController == null || _progressController!.isClosed) return;

    final vertOsc = _calculator.calculateVerticalOscillationCm();
    final hipDrop = _calculator.calculateHipDropDegrees();
    final armSym = _calculator.calculateArmSwingSymmetry();
    final footStrike = _calculator.detectFootStrike();

    _progressController!.add(FormAnalysisProgress(
      formScore: _calculator.calculateFormScore(),
      cadence: _calculator.calculateCadence(),
      groundContactTimeMs: _calculator.calculateGroundContactTimeMs(),
      verticalOscillationCm: vertOsc,
      forwardLeanDeg: _calculator.calculateForwardLeanDegrees(),
      hipDropDeg: hipDrop,
      armSwingSymmetryPct: armSym * 100,
      footStrikeType: _mapFootStrike(footStrike),
      framesProcessed: _frameCount,
      sessionDurationSec: sessionDurationSec,
    ));
  }

  /// Stop the analysis session and return the final result
  Future<FormAnalysisResult?> stop() async {
    if (!_isAnalyzing) return null;

    _isAnalyzing = false;
    _progressController?.close();
    _progressController = null;

    if (!_calculator.hasEnoughData) {
      debugPrint('FormAnalyzer: Not enough data for analysis '
          '($_frameCount frames)');
      return null;
    }

    final gct = _calculator.calculateGroundContactTimeMs();
    final oscillation = _calculator.calculateVerticalOscillationCm();
    final cadence = _calculator.calculateCadence();
    final lean = _calculator.calculateForwardLeanDegrees();
    final hipDrop = _calculator.calculateHipDropDegrees();
    final armSymmetry = _calculator.calculateArmSwingSymmetry();
    final footStrike = _calculator.detectFootStrike();
    final formScore = _calculator.calculateFormScore();
    final tips = _calculator.generateCoachingTips();

    // Calculate stride length from cadence and estimated speed
    // Use session duration and assumed GPS pace if available
    double strideLengthM = 0;
    if (cadence > 0) {
      // Better estimation: use form score to estimate speed range
      // Elite runners: ~15 km/h, recreational: ~10 km/h
      final estimatedSpeedMPerMin = formScore >= 75
          ? 230.0   // ~13.8 km/h
          : formScore >= 50
              ? 185.0 // ~11.1 km/h
              : 150.0; // ~9.0 km/h
      strideLengthM = estimatedSpeedMPerMin / cadence;
    }

    final result = FormAnalysisResult(
      groundContactTimeMs: gct,
      verticalOscillationCm: oscillation,
      cadenceSpm: cadence,
      strideLengthM: strideLengthM,
      forwardLeanDeg: lean,
      hipDropDeg: hipDrop,
      armSwingSymmetryPct: armSymmetry * 100,
      footStrikeType: _mapFootStrike(footStrike),
      formScore: formScore,
      coachingTips: tips,
      analyzedAt: DateTime.now(),
      framesAnalyzed: _frameCount,
      avgLandmarkConfidence:
          _frameCount > 0 ? _totalConfidence / _frameCount : 0.0,
    );

    _calculator.reset();
    _sessionStartTime = null;

    debugPrint('FormAnalyzer: Session complete — score: $formScore, '
        '$_frameCount frames analyzed, '
        'GCT: ${gct.toStringAsFixed(0)}ms, Cadence: $cadence spm');

    return result;
  }

  String _mapFootStrike(FootStrikeDetection detection) {
    switch (detection) {
      case FootStrikeDetection.heel:
        return 'heel';
      case FootStrikeDetection.midfoot:
        return 'midfoot';
      case FootStrikeDetection.forefoot:
        return 'forefoot';
      case FootStrikeDetection.unknown:
        return 'midfoot';
    }
  }
}

/// Progress update emitted during form analysis
class FormAnalysisProgress {
  final int formScore;
  final int cadence;
  final double groundContactTimeMs;
  final double verticalOscillationCm;
  final double forwardLeanDeg;
  final double hipDropDeg;
  final double armSwingSymmetryPct;
  final String footStrikeType;
  final int framesProcessed;
  final int sessionDurationSec;

  const FormAnalysisProgress({
    required this.formScore,
    required this.cadence,
    required this.groundContactTimeMs,
    this.verticalOscillationCm = 0,
    this.forwardLeanDeg = 0,
    this.hipDropDeg = 0,
    this.armSwingSymmetryPct = 0,
    this.footStrikeType = 'midfoot',
    required this.framesProcessed,
    this.sessionDurationSec = 0,
  });
}
