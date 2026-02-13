import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/gps_point.dart';
import '../../domain/models/planned_workout.dart';
import '../../domain/models/weekly_stats.dart';
import '../providers/app_providers.dart';
import '../providers/step_tracking_provider.dart';
import 'activity_dashboard_screen.dart';
import 'activity_detail_screen.dart';
import 'form_analysis_screen.dart';

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ready to crush your next run?',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: AppTheme.textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Today's Steps Card
                _TodayStepsCard(),
                const SizedBox(height: 24),

                // Weekly Summary Card
                weeklyStats.when(
                  data: (stats) => _WeeklySummaryCard(stats: stats),
                  loading: () => const _WeeklySummaryCardSkeleton(),
                  error: (e, _) =>
                      const _ErrorCard(message: 'Could not load weekly stats'),
                ),
                const SizedBox(height: 24),

                // Quick Actions
                _QuickActionsRow(
                  onFormAnalysis: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FormAnalysisScreen(),
                    ),
                  ),
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
                                child: GestureDetector(
                                  onTap: () => _showWorkoutDetail(context, w),
                                  child: _WorkoutCard(workout: w),
                                ),
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
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Ambient Gradient Glow
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.electricLime.withValues(alpha: 0.15),
                      AppTheme.electricLime.withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.electricLime.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          size: 18,
                          color: AppTheme.electricLime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Weekly Progress',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MetricColumn(
                        value: '${stats.runCount}',
                        label: 'Runs',
                        color: AppTheme.electricLime,
                      ),
                      _VerticalDivider(),
                      _MetricColumn(
                        value: stats.formattedDistance,
                        label: 'Distance',
                        color: AppTheme.distance,
                      ),
                      _VerticalDivider(),
                      _MetricColumn(
                        value: stats.formattedDuration,
                        label: 'Time',
                        color: AppTheme.pace,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 1,
      color: AppTheme.surfaceLight,
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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
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
      height: 160,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            color: AppTheme.electricLime,
            strokeWidth: 3,
          ),
        ),
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
    final hasRoute = activity.rawGpsPoints.length >= 2;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Mini route map or activity icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasRoute
                ? CustomPaint(
                    painter: _MiniRoutePainter(
                      points: activity.rawGpsPoints,
                    ),
                  )
                : Icon(
                    _ActivityCardHelper.activityIcon(activity.activityType),
                    color: AppTheme.electricLime,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.activityName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      _ActivityCardHelper.formatDate(activity.startTime),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _CompactStat(
                      value: activity.formattedDistance,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 10, color: AppTheme.surfaceLight),
                    const SizedBox(width: 12),
                    _CompactStat(
                      value: activity.formattedDuration,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textTertiary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String value;
  final Color color;

  const _CompactStat({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _ActivityCardHelper {
  static IconData activityIcon(String type) {
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

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ============================================================
// Mini Route Painter — lightweight route thumbnail for cards
// ============================================================

class _MiniRoutePainter extends CustomPainter {
  final List<GpsPoint> points;
  _MiniRoutePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final lats = points.map((p) => p.latitude).toList();
    final lngs = points.map((p) => p.longitude).toList();
    final minLat = lats.reduce(math.min);
    final maxLat = lats.reduce(math.max);
    final minLng = lngs.reduce(math.min);
    final maxLng = lngs.reduce(math.max);

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    final range = math.max(latRange, lngRange);
    if (range == 0) return;

    final padding = size.width * 0.12;
    final drawW = size.width - padding * 2;
    final drawH = size.height - padding * 2;

    Offset project(GpsPoint p) {
      final x = padding + ((p.longitude - minLng) / range) * drawW;
      final y = padding + ((maxLat - p.latitude) / range) * drawH;
      return Offset(x, y);
    }

    // Glow
    final glowPaint = Paint()
      ..color = AppTheme.electricLime.withValues(alpha: 0.25)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Main
    final mainPaint = Paint()
      ..color = AppTheme.electricLime.withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final first = project(points.first);
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i < points.length; i++) {
      final pt = project(points[i]);
      path.lineTo(pt.dx, pt.dy);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, mainPaint);

    // Start dot
    canvas.drawCircle(
        first, 3.0, Paint()..color = AppTheme.success);
    // End dot
    final last = project(points.last);
    canvas.drawCircle(
        last, 3.0, Paint()..color = AppTheme.error);
  }

  @override
  bool shouldRepaint(_MiniRoutePainter old) =>
      old.points.length != points.length;
}

// ============================================================
// Workout Detail Bottom Sheet
// ============================================================

void _showWorkoutDetail(BuildContext context, PlannedWorkout workout) {
  final color = _workoutDetailColor(workout.workoutType);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.35,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_workoutDetailIcon(workout.workoutType),
                      color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.workoutType.split('_').map((w) =>
                            w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
                            .join(' '),
                        style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _workoutDetailDate(workout.plannedDate),
                        style: TextStyle(color: color, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (workout.isCompleted)
                  const Icon(Icons.check_circle_rounded, color: AppTheme.success),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.surfaceLight),
              ),
              child: Text(workout.description,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 15, height: 1.6)),
            ),
            if (workout.targetDistanceMeters != null ||
                workout.targetDurationMinutes != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (workout.formattedTargetDistance != null)
                    Expanded(
                      child: _WorkoutDetailStat(
                        icon: Icons.straighten_rounded,
                        label: 'Distance',
                        value: workout.formattedTargetDistance!,
                      ),
                    ),
                  if (workout.formattedTargetDistance != null &&
                      workout.formattedTargetDuration != null)
                    const SizedBox(width: 12),
                  if (workout.formattedTargetDuration != null)
                    Expanded(
                      child: _WorkoutDetailStat(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: workout.formattedTargetDuration!,
                      ),
                    ),
                ],
              ),
            ],
            if (workout.coachingRationale != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.electricLime.withValues(alpha: 0.08),
                      AppTheme.electricLime.withValues(alpha: 0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.electricLime.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology_alt_rounded,
                            size: 18, color: AppTheme.electricLime),
                        SizedBox(width: 8),
                        Text("Coach's Rationale",
                            style: TextStyle(
                                color: AppTheme.electricLime,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(workout.coachingRationale!,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                            height: 1.5,
                            fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

Color _workoutDetailColor(String type) {
  switch (type) {
    case 'easy': return AppTheme.success;
    case 'tempo': return AppTheme.warning;
    case 'intervals': return AppTheme.heartRate;
    case 'long_run': return AppTheme.distance;
    case 'recovery': return AppTheme.info;
    case 'race': return AppTheme.electricLime;
    default: return AppTheme.electricLime;
  }
}

IconData _workoutDetailIcon(String type) {
  switch (type) {
    case 'easy': return Icons.self_improvement_rounded;
    case 'tempo': return Icons.speed_rounded;
    case 'intervals': return Icons.flash_on_rounded;
    case 'long_run': return Icons.route_rounded;
    case 'recovery': return Icons.healing_rounded;
    case 'race': return Icons.emoji_events_rounded;
    default: return Icons.fitness_center_rounded;
  }
}

String _workoutDetailDate(DateTime date) {
  final now = DateTime.now();
  final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 0) return 'In $diff days';
  return '${-diff} days ago';
}

class _WorkoutDetailStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _WorkoutDetailStat({
    required this.icon, required this.label, required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 18),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(
              color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ============================================================
// Quick Actions Row
// ============================================================

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onFormAnalysis;
  const _QuickActionsRow({required this.onFormAnalysis});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuickActionCard(
          icon: Icons.camera_alt_rounded,
          label: 'Form\nAnalysis',
          description: 'AI-powered biomechanics feedback',
          color: AppTheme.info,
          onTap: onFormAnalysis,
        ),
        const SizedBox(height: 10),
        _QuickActionCard(
          icon: Icons.bar_chart_rounded,
          label: 'Activity\nDashboard',
          description: 'Steps, calories & daily activity',
          color: AppTheme.electricLime,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActivityDashboardScreen()),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard({
    required this.icon, required this.label,
    required this.description,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.12),
                color.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.replaceAll('\n', ' '),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: color, size: 16),
            ],
          ),
        ),
      ),
    );
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
    var iconColor = _workoutColor(workout.workoutType);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: iconColor.withValues(alpha: 0.2)),
            ),
            child: Icon(
              _workoutIcon(workout.workoutType),
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatWorkoutTitle(workout.workoutType),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  workout.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (workout.formattedTargetDistance != null)
             Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.electricLime.withValues(alpha: 0.3)),
              ),
              child: Text(
                workout.formattedTargetDistance!,
                style: const TextStyle(
                  color: AppTheme.electricLime,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatWorkoutTitle(String type) {
    return type.split('_').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: AppTheme.electricLime,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.electricLime.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} // Correctly closes class _EmptyStateCard

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
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
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: AppTheme.electricLime,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

/// Today's Steps compact card for the home dashboard
class _TodayStepsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayActivityProvider);
    final snapshot = ref.watch(todayActivitySnapshotProvider);
    final today = todayAsync.valueOrNull ?? snapshot;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActivityDashboardScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.electricLime.withValues(alpha: 0.08),
              AppTheme.cardBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.electricLime.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // Progress ring
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: today.goalProgress,
                    strokeWidth: 6,
                    backgroundColor: AppTheme.surfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      today.goalReached
                          ? AppTheme.success
                          : AppTheme.electricLime,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                  Icon(
                    Icons.directions_walk_rounded,
                    color: today.goalReached
                        ? AppTheme.success
                        : AppTheme.electricLime,
                    size: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Steps',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${today.steps}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                      ),
                      Text(
                        ' / ${today.stepGoal}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${today.formattedCalories} cal · ${today.formattedDistance}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
