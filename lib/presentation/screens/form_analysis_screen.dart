import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../ml/ml_providers.dart';
import '../../ml/models/form_analysis_result.dart';
import '../../ml/form_analyzer.dart';

/// Form Analysis Screen — ML-powered running form feedback
///
/// Displays:
/// - Live form score during analysis
/// - Detailed biomechanical metrics
/// - Coaching tips for improvement
/// - Historical form data
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
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

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
              const SizedBox(height: 24),

              // Camera Preview during analysis
              if (analysisState.isAnalyzing) ...[
                _CameraPreviewCard(ref: ref),
                const SizedBox(height: 24),
              ],

              // Live progress during analysis
              if (analysisState.isAnalyzing &&
                  analysisState.liveProgress != null) ...[
                _LiveProgressCard(
                    progress: analysisState.liveProgress!),
                const SizedBox(height: 24),
              ],

              // Last result
              if (analysisState.lastResult != null) ...[
                Text('Last Analysis',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _FormScoreCard(result: analysisState.lastResult!),
                const SizedBox(height: 16),
                _GaitMetricsCard(result: analysisState.lastResult!),
                const SizedBox(height: 16),
                _CoachingTipsCard(
                    tips: analysisState.lastResult!.coachingTips),
              ] else ...[
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
        title: const Text('How Form Analysis Works'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Position your phone to capture your running form '
                '(treadmill recommended)'),
            SizedBox(height: 8),
            Text('2. Tap "Start Analysis" and run for 30-60 seconds'),
            SizedBox(height: 8),
            Text('3. MediaPipe AI tracks 33 body landmarks'),
            SizedBox(height: 8),
            Text('4. Get instant feedback on form, cadence, and efficiency'),
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
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
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
                ),
                Text('$score',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: color)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Morning Readiness',
                    style: Theme.of(context).textTheme.titleMedium),
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
    if (score >= 80) return 'Peak condition — great day for hard training!';
    if (score >= 60) return 'Well recovered — normal training recommended.';
    if (score >= 40) return 'Moderate recovery — keep effort easy today.';
    return 'Low recovery — consider rest or very light activity.';
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              isAnalyzing
                  ? Icons.videocam_rounded
                  : Icons.accessibility_new_rounded,
              size: 48,
              color: isAnalyzing
                  ? AppTheme.error
                  : AppTheme.electricLime,
            ),
            const SizedBox(height: 16),
            Text(
              isAnalyzing ? 'Analyzing Your Form...' : 'Analyze Running Form',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isAnalyzing
                  ? 'Keep running naturally. Camera tracks your movements.'
                  : 'Use your phone camera to analyze your running biomechanics.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isAnalyzing ? onStop : onStart,
                icon: Icon(
                  isAnalyzing
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(isAnalyzing ? 'Stop Analysis' : 'Start Analysis'),
                style: isAnalyzing
                    ? ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Live Progress Card
// ============================================================

class _LiveProgressCard extends StatelessWidget {
  final FormAnalysisProgress progress;
  const _LiveProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _LiveMetric(
              label: 'Score',
              value: '${progress.formScore}',
              color: _scoreColor(progress.formScore),
            ),
            _LiveMetric(
              label: 'Cadence',
              value: '${progress.cadence}',
              unit: 'spm',
              color: AppTheme.pace,
            ),
            _LiveMetric(
              label: 'GCT',
              value: '${progress.groundContactTimeMs.toInt()}',
              unit: 'ms',
              color: AppTheme.distance,
            ),
            _LiveMetric(
              label: 'Frames',
              value: '${progress.framesProcessed}',
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 75) return AppTheme.success;
    if (score >= 50) return AppTheme.warning;
    return AppTheme.error;
  }
}

class _LiveMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;
  const _LiveMetric({
    required this.label,
    required this.value,
    this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: color)),
        if (unit != null)
          Text(unit!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color.withOpacity(0.7))),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ============================================================
// Form Score Card
// ============================================================

class _FormScoreCard extends StatelessWidget {
  final FormAnalysisResult result;
  const _FormScoreCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final scoreColor = result.formScore >= 75
        ? AppTheme.success
        : result.formScore >= 50
            ? AppTheme.warning
            : AppTheme.error;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withOpacity(0.15),
            scoreColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('${result.formScore}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 48,
                  )),
          Text('Form Score',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '${result.framesAnalyzed} frames analyzed • '
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gait Metrics',
                style: Theme.of(context).textTheme.titleMedium),
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
              ),
            if (result.hipDropDeg != null)
              _MetricRow(
                icon: Icons.accessibility_rounded,
                label: 'Hip Drop',
                value: '${result.hipDropDeg!.toStringAsFixed(1)}°',
                assessment:
                    result.hipDropDeg! < 5 ? 'Good' : 'Needs Work',
              ),
            _MetricRow(
              icon: Icons.directions_walk_rounded,
              label: 'Foot Strike',
              value: (result.footStrikeType ?? 'midfoot').toUpperCase(),
            ),
          ],
        ),
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
          Icon(icon, size: 20, color: AppTheme.electricLime),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppTheme.electricLime)),
          if (assessment != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _assessmentColor(assessment!).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                assessment!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _assessmentColor(assessment!),
                      fontSize: 10,
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
    return Card(
      child: Padding(
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
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(color: AppTheme.electricLime)),
                      Expanded(
                        child: Text(tip,
                            style:
                                Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                )),
          ],
        ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.electricLime.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.electricLime.withOpacity(0.05),
            blurRadius: 12,
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
                      // Scanning overlay
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
              color: AppTheme.electricLime.withOpacity(0.08),
              border: Border(
                top: BorderSide(
                  color: AppTheme.electricLime.withOpacity(0.2),
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
                            .withOpacity(0.5),
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
      ..color = AppTheme.electricLime.withOpacity(0.6)
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
      ..color = AppTheme.electricLime.withOpacity(0.3)
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
// Empty State
// ============================================================

class _EmptyAnalysisCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.accessibility_new_rounded,
                size: 64, color: AppTheme.electricLime.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No Analysis Yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Start a form analysis session to get AI-powered feedback on your running biomechanics.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
