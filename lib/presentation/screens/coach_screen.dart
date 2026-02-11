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
        color: AppTheme.cardBackground,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.electricLime.withOpacity(0.08),
            AppTheme.cardBackground,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.electricLime.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.electricLime,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.electricLime.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  size: 32,
                  color: AppTheme.background,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gemini Coach',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.electricLime.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Powered by Gemini 1.5 Flash',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.electricLime,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isGenerating ? null : onGenerate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.electricLime,
                    foregroundColor: AppTheme.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.background,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    isGenerating ? 'Analyzing...' : 'Generate Plan',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isGenerating ? null : onInsight,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.textTertiary.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppTheme.electricLime,
                    ),
                  ),
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Side Accent
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.electricLime, Color(0xFF82B100)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 26, right: 20, top: 24, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.electricLime.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.electricLime.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          'RECOMMENDED TODAY',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.electricLime,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                      if (workout.isCompleted)
                        const Icon(Icons.check_circle_rounded, color: AppTheme.success)
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _formatWorkoutTitle(workout.workoutType),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    workout.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (workout.formattedTargetDuration != null)
                        _InteractiveStatBadge(
                            icon: Icons.timer_outlined,
                            label: workout.formattedTargetDuration!),
                      if (workout.formattedTargetDistance != null) ...[
                        const SizedBox(width: 12),
                        _InteractiveStatBadge(
                            icon: Icons.straighten,
                            label: workout.formattedTargetDistance!),
                      ]
                    ],
                  ),
                  if (workout.coachingRationale != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.surfaceLight,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.psychology_alt_rounded,
                              size: 20, color: AppTheme.electricLime),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              workout.coachingRationale!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWorkoutTitle(String type) {
    // Convert 'recovery_run' to 'Recovery Run'
    return type.split('_').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

class _InteractiveStatBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InteractiveStatBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textPrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactWorkoutCard extends StatelessWidget {
  final PlannedWorkout workout;
  const _CompactWorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {}, // Just visual for now
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      _getIconForType(workout.workoutType),
                      color: AppTheme.textSecondary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatWorkoutTitle(workout.workoutType),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(workout.plannedDate),
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    if (type.contains('run')) return Icons.directions_run;
    if (type.contains('rest')) return Icons.hotel;
    return Icons.fitness_center;
  }
  
  String _formatWorkoutTitle(String type) {
     return type.split('_').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
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
