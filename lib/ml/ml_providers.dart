import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'form_analyzer.dart';
import 'hrv_service.dart';
import 'gait_metrics_calculator.dart';
import 'tflite_model_service.dart';
import 'pose_camera_service.dart';
import 'models/form_analysis_result.dart';
import 'models/hrv_data.dart';

// ============================================================
// ML Service Providers
// ============================================================

/// Provides the FormAnalyzer for running form analysis sessions
final formAnalyzerProvider = Provider<FormAnalyzer>((ref) {
  return FormAnalyzer();
});

/// Provides the PoseCameraService for camera → pose detection pipeline
final poseCameraServiceProvider = Provider<PoseCameraService>((ref) {
  final service = PoseCameraService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provides the HRV service for health data integration
final hrvServiceProvider = Provider<HrvService>((ref) {
  final service = HrvService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provides the GaitMetricsCalculator for real-time gait analysis
final gaitCalculatorProvider = Provider<GaitMetricsCalculator>((ref) {
  return GaitMetricsCalculator();
});

// ============================================================
// Form Analysis State
// ============================================================

/// Current form analysis session state
final formAnalysisStateProvider =
    StateNotifierProvider<FormAnalysisNotifier, FormAnalysisState>((ref) {
  final analyzer = ref.watch(formAnalyzerProvider);
  final cameraService = ref.watch(poseCameraServiceProvider);
  return FormAnalysisNotifier(analyzer, cameraService);
});

class FormAnalysisState {
  final bool isAnalyzing;
  final FormAnalysisResult? lastResult;
  final FormAnalysisProgress? liveProgress;
  final String? errorMessage;

  const FormAnalysisState({
    this.isAnalyzing = false,
    this.lastResult,
    this.liveProgress,
    this.errorMessage,
  });

  FormAnalysisState copyWith({
    bool? isAnalyzing,
    FormAnalysisResult? lastResult,
    FormAnalysisProgress? liveProgress,
    String? errorMessage,
  }) {
    return FormAnalysisState(
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      lastResult: lastResult ?? this.lastResult,
      liveProgress: liveProgress ?? this.liveProgress,
      errorMessage: errorMessage,
    );
  }
}

class FormAnalysisNotifier extends StateNotifier<FormAnalysisState> {
  final FormAnalyzer _analyzer;
  final PoseCameraService _cameraService;
  StreamSubscription<PoseFrame>? _poseSubscription;
  StreamSubscription<FormAnalysisProgress>? _progressSubscription;

  FormAnalysisNotifier(this._analyzer, this._cameraService)
      : super(const FormAnalysisState());

  /// Start a form analysis session — opens camera, starts pose detection,
  /// and pipes frames into the FormAnalyzer.
  Future<void> startSession() async {
    try {
      // Start the form analyzer
      _analyzer.start();
      state = state.copyWith(isAnalyzing: true, errorMessage: null);

      // Listen to progress updates from the analyzer
      _progressSubscription = _analyzer.progressStream?.listen((progress) {
        if (mounted) {
          state = state.copyWith(liveProgress: progress);
        }
      });

      // Start camera + pose detection pipeline
      await _cameraService.start();

      // Subscribe to detected poses and forward to analyzer
      _poseSubscription = _cameraService.poseStream.listen((frame) {
        if (mounted && state.isAnalyzing) {
          _analyzer.processCameraFrame(
            landmarks: frame.landmarks,
            timestampMs: frame.timestampMs,
            confidence: frame.confidence,
          );
        }
      });
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        errorMessage: 'Failed to start analysis: $e',
      );
    }
  }

  Future<void> stopSession() async {
    // Stop subscriptions first
    await _poseSubscription?.cancel();
    _poseSubscription = null;
    await _progressSubscription?.cancel();
    _progressSubscription = null;

    // Stop camera
    await _cameraService.stop();

    // Stop analyzer and collect results
    final result = await _analyzer.stop();
    state = state.copyWith(
      isAnalyzing: false,
      lastResult: result,
      liveProgress: null,
    );
  }

  /// Feed a pose frame from camera/MediaPipe detection
  void processPoseFrame({
    required List<PoseLandmark> landmarks,
    required int timestampMs,
    double confidence = 0.8,
  }) {
    _analyzer.processCameraFrame(
      landmarks: landmarks,
      timestampMs: timestampMs,
      confidence: confidence,
    );
  }

  @override
  void dispose() {
    _poseSubscription?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }
}

// ============================================================
// HRV State
// ============================================================

/// Today's HRV and recovery state
final todaysHrvProvider = FutureProvider.autoDispose<HrvData?>((ref) async {
  final service = ref.watch(hrvServiceProvider);
  return service.fetchTodaysHrv();
});

/// Morning readiness score
final readinessScoreProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.watch(hrvServiceProvider);
  return service.calculateReadinessScore();
});

/// HRV trend (positive = improving, negative = declining)
final hrvTrendProvider = Provider<double?>((ref) {
  final service = ref.watch(hrvServiceProvider);
  return service.getHrvTrend();
});

// ============================================================
// TFLite Model Service
// ============================================================

/// Provides the TFLite model service for on-device/server ML inference
final tfliteServiceProvider = Provider<TFLiteModelService>((ref) {
  final service = TFLiteModelService();
  service.initialize();
  return service;
});

/// Gait form prediction — returns form score + level
final gaitFormPredictionProvider =
    FutureProvider.family<Map<String, dynamic>, List<double>>((ref, features) async {
  final service = ref.watch(tfliteServiceProvider);
  return service.predict(TFLiteModel.gaitForm, features);
});

/// Injury risk prediction — returns risk level + confidence
final injuryRiskPredictionProvider =
    FutureProvider.family<Map<String, dynamic>, List<double>>((ref, features) async {
  final service = ref.watch(tfliteServiceProvider);
  return service.predict(TFLiteModel.injuryRisk, features);
});

/// Performance prediction — returns predicted race times
final performancePredictionProvider =
    FutureProvider.family<Map<String, dynamic>, List<double>>((ref, features) async {
  final service = ref.watch(tfliteServiceProvider);
  return service.predict(TFLiteModel.performance, features);
});
