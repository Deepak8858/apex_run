import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'form_analyzer.dart';
import 'hrv_service.dart';
import 'gait_metrics_calculator.dart';
import 'models/form_analysis_result.dart';
import 'models/hrv_data.dart';

// ============================================================
// ML Service Providers
// ============================================================

/// Provides the FormAnalyzer for running form analysis sessions
final formAnalyzerProvider = Provider<FormAnalyzer>((ref) {
  return FormAnalyzer();
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
  return FormAnalysisNotifier(analyzer);
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

  FormAnalysisNotifier(this._analyzer) : super(const FormAnalysisState());

  void startSession() {
    _analyzer.start();
    state = state.copyWith(isAnalyzing: true, errorMessage: null);

    // Listen to progress updates
    _analyzer.progressStream?.listen((progress) {
      if (mounted) {
        state = state.copyWith(liveProgress: progress);
      }
    });
  }

  Future<void> stopSession() async {
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
