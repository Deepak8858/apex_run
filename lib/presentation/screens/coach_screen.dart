import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/planned_workout.dart';
import '../providers/app_providers.dart';

/// AI Coach Screen - Gemini-powered Training Plans
///
/// Features:
/// - Generate daily workout recommendations via Gemini 1.5 Flash
/// - View today's planned workout
/// - Upcoming workout schedule
/// - On-demand coaching insights
class CoachScreen extends ConsumerWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachState = ref.watch(coachControllerProvider);
    final todaysWorkout = ref.watch(todaysWorkoutProvider);
    final upcomingWorkouts = ref.watch(upcomingWorkoutsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Coach'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(todaysWorkoutProvider);
              ref.invalidate(upcomingWorkoutsProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coach Header
              _CoachHeader(
                isGenerating: coachState.isGenerating,
                onGenerate: () => ref
                    .read(coachControllerProvider.notifier)
                    .generateDailyWorkout(),
                onInsight: () => ref
                    .read(coachControllerProvider.notifier)
                    .getCoachingInsight(),
              ),
              const SizedBox(height: 24),

              // Error message
              if (coachState.errorMessage != null) ...[
                _ErrorBanner(message: coachState.errorMessage!),
                const SizedBox(height: 16),
              ],

              // Coaching Insight
              if (coachState.coachingInsight != null) ...[
                _InsightCard(insight: coachState.coachingInsight!),
                const SizedBox(height: 24),
              ],

              // Today's Workout
              Text("Today's Workout",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              // Show generated workout from state if available, otherwise from DB
              if (coachState.generatedWorkout != null)
                _DetailedWorkoutCard(workout: coachState.generatedWorkout!)
              else
                todaysWorkout.when(
                  data: (workout) {
                    if (workout == null) {
                      return _NoWorkoutCard(
                        onGenerate: coachState.isGenerating
                            ? null
                            : () => ref
                                .read(coachControllerProvider.notifier)
                                .generateDailyWorkout(),
                      );
                    }
                    return _DetailedWorkoutCard(workout: workout);
                  },
                  loading: () => const _LoadingCard(),
                  error: (e, _) => _NoWorkoutCard(
                    onGenerate: coachState.isGenerating
                        ? null
                        : () => ref
                            .read(coachControllerProvider.notifier)
                            .generateDailyWorkout(),
                  ),
                ),
              const SizedBox(height: 24),

              // Upcoming Workouts
              Text('Upcoming Workouts',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              upcomingWorkouts.when(
                data: (workouts) {
                  if (workouts.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No upcoming workouts scheduled.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: workouts
                        .map((w) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _CompactWorkoutCard(workout: w),
                            ))
                        .toList(),
                  );
                },
                loading: () => const _LoadingCard(),
                error: (e, _) => const _ErrorCard(
                    message: 'Could not load upcoming workouts'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Coach Header
// ============================================================

class _CoachHeader extends StatelessWidget {
  final bool isGenerating;
  final VoidCallback onGenerate;
  final VoidCallback onInsight;
  const _CoachHeader({
    required this.isGenerating,
    required this.onGenerate,
    required this.onInsight,
  });

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
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.electricLime.withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  size: 32,
                  color: AppTheme.electricLime,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gemini AI Coach',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Powered by Gemini 1.5 Flash',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isGenerating ? null : onGenerate,
                  icon: isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.background,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                      isGenerating ? 'Generating...' : 'Generate Workout'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: isGenerating ? null : onInsight,
                icon: const Icon(Icons.lightbulb_outline_rounded),
                label: const Text('Insights'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.electricLime,
                  side: const BorderSide(color: AppTheme.electricLime),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Workout Cards
// ============================================================

class _DetailedWorkoutCard extends StatelessWidget {
  final PlannedWorkout workout;
  const _DetailedWorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _WorkoutTypeBadge(type: workout.workoutType),
                const Spacer(),
                if (workout.isCompleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Completed',
                        style:
                            TextStyle(color: AppTheme.success, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(workout.description,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                if (workout.formattedTargetDistance != null)
                  _TargetChip(
                    icon: Icons.straighten_rounded,
                    label: workout.formattedTargetDistance!,
                    color: AppTheme.distance,
                  ),
                if (workout.formattedTargetDistance != null)
                  const SizedBox(width: 12),
                if (workout.formattedTargetDuration != null)
                  _TargetChip(
                    icon: Icons.timer_rounded,
                    label: workout.formattedTargetDuration!,
                    color: AppTheme.pace,
                  ),
              ],
            ),
            if (workout.coachingRationale != null) ...[
              const SizedBox(height: 16),
              const Divider(color: AppTheme.surfaceLight),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 18, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      workout.coachingRationale!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactWorkoutCard extends StatelessWidget {
  final PlannedWorkout workout;
  const _CompactWorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _WorkoutTypeBadge(type: workout.workoutType, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workout.formattedType,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(workout.plannedDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (workout.formattedTargetDistance != null)
              Text(
                workout.formattedTargetDistance!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.distance,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff =
        date.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }
}

class _NoWorkoutCard extends StatelessWidget {
  final VoidCallback? onGenerate;
  const _NoWorkoutCard({this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: 12),
              Text(
                'No workout planned for today',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (onGenerate != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Generate with AI'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Insight Card
// ============================================================

class _InsightCard extends StatelessWidget {
  final String insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded,
                  size: 20, color: AppTheme.info),
              const SizedBox(width: 8),
              Text('Coach Insight',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppTheme.info)),
            ],
          ),
          const SizedBox(height: 12),
          Text(insight, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ============================================================
// Shared Widgets
// ============================================================

class _WorkoutTypeBadge extends StatelessWidget {
  final String type;
  final double size;
  const _WorkoutTypeBadge({required this.type, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_icon, color: _color, size: size * 0.5),
    );
  }

  IconData get _icon {
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

  Color get _color {
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

class _TargetChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _TargetChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
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
              child:
                  Text(message, style: const TextStyle(color: AppTheme.error)),
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
