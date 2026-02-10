import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apex_run/core/theme/app_theme.dart';
import 'package:apex_run/domain/models/weekly_stats.dart';
import 'package:apex_run/domain/models/activity.dart';

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
  group('Home Screen Components', () {
    testWidgets('Weekly stats card displays formatted values', (tester) async {
      final stats = WeeklyStats(
        totalActivities: 5,
        totalDistanceMeters: 32500.0,
        totalDurationSeconds: 10800,
        averagePaceMinPerKm: 5.2,
      );

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
                      'This Week',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: 'Runs',
                          value: '${stats.totalActivities}',
                          color: AppTheme.electricLime,
                        ),
                        _StatItem(
                          label: 'Distance',
                          value: stats.formattedDistance,
                          color: AppTheme.distance,
                        ),
                        _StatItem(
                          label: 'Duration',
                          value: stats.formattedDuration,
                          color: AppTheme.pace,
                        ),
                        _StatItem(
                          label: 'Pace',
                          value: stats.formattedPace,
                          color: AppTheme.heartRate,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('32.50 km'), findsOneWidget);
      expect(find.text('3h 0m'), findsOneWidget);
      expect(find.text('5:12 /km'), findsOneWidget);
    });

    testWidgets('Empty state shows motivational message', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_run_rounded,
                    size: 64,
                    color: AppTheme.electricLime.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No activities yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start your first run to see stats here',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('No activities yet'), findsOneWidget);
      expect(find.text('Start your first run to see stats here'), findsOneWidget);
      expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);
    });

    testWidgets('Activity list item shows run data', (tester) async {
      final activity = Activity(
        id: 'act-1',
        userId: 'user-1',
        activityType: 'run',
        distanceMeters: 5200,
        durationSeconds: 1560,
        averagePaceMinPerKm: 5.0,
        startTime: DateTime(2024, 3, 15, 7, 30),
      );

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.electricLime,
                child: Icon(Icons.directions_run, color: AppTheme.background),
              ),
              title: Text('${(activity.distanceMeters / 1000).toStringAsFixed(2)} km'),
              subtitle: Text(activity.formattedDuration),
              trailing: Text(
                activity.formattedPace,
                style: const TextStyle(
                  color: AppTheme.electricLime,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('5.20 km'), findsOneWidget);
      expect(find.byIcon(Icons.directions_run), findsOneWidget);
    });

    testWidgets('Navigation bar shows all tabs', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fiber_manual_record),
                  label: 'Record',
                ),
                NavigationDestination(
                  icon: Icon(Icons.leaderboard_rounded),
                  label: 'Leaderboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.psychology_rounded),
                  label: 'Coach',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.text('Coach'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });
  });
}

/// Simple stat display widget for testing
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
