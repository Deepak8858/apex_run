import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../ml/ml_providers.dart';
import '../../ml/models/form_analysis_result.dart';
import '../../ml/form_analyzer.dart';
import '../../ml/tflite_model_service.dart';

/// Form Analysis Screen — ML-powered running form feedback
///
/// Displays:
/// - Live form score during analysis with all real-time metrics
/// - Detailed biomechanical metrics post-analysis
/// - ML-powered injury risk assessment
/// - Coaching tips for improvement
/// - Session controls with timer
class FormAnalysisScreen extends ConsumerWidget {
  const FormAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisState = ref.watch(formAnalysisStateProvider);
    final readiness = ref.watch(readinessScoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Running Form'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Readiness Card
              readiness.when(
                data: (score) => _ReadinessCard(score: score),
                loading: () => const _ReadinessCard(score: 50),
                error: (_, s) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              // Error message
              if (analysisState.errorMessage != null) ...[
                _ErrorBanner(message: analysisState.errorMessage!),
                const SizedBox(height: 16),
              ],

              // Form Analysis Control
              _AnalysisControlCard(
                isAnalyzing: analysisState.isAnalyzing,
                onStart: () => ref
                    .read(formAnalysisStateProvider.notifier)
                    .startSession(),
                onStop: () => ref
                    .read(formAnalysisStateProvider.notifier)
                    .stopSession(),
              ),
              const SizedBox(height: 20),

              // Camera Preview during analysis
              if (analysisState.isAnalyzing) ...[
                _CameraPreviewCard(ref: ref),
                const SizedBox(height: 16),
              ],

              // Live progress during analysis — expanded with all metrics
              if (analysisState.isAnalyzing &&
                  analysisState.liveProgress != null) ...[
                _LiveMetricsDashboard(
                    progress: analysisState.liveProgress!),
                const SizedBox(height: 20),
              ],

              // ML Prediction (Injury Risk + Enhanced Score)
              if (analysisState.isLoadingPrediction) ...[
                _MLPredictionLoading(),
                const SizedBox(height: 20),
              ] else if (analysisState.mlPrediction != null) ...[
                _InjuryRiskCard(prediction: analysisState.mlPrediction!),
                const SizedBox(height: 16),
                _MLRecommendationsCard(
                    recommendations: analysisState.mlPrediction!.recommendations),
                const SizedBox(height: 20),
              ],

              // Last result
              if (analysisState.lastResult != null) ...[
                Text('Analysis Results',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _FormScoreCard(
                  result: analysisState.lastResult!,
                  mlScore: analysisState.mlPrediction?.formScore,
                  mlLevel: analysisState.mlPrediction?.formLevel,
                ),
                const SizedBox(height: 16),
                _GaitMetricsCard(result: analysisState.lastResult!),
                const SizedBox(height: 16),
                _CoachingTipsCard(
                    tips: analysisState.lastResult!.coachingTips),
              ] else if (!analysisState.isAnalyzing) ...[
                _EmptyAnalysisCard(),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.electricLime.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: AppTheme.electricLime, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('How It Works'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoStep(number: '1', text: 'Position phone to capture your running form (treadmill recommended)'),
            _InfoStep(number: '2', text: 'Tap "Start Analysis" and run for 30-60 seconds'),
            _InfoStep(number: '3', text: 'MediaPipe AI tracks 33 body landmarks in real-time'),
            _InfoStep(number: '4', text: 'Get instant biomechanical feedback + injury risk assessment'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _InfoStep extends StatelessWidget {
  final String number;
  final String text;
  const _InfoStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.electricLime,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: AppTheme.background,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

// ============================================================
// Readiness Card
// ============================================================

class _ReadinessCard extends StatelessWidget {
  final int score;
  const _ReadinessCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? AppTheme.success
        : score >= 40
            ? AppTheme.warning
            : AppTheme.error;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: AppTheme.surfaceLight,
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
                Text('$score',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Morning Readiness',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 4),
                Text(
                  _readinessMessage(score),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _readinessMessage(int score) {
    if (score >= 80) return 'Peak condition — great day for quality work!';
    if (score >= 60) return 'Well recovered — normal training recommended.';
    if (score >= 40) return 'Moderate recovery — easy effort today.';
    return 'Low recovery — rest or very light movement.';
  }
}

// ============================================================
// Analysis Control Card
// ============================================================

class _AnalysisControlCard extends StatelessWidget {
  final bool isAnalyzing;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _AnalysisControlCard({
    required this.isAnalyzing,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAnalyzing
              ? AppTheme.error.withValues(alpha: 0.3)
              : AppTheme.electricLime.withValues(alpha: 0.15),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAnalyzing
                  ? AppTheme.error.withValues(alpha: 0.12)
                  : AppTheme.electricLime.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: (isAnalyzing ? AppTheme.error : AppTheme.electricLime)
                      .withValues(alpha: 0.15),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(
              isAnalyzing
                  ? Icons.videocam_rounded
                  : Icons.accessibility_new_rounded,
              size: 36,
              color: isAnalyzing ? AppTheme.error : AppTheme.electricLime,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isAnalyzing ? 'Analyzing Your Form...' : 'Analyze Running Form',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            isAnalyzing
                ? 'Keep running naturally. AI is tracking 33 body landmarks.'
                : 'Use camera to get AI-powered biomechanical feedback.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isAnalyzing ? onStop : onStart,
              icon: Icon(
                isAnalyzing
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                size: 24,
              ),
              label: Text(
                isAnalyzing ? 'Stop Analysis' : 'Start Analysis',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: isAnalyzing
                  ? ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    )
                  : ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Live Metrics Dashboard — Full real-time view
// ============================================================

class _LiveMetricsDashboard extends StatelessWidget {
  final FormAnalysisProgress progress;
  const _LiveMetricsDashboard({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.electricLime.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.success.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('Live Analysis',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.electricLime,
                        fontWeight: FontWeight.w700,
                      )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${progress.sessionDurationSec}s • ${progress.framesProcessed} frames',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Large form score
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _scoreColor(progress.formScore).withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${progress.formScore}',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: _scoreColor(progress.formScore),
                              fontWeight: FontWeight.w900,
                            )),
                    Text('FORM',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.textSecondary,
                              letterSpacing: 1.5,
                            )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Metric grid
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  icon: Icons.speed_rounded,
                  label: 'Cadence',
                  value: '${progress.cadence}',
                  unit: 'spm',
                  color: AppTheme.pace,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.timer_rounded,
                  label: 'GCT',
                  value: '${progress.groundContactTimeMs.toInt()}',
                  unit: 'ms',
                  color: AppTheme.distance,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.height_rounded,
                  label: 'Osc',
                  value: progress.verticalOscillationCm.toStringAsFixed(1),
                  unit: 'cm',
                  color: AppTheme.elevation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  icon: Icons.airline_seat_recline_normal_rounded,
                  label: 'Lean',
                  value: '${progress.forwardLeanDeg.toStringAsFixed(1)}°',
                  color: AppTheme.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.accessibility_rounded,
                  label: 'Hip Drop',
                  value: '${progress.hipDropDeg.toStringAsFixed(1)}°',
                  color: progress.hipDropDeg > 8 ? AppTheme.error : AppTheme.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.directions_walk_rounded,
                  label: 'Strike',
                  value: progress.footStrikeType.toUpperCase(),
                  color: AppTheme.textPrimary,
                  smallText: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 75) return AppTheme.success;
    if (score >= 55) return AppTheme.electricLime;
    if (score >= 40) return AppTheme.warning;
    return AppTheme.error;
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final bool smallText;

  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    required this.color,
    this.smallText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: smallText ? 11 : 16,
                ),
          ),
          if (unit != null)
            Text(unit!,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color.withValues(alpha: 0.7), fontSize: 10)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.textTertiary, fontSize: 10)),
        ],
      ),
    );
  }
}

// ============================================================
// ML Prediction Loading
// ============================================================

class _MLPredictionLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.info,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Running ML Analysis...',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppTheme.info)),
                const SizedBox(height: 2),
                Text('Evaluating biomechanics for injury risk and form scoring',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Injury Risk Card
// ============================================================

class _InjuryRiskCard extends StatelessWidget {
  final FormAnalysisPrediction prediction;
  const _InjuryRiskCard({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final riskColor = prediction.injuryRiskLevel == 'high'
        ? AppTheme.error
        : prediction.injuryRiskLevel == 'moderate'
            ? AppTheme.warning
            : AppTheme.success;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [riskColor.withValues(alpha: 0.12), riskColor.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              prediction.injuryRiskLevel == 'high'
                  ? Icons.warning_amber_rounded
                  : prediction.injuryRiskLevel == 'moderate'
                      ? Icons.shield_outlined
                      : Icons.verified_rounded,
              color: riskColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Injury Risk',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        )),
                const SizedBox(height: 2),
                Text(
                  prediction.injuryRiskLevel.toUpperCase(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: riskColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('ML Score',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textTertiary,
                      )),
              Text(
                '${prediction.formScore.toInt()}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.electricLime,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(prediction.formLevel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.electricLime,
                      )),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ML Recommendations Card
// ============================================================

class _MLRecommendationsCard extends StatelessWidget {
  final List<String> recommendations;
  const _MLRecommendationsCard({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.electricLime, size: 18),
              const SizedBox(width: 8),
              Text('AI Recommendations',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
            ],
          ),
          const SizedBox(height: 12),
          ...recommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.electricLime,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(rec,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              )),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ============================================================
// Form Score Card
// ============================================================

class _FormScoreCard extends StatelessWidget {
  final FormAnalysisResult result;
  final double? mlScore;
  final String? mlLevel;
  const _FormScoreCard({required this.result, this.mlScore, this.mlLevel});

  @override
  Widget build(BuildContext context) {
    final displayScore = mlScore?.toInt() ?? result.formScore;
    final scoreColor = displayScore >= 75
        ? AppTheme.success
        : displayScore >= 55
            ? AppTheme.electricLime
            : displayScore >= 40
                ? AppTheme.warning
                : AppTheme.error;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withValues(alpha: 0.12),
            scoreColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Score ring
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: displayScore / 100,
                  strokeWidth: 8,
                  backgroundColor: AppTheme.surfaceLight,
                  valueColor: AlwaysStoppedAnimation(scoreColor),
                  strokeCap: StrokeCap.round,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$displayScore',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: scoreColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 44,
                            )),
                    if (mlLevel != null)
                      Text(
                        mlLevel!.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Form Score',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 4),
          Text(
            '${result.framesAnalyzed} frames • '
            '${(result.avgLandmarkConfidence * 100).toInt()}% confidence',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Gait Metrics Card
// ============================================================

class _GaitMetricsCard extends StatelessWidget {
  final FormAnalysisResult result;
  const _GaitMetricsCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gait Metrics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 16),
          _MetricRow(
            icon: Icons.timer_rounded,
            label: 'Ground Contact Time',
            value: '${result.groundContactTimeMs.toInt()} ms',
            assessment: result.gctAssessment,
          ),
          _MetricRow(
            icon: Icons.height_rounded,
            label: 'Vertical Oscillation',
            value: '${result.verticalOscillationCm.toStringAsFixed(1)} cm',
            assessment: result.oscillationAssessment,
          ),
          _MetricRow(
            icon: Icons.speed_rounded,
            label: 'Cadence',
            value: '${result.cadenceSpm} spm',
            assessment: result.cadenceAssessment,
          ),
          _MetricRow(
            icon: Icons.straighten_rounded,
            label: 'Stride Length',
            value: '${result.strideLengthM.toStringAsFixed(2)} m',
          ),
          if (result.forwardLeanDeg != null)
            _MetricRow(
              icon: Icons.airline_seat_recline_normal_rounded,
              label: 'Forward Lean',
              value: '${result.forwardLeanDeg!.toStringAsFixed(1)}°',
              assessment: (result.forwardLeanDeg! >= 5 && result.forwardLeanDeg! <= 12)
                  ? 'Good'
                  : 'Adjust',
            ),
          if (result.hipDropDeg != null)
            _MetricRow(
              icon: Icons.accessibility_rounded,
              label: 'Hip Drop',
              value: '${result.hipDropDeg!.toStringAsFixed(1)}°',
              assessment:
                  result.hipDropDeg! < 5 ? 'Good' : result.hipDropDeg! < 8 ? 'Moderate' : 'High',
            ),
          if (result.armSwingSymmetryPct != null)
            _MetricRow(
              icon: Icons.compare_arrows_rounded,
              label: 'Arm Symmetry',
              value: '${result.armSwingSymmetryPct!.toInt()}%',
              assessment: result.armSwingSymmetryPct! >= 85 ? 'Good' : 'Asymmetric',
            ),
          _MetricRow(
            icon: Icons.directions_walk_rounded,
            label: 'Foot Strike',
            value: (result.footStrikeType ?? 'midfoot').toUpperCase(),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? assessment;

  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    this.assessment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.electricLime.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppTheme.electricLime),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    color: AppTheme.electricLime,
                    fontWeight: FontWeight.w600,
                  )),
          if (assessment != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _assessmentColor(assessment!).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                assessment!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _assessmentColor(assessment!),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _assessmentColor(String assessment) {
    switch (assessment) {
      case 'Elite':
      case 'Excellent':
      case 'Optimal':
      case 'Good':
        return AppTheme.success;
      case 'Average':
      case 'Below Optimal':
      case 'Moderate':
      case 'Adjust':
        return AppTheme.warning;
      default:
        return AppTheme.error;
    }
  }
}

// ============================================================
// Coaching Tips Card
// ============================================================

class _CoachingTipsCard extends StatelessWidget {
  final List<String> tips;
  const _CoachingTipsCard({required this.tips});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: AppTheme.electricLime, size: 20),
              const SizedBox(width: 8),
              Text('Coaching Tips',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppTheme.electricLime,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(tip,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.4,
                              )),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ============================================================
// Camera Preview Card
// ============================================================

class _CameraPreviewCard extends StatelessWidget {
  final WidgetRef ref;
  const _CameraPreviewCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    final cameraService = ref.watch(poseCameraServiceProvider);
    final controller = cameraService.cameraController;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.electricLime.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.electricLime.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Camera feed
          AspectRatio(
            aspectRatio: 3 / 4,
            child: controller != null && controller.value.isInitialized
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(controller),
                      _ScanOverlay(),
                    ],
                  )
                : Container(
                    color: AppTheme.surfaceLight,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppTheme.electricLime,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Initializing camera...',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.electricLime.withValues(alpha: 0.06),
              border: Border(
                top: BorderSide(
                  color: AppTheme.electricLime.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: controller != null && controller.value.isInitialized
                        ? AppTheme.success
                        : AppTheme.warning,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (controller != null && controller.value.isInitialized
                                ? AppTheme.success
                                : AppTheme.warning)
                            .withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  controller != null && controller.value.isInitialized
                      ? 'Pose Detection Active'
                      : 'Connecting...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.electricLime,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                const Icon(
                  Icons.visibility_rounded,
                  size: 16,
                  color: AppTheme.electricLime,
                ),
                const SizedBox(width: 4),
                Text(
                  '33 landmarks',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Scan overlay that shows targeting guides on the camera preview
class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScanOverlayPainter(),
      child: Container(),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.electricLime.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final cornerLength = size.width * 0.08;
    final margin = size.width * 0.1;
    final rect = Rect.fromLTRB(
      margin,
      size.height * 0.05,
      size.width - margin,
      size.height * 0.95,
    );

    // Top-left corner
    canvas.drawLine(rect.topLeft, Offset(rect.left + cornerLength, rect.top), paint);
    canvas.drawLine(rect.topLeft, Offset(rect.left, rect.top + cornerLength), paint);

    // Top-right corner
    canvas.drawLine(rect.topRight, Offset(rect.right - cornerLength, rect.top), paint);
    canvas.drawLine(rect.topRight, Offset(rect.right, rect.top + cornerLength), paint);

    // Bottom-left corner
    canvas.drawLine(rect.bottomLeft, Offset(rect.left + cornerLength, rect.bottom), paint);
    canvas.drawLine(rect.bottomLeft, Offset(rect.left, rect.bottom - cornerLength), paint);

    // Bottom-right corner
    canvas.drawLine(rect.bottomRight, Offset(rect.right - cornerLength, rect.bottom), paint);
    canvas.drawLine(rect.bottomRight, Offset(rect.right, rect.bottom - cornerLength), paint);

    // Center crosshair (subtle)
    final center = rect.center;
    final crossSize = size.width * 0.03;
    final crossPaint = Paint()
      ..color = AppTheme.electricLime.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - crossSize, center.dy),
      Offset(center.dx + crossSize, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - crossSize),
      Offset(center.dx, center.dy + crossSize),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// Error Banner
// ============================================================

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppTheme.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Empty State
// ============================================================

class _EmptyAnalysisCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.electricLime.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.accessibility_new_rounded,
                size: 40, color: AppTheme.electricLime.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          Text('No Analysis Yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 8),
          Text(
            'Start a session to get AI-powered running biomechanics feedback with injury risk assessment.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
