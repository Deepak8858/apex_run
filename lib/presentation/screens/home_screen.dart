import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/planned_workout.dart';
import '../../domain/models/weekly_stats.dart';
import '../providers/app_providers.dart';
import 'activity_detail_screen.dart';

/// Home Screen - Dashboard
///
/// Displays:
/// - Weekly training summary (live from Supabase)
/// - Recent activities
/// - Upcoming planned workouts
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyStats = ref.watch(weeklyStatsProvider);
    final recentActivities = ref.watch(recentActivitiesProvider);
    final upcomingWorkouts = ref.watch(upcomingWorkoutsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ApexRun'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(weeklyStatsProvider);
              ref.invalidate(recentActivitiesProvider);
              ref.invalidate(upcomingWorkoutsProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.electricLime,
          onRefresh: () async {
            ref.invalidate(weeklyStatsProvider);
            ref.invalidate(recentActivitiesProvider);
            ref.invalidate(upcomingWorkoutsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Message
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ready to crush your next run?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),

                // Weekly Summary Card
                weeklyStats.when(
                  data: (stats) => _WeeklySummaryCard(stats: stats),
                  loading: () => const _WeeklySummaryCardSkeleton(),
                  error: (e, _) =>
                      const _ErrorCard(message: 'Could not load weekly stats'),
                ),
                const SizedBox(height: 24),

                // Recent Activities
                _SectionHeader(
                  title: 'Recent Activities',
                  trailing: recentActivities.valueOrNull?.isNotEmpty == true
                      ? TextButton(
                          onPressed: () {},
                          child: const Text('See All'),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                recentActivities.when(
                  data: (activities) {
                    if (activities.isEmpty) {
                      return const _EmptyStateCard(
                        message: 'No activities yet. Start your first run!',
                        icon: Icons.directions_run_rounded,
                      );
                    }
                    return Column(
                      children: activities
                          .map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ActivityDetailScreen(activity: a),
                                    ),
                                  ),
                                  child: _ActivityCard(activity: a),
                                ),
                              ))
                          .toList(),
                    );
                  },
                  loading: () => const _LoadingCard(),
                  error: (e, _) =>
                      const _ErrorCard(message: 'Could not load activities'),
                ),
                const SizedBox(height: 24),

                // Upcoming Workouts
                const _SectionHeader(title: 'Planned Workouts'),
                const SizedBox(height: 12),
                upcomingWorkouts.when(
                  data: (workouts) {
                    if (workouts.isEmpty) {
                      return const _EmptyStateCard(
                        message: 'No upcoming workouts. Ask your AI Coach!',
                        icon: Icons.calendar_today_rounded,
                      );
                    }
                    return Column(
                      children: workouts
                          .take(3)
                          .map((w) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _WorkoutCard(workout: w),
                              ))
                          .toList(),
                    );
                  },
                  loading: () => const _LoadingCard(),
                  error: (e, _) =>
                      const _ErrorCard(message: 'Could not load workouts'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Weekly Summary Card
// ============================================================

class _WeeklySummaryCard extends StatelessWidget {
  final WeeklyStats stats;
  const _WeeklySummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.performanceGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 18, color: AppTheme.electricLime),
              const SizedBox(width: 8),
              Text(
                'This Week',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricColumn(
                value: '${stats.runCount}',
                label: 'Runs',
                color: AppTheme.electricLime,
              ),
              _MetricColumn(
                value: stats.formattedDistance,
                label: 'Distance',
                color: AppTheme.distance,
              ),
              _MetricColumn(
                value: stats.formattedDuration,
                label: 'Time',
                color: AppTheme.pace,
              ),
              _MetricColumn(
                value: stats.formattedPace,
                label: 'Avg Pace',
                color: AppTheme.heartRate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MetricColumn({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _WeeklySummaryCardSkeleton extends StatelessWidget {
  const _WeeklySummaryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppTheme.electricLime),
      ),
    );
  }
}

// ============================================================
// Activity Card
// ============================================================

class _ActivityCard extends StatelessWidget {
  final Activity activity;
  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.electricLime.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _activityIcon(activity.activityType),
                color: AppTheme.electricLime,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.activityName,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(activity.startTime),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  activity.formattedDistance,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.distance,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      activity.formattedDuration,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      activity.formattedPace,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.pace,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'run':
        return Icons.directions_run_rounded;
      case 'walk':
        return Icons.directions_walk_rounded;
      case 'bike':
        return Icons.directions_bike_rounded;
      case 'hike':
        return Icons.terrain_rounded;
      default:
        return Icons.directions_run_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ============================================================
// Workout Card
// ============================================================

class _WorkoutCard extends StatelessWidget {
  final PlannedWorkout workout;
  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _workoutColor(workout.workoutType).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _workoutIcon(workout.workoutType),
                color: _workoutColor(workout.workoutType),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.formattedType,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    workout.description,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (workout.formattedTargetDistance != null)
                  Text(
                    workout.formattedTargetDistance!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.distance,
                        ),
                  ),
                if (workout.formattedTargetDuration != null)
                  Text(
                    workout.formattedTargetDuration!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _workoutIcon(String type) {
    switch (type) {
      case 'easy':
        return Icons.self_improvement_rounded;
      case 'tempo':
        return Icons.speed_rounded;
      case 'intervals':
        return Icons.flash_on_rounded;
      case 'long_run':
        return Icons.route_rounded;
      case 'recovery':
        return Icons.healing_rounded;
      case 'race':
        return Icons.emoji_events_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  Color _workoutColor(String type) {
    switch (type) {
      case 'easy':
        return AppTheme.success;
      case 'tempo':
        return AppTheme.warning;
      case 'intervals':
        return AppTheme.heartRate;
      case 'long_run':
        return AppTheme.distance;
      case 'recovery':
        return AppTheme.info;
      case 'race':
        return AppTheme.electricLime;
      default:
        return AppTheme.electricLime;
    }
  }
}

// ============================================================
// Shared Widgets
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        ?trailing,
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyStateCard({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.electricLime,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}
