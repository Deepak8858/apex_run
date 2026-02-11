import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/gps_utils.dart';
import '../../domain/models/activity.dart';
import '../widgets/route_map_widget.dart';
import '../widgets/activity_charts.dart';
import '../providers/app_providers.dart';

/// Activity Detail Screen — Phase 4e
///
/// Full-screen view of a completed activity with:
/// - Mapbox route map (or fallback painter)
/// - Pace / Elevation charts
/// - Segment effort highlights
/// - Key metrics summary
/// - Share action
class ActivityDetailScreen extends ConsumerWidget {
  final Activity activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasGps = activity.rawGpsPoints.length >= 2;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsible app bar with map
          SliverAppBar(
            expandedHeight: hasGps ? 300 : 120,
            pinned: true,
            backgroundColor: AppTheme.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded),
                onPressed: () => _shareActivity(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppTheme.error,
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: hasGps
                  ? RouteMapWidget(
                      routePoints: activity.rawGpsPoints,
                      isLiveTracking: false,
                      showStartEndMarkers: true,
                      animateRoute: true,
                      padding: const EdgeInsets.all(60),
                    )
                  : Container(
                      color: AppTheme.cardBackground,
                      child: Center(
                        child: Icon(
                          Icons.route_rounded,
                          size: 48,
                          color: AppTheme.textTertiary.withOpacity(0.3),
                        ),
                      ),
                    ),
            ),
          ),

          // Activity content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & date
                  Text(
                    activity.activityName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _activityIcon(activity.activityType),
                        size: 16,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatFullDate(activity.startTime),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (activity.isPrivate) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.lock_rounded,
                            size: 14, color: AppTheme.textTertiary),
                      ],
                    ],
                  ),
                  if (activity.description != null &&
                      activity.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      activity.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Key metrics grid
                  _MetricsGrid(activity: activity),

                  const SizedBox(height: 24),

                  // Pace chart
                  if (hasGps) ...[
                    _SectionLabel(label: 'Pace'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.surfaceLight.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: PaceChartWidget(
                        points: activity.rawGpsPoints,
                        height: 120,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Elevation chart
                    _SectionLabel(label: 'Elevation'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.surfaceLight.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevationChartWidget(
                        points: activity.rawGpsPoints,
                        height: 80,
                      ),
                    ),
                  ],

                  // Split times
                  if (hasGps) ...[
                    const SizedBox(height: 24),
                    _SectionLabel(label: 'Splits'),
                    const SizedBox(height: 8),
                    _SplitTimesWidget(points: activity.rawGpsPoints),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
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

  String _formatFullDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final d = days[date.weekday - 1];
    final m = months[date.month - 1];
    final hour = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d, ${date.day} $m ${date.year} at $hour:$min';
  }

  void _shareActivity(BuildContext context) {
    // Placeholder for share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share coming in a future update'),
        backgroundColor: AppTheme.info,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Delete Activity?'),
        content: const Text(
            'This will permanently remove this activity and all associated data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (activity.id != null) {
                try {
                  final ds = ref.read(
                    activityDataSourceForDetailProvider,
                  );
                  await ds.deleteActivity(activity.id!);
                  ref.invalidate(recentActivitiesProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Metrics Grid
// ============================================================

class _MetricsGrid extends StatelessWidget {
  final Activity activity;
  const _MetricsGrid({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceLight.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _MetricTile(
                icon: Icons.straighten_rounded,
                label: 'Distance',
                value: activity.formattedDistance,
                color: AppTheme.distance,
              )),
              Expanded(
                  child: _MetricTile(
                icon: Icons.timer_rounded,
                label: 'Duration',
                value: activity.formattedDuration,
                color: AppTheme.electricLime,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _MetricTile(
                icon: Icons.speed_rounded,
                label: 'Avg Pace',
                value: activity.formattedPace,
                color: AppTheme.pace,
              )),
              Expanded(
                  child: _MetricTile(
                icon: Icons.flash_on_rounded,
                label: 'Max Speed',
                value: activity.maxSpeedKmh != null
                    ? '${activity.maxSpeedKmh!.toStringAsFixed(1)} km/h'
                    : '--',
                color: AppTheme.warning,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _MetricTile(
                icon: Icons.trending_up_rounded,
                label: 'Elev Gain',
                value: activity.elevationGainMeters != null
                    ? '${activity.elevationGainMeters!.toStringAsFixed(0)} m'
                    : '--',
                color: AppTheme.elevation,
              )),
              Expanded(
                  child: _MetricTile(
                icon: Icons.trending_down_rounded,
                label: 'Elev Loss',
                value: activity.elevationLossMeters != null
                    ? '${activity.elevationLossMeters!.toStringAsFixed(0)} m'
                    : '--',
                color: AppTheme.elevation,
              )),
            ],
          ),
          if (activity.avgHeartRate != null || activity.maxHeartRate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _MetricTile(
                  icon: Icons.favorite_rounded,
                  label: 'Avg HR',
                  value: activity.avgHeartRate != null
                      ? '${activity.avgHeartRate} bpm'
                      : '--',
                  color: AppTheme.heartRate,
                )),
                Expanded(
                    child: _MetricTile(
                  icon: Icons.favorite_border_rounded,
                  label: 'Max HR',
                  value: activity.maxHeartRate != null
                      ? '${activity.maxHeartRate} bpm'
                      : '--',
                  color: AppTheme.heartRate,
                )),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Split Times
// ============================================================

class _SplitTimesWidget extends StatelessWidget {
  final List points;
  const _SplitTimesWidget({required this.points});

  @override
  Widget build(BuildContext context) {
    final splits = _calculateKmSplits();
    if (splits.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceLight.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text('km',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppTheme.textTertiary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Pace',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppTheme.textTertiary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Elev',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppTheme.textTertiary),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.surfaceLight, height: 1),
          ...splits.asMap().entries.map((entry) {
            final i = entry.key;
            final split = entry.value;
            return Container(
              color: i.isEven
                  ? Colors.transparent
                  : AppTheme.surfaceLight.withOpacity(0.05),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${i + 1}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      split.formattedPace,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.pace,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${split.elevChange >= 0 ? '+' : ''}${split.elevChange.toStringAsFixed(0)}m',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: split.elevChange >= 0
                                ? AppTheme.elevation
                                : AppTheme.info,
                          ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<_KmSplit> _calculateKmSplits() {
    if (points.length < 2) return [];

    final splits = <_KmSplit>[];
    double cumDist = 0;
    int splitStartIdx = 0;
    double splitStartDist = 0;

    for (int i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      cumDist += GpsUtils.haversineDistance(a, b);

      final kmCompleted = ((cumDist - splitStartDist) / 1000).floor();
      if (kmCompleted >= 1) {
        final splitDuration = b.timestamp
            .difference(points[splitStartIdx].timestamp)
            .inSeconds;
        final splitElev = b.altitude - points[splitStartIdx].altitude;
        final pace = GpsUtils.calculatePace(1000, splitDuration);

        splits.add(_KmSplit(
          paceMinPerKm: pace,
          elevChange: splitElev,
        ));

        splitStartIdx = i;
        splitStartDist = cumDist;
      }
    }

    return splits;
  }
}

class _KmSplit {
  final double paceMinPerKm;
  final double elevChange;

  _KmSplit({required this.paceMinPerKm, required this.elevChange});

  String get formattedPace {
    if (paceMinPerKm <= 0 || paceMinPerKm.isInfinite) return '--:--';
    final totalSec = (paceMinPerKm * 60).round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.electricLime,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
