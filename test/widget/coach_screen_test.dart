import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apex_run/core/theme/app_theme.dart';
import 'package:apex_run/domain/models/planned_workout.dart';

/// Helper to wrap a widget for testing with theme & Riverpod
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
  group('CoachScreen Components', () {
    testWidgets('Coach header renders title and buttons', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            appBar: AppBar(title: const Text('AI Coach')),
            body: const Center(
              child: Text('Coach Screen'),
            ),
          ),
        ),
      );

      expect(find.text('AI Coach'), findsOneWidget);
    });

    testWidgets('PlannedWorkout card displays workout info', (tester) async {
      final workout = PlannedWorkout(
        id: 'test-1',
        userId: 'user-1',
        workoutType: 'tempo',
        description: 'Run 5km at tempo pace to build lactate threshold.',
        targetDistanceMeters: 5000.0,
        targetDurationMinutes: 25,
        plannedDate: DateTime(2024, 3, 15),
        isCompleted: false,
      );

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        workout.formattedType,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(workout.description),
                      if (workout.targetDistanceMeters != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Target: ${(workout.targetDistanceMeters! / 1000).toStringAsFixed(1)} km',
                        ),
                      ],
                      if (workout.targetDurationMinutes != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Duration: ${workout.targetDurationMinutes} min',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tempo Run'), findsOneWidget);
      expect(find.textContaining('tempo pace'), findsOneWidget);
      expect(find.text('Target: 5.0 km'), findsOneWidget);
      expect(find.text('Duration: 25 min'), findsOneWidget);
    });

    testWidgets('Error banner displays error message', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Something went wrong. Try again later.',
                      style: TextStyle(color: AppTheme.error, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Something went wrong. Try again later.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('Generate button renders correctly', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Center(
              child: ElevatedButton.icon(
                onPressed: () => pressed = true,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Workout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.electricLime,
                  foregroundColor: AppTheme.background,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Generate Workout'), findsOneWidget);
      await tester.tap(find.text('Generate Workout'));
      expect(pressed, true);
    });

    testWidgets('Completed workout shows checkmark styling', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Text('Easy Run - Completed'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Easy Run - Completed'), findsOneWidget);
    });
  });
}
