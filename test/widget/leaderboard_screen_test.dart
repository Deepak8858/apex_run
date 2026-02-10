import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apex_run/core/theme/app_theme.dart';
import 'package:apex_run/domain/models/segment.dart';
import 'package:apex_run/domain/models/segment_effort.dart';

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
  group('Leaderboard Screen Components', () {
    testWidgets('Segment card shows name, distance, and stats', (tester) async {
      final segment = Segment.fromSupabaseJson({
        'id': 'seg-1',
        'name': 'Riverside Loop',
        'distance_meters': 3200.0,
        'elevation_gain_meters': 25.0,
        'is_verified': true,
        'total_attempts': 120,
        'unique_athletes': 45,
      });

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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            segment.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (segment.isVerified)
                          const Icon(
                            Icons.verified,
                            color: AppTheme.electricLime,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(segment.formattedDistance),
                        const SizedBox(width: 16),
                        Text('${segment.elevationGainMeters?.toStringAsFixed(0) ?? 0}m gain'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${segment.totalAttempts} attempts · ${segment.uniqueAthletes} athletes',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Riverside Loop'), findsOneWidget);
      expect(find.text('3.20 km'), findsOneWidget);
      expect(find.text('25m gain'), findsOneWidget);
      expect(find.text('120 attempts · 45 athletes'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('Leaderboard row shows rank, time, and pace', (tester) async {
      final effort = SegmentEffort(
        id: 'eff-1',
        segmentId: 'seg-1',
        activityId: 'act-1',
        userId: 'user-1',
        elapsedSeconds: 720,
        avgPaceMinPerKm: 3.75,
        recordedAt: DateTime(2024, 3, 15),
      );

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.electricLime,
                child: Text(
                  '1',
                  style: const TextStyle(
                    color: AppTheme.background,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(effort.formattedTime),
              subtitle: Text(effort.formattedPace),
              trailing: const Icon(Icons.emoji_events, color: Colors.amber),
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      expect(find.text('3:45 /km'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });

    testWidgets('Error view shows retry button', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not load segments',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check your connection and try again',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => retried = true,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Could not load segments'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, true);
    });

    testWidgets('Top 3 podium shows gold/silver/bronze', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PodiumPosition(rank: 2, color: Colors.grey.shade400, label: 'Silver'),
                _PodiumPosition(rank: 1, color: Colors.amber, label: 'Gold'),
                _PodiumPosition(rank: 3, color: Colors.brown.shade300, label: 'Bronze'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Gold'), findsOneWidget);
      expect(find.text('Silver'), findsOneWidget);
      expect(find.text('Bronze'), findsOneWidget);
    });
  });
}

class _PodiumPosition extends StatelessWidget {
  final int rank;
  final Color color;
  final String label;

  const _PodiumPosition({
    required this.rank,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: color,
          child: Text(
            '$rank',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}
