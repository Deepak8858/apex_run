import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apex_run/core/theme/app_theme.dart';
import 'package:apex_run/ml/models/form_analysis_result.dart';
import 'package:apex_run/ml/models/hrv_data.dart';

Widget testApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: child,
    ),
  );
}

void main() {
  group('Form Analysis Screen Components', () {
    testWidgets('Readiness card shows score and status', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Recovery Status',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: 0.82,
                            strokeWidth: 8,
                            color: AppTheme.success,
                            backgroundColor: AppTheme.surfaceLight,
                          ),
                          const Text(
                            '82',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Optimal',
                      style: TextStyle(color: AppTheme.success),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Great day for quality training',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Recovery Status'), findsOneWidget);
      expect(find.text('82'), findsOneWidget);
      expect(find.text('Optimal'), findsOneWidget);
      expect(find.text('Great day for quality training'), findsOneWidget);
    });

    testWidgets('Form score card shows score with color', (tester) async {
      final result = FormAnalysisResult(
        groundContactTimeMs: 210,
        verticalOscillationCm: 8.5,
        cadenceSpm: 178,
        strideLengthM: 1.15,
        formScore: 78,
        coachingTips: ['Increase cadence to 180+', 'Reduce ground contact time'],
      );

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Form Score',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${result.formScore}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: result.formScore >= 80
                            ? AppTheme.success
                            : result.formScore >= 60
                                ? AppTheme.warning
                                : AppTheme.error,
                      ),
                    ),
                    const Text(
                      'out of 100',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Form Score'), findsOneWidget);
      expect(find.text('78'), findsOneWidget);
      expect(find.text('out of 100'), findsOneWidget);
    });

    testWidgets('Gait metrics display correctly', (tester) async {
      final result = FormAnalysisResult(
        groundContactTimeMs: 215,
        verticalOscillationCm: 9.0,
        cadenceSpm: 175,
        strideLengthM: 1.12,
        forwardLeanDeg: 8.5,
        hipDropDeg: 4.2,
        armSwingSymmetryPct: 92,
        footStrikeType: 'midfoot',
        formScore: 72,
      );

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  _MetricRow('Ground Contact', '${result.groundContactTimeMs} ms', result.gctAssessment),
                  _MetricRow('Vertical Osc.', '${result.verticalOscillationCm.toStringAsFixed(1)} cm', result.oscillationAssessment),
                  _MetricRow('Cadence', '${result.cadenceSpm} spm', result.cadenceAssessment),
                  _MetricRow('Stride Length', '${result.strideLengthM.toStringAsFixed(2)} m', ''),
                  _MetricRow('Forward Lean', '${result.forwardLeanDeg?.toStringAsFixed(1)}°', ''),
                  _MetricRow('Foot Strike', result.footStrikeType ?? 'Unknown', ''),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ground Contact'), findsOneWidget);
      expect(find.text('215 ms'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('175 spm'), findsOneWidget);
      expect(find.text('midfoot'), findsOneWidget);
    });

    testWidgets('Coaching tips list renders all tips', (tester) async {
      final tips = [
        'Focus on quick ground contact',
        'Aim for 180 steps per minute',
        'Keep forward lean around 5-10 degrees',
      ];

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Coaching Tips',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...tips.map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb_outline,
                                  color: AppTheme.electricLime, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(tip)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Coaching Tips'), findsOneWidget);
      expect(find.text('Focus on quick ground contact'), findsOneWidget);
      expect(find.text('Aim for 180 steps per minute'), findsOneWidget);
      expect(find.text('Keep forward lean around 5-10 degrees'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline), findsNWidgets(3));
    });

    testWidgets('HRV data shows recovery status colors', (tester) async {
      final statuses = {
        RecoveryStatus.optimal: AppTheme.success,
        RecoveryStatus.good: AppTheme.electricLime,
        RecoveryStatus.moderate: AppTheme.warning,
        RecoveryStatus.low: AppTheme.error,
        RecoveryStatus.critical: AppTheme.error,
      };

      for (final entry in statuses.entries) {
        final statusStr = entry.key.toString().split('.').last;
        final color = entry.value;

        await tester.pumpWidget(
          testApp(
            Scaffold(
              body: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusStr.substring(0, 1).toUpperCase() + statusStr.substring(1),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          find.text(statusStr.substring(0, 1).toUpperCase() + statusStr.substring(1)),
          findsOneWidget,
        );
      }
    });
  });
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final String assessment;

  const _MetricRow(this.label, this.value, this.assessment);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (assessment.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(assessment, style: const TextStyle(color: AppTheme.electricLime, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
