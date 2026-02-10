import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/permission_utils.dart';
import '../../domain/models/tracking_metrics.dart';
import '../providers/tracking_provider.dart';
import '../widgets/route_map_widget.dart';
import 'activity_detail_screen.dart';

/// Record Screen - GPS Activity Tracking
///
/// Live GPS tracking with:
/// - Real-time pace/distance/time display
/// - Start/Stop/Pause controls
/// - Activity summary on completion
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _activityNameController =
      TextEditingController(text: 'Morning Run');

  late AnimationController _mapAnimationController;
  late Animation<double> _mapHeightAnimation;
  late Animation<double> _mapOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _mapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _mapHeightAnimation = Tween<double>(begin: 0, end: 220).animate(
      CurvedAnimation(
        parent: _mapAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _mapOpacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mapAnimationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _activityNameController.dispose();
    _mapAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(trackingControllerProvider);
    final metrics = ref.watch(trackingMetricsProvider);

    ref.listen<TrackingControllerState>(trackingControllerProvider,
        (prev, next) {
      if (next.lastSavedActivity != null &&
          prev?.lastSavedActivity == null) {
        _showActivitySavedDialog(context, next);
      }
      if (next.errorMessage != null && prev?.errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    });

    final isTracking =
        controllerState.trackingState != TrackingState.idle;

    // Animate map in/out when tracking state changes
    if (isTracking && !_mapAnimationController.isCompleted) {
      _mapAnimationController.forward();
    } else if (!isTracking && _mapAnimationController.value > 0) {
      _mapAnimationController.reverse();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Activity'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Animated live route map (Phase 4a)
            AnimatedBuilder(
              animation: _mapAnimationController,
              builder: (context, child) {
                if (_mapHeightAnimation.value <= 0) {
                  return const SizedBox.shrink();
                }
                return Opacity(
                  opacity: _mapOpacityAnimation.value.clamp(0.0, 1.0),
                  child: SizedBox(
                    height: _mapHeightAnimation.value,
                    child: child,
                  ),
                );
              },
              child: metrics.when(
                data: (m) => RouteMapWidget(
                  routePoints: m.routePoints,
                  isLiveTracking: true,
                ),
                loading: () => const RouteMapWidget(
                  routePoints: [],
                  isLiveTracking: true,
                ),
                error: (_, __) => const RouteMapWidget(
                  routePoints: [],
                  isLiveTracking: true,
                ),
              ),
            ),
            Expanded(
              child: _buildMetricsDisplay(context, controllerState, metrics),
            ),
            _buildControls(context, controllerState),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsDisplay(
    BuildContext context,
    TrackingControllerState controllerState,
    AsyncValue<TrackingMetrics> metricsAsync,
  ) {
    final isIdle = controllerState.trackingState == TrackingState.idle;

    if (isIdle) {
      return _buildPreTrackingView(context);
    }

    return metricsAsync.when(
      data: (metrics) => _buildLiveMetrics(context, metrics, controllerState),
      loading: () => _buildLiveMetrics(
          context, const TrackingMetrics(), controllerState),
      error: (e, _) => Center(
        child: Text('Tracking error: $e',
            style: const TextStyle(color: AppTheme.error)),
      ),
    );
  }

  Widget _buildPreTrackingView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.electricLime.withOpacity(0.1),
                border: Border.all(
                  color: AppTheme.electricLime.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.directions_run_rounded,
                size: 60,
                color: AppTheme.electricLime,
              ),
            ),
            const SizedBox(height: 32),
            Text('Ready to Run?',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              'GPS tracking will record your route, distance, pace, and elevation in real-time.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _activityNameController,
              decoration: const InputDecoration(
                labelText: 'Activity Name',
                hintText: 'e.g. Morning Run',
                prefixIcon: Icon(Icons.edit_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMetrics(
    BuildContext context,
    TrackingMetrics metrics,
    TrackingControllerState controllerState,
  ) {
    final isPaused = controllerState.trackingState == TrackingState.paused;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPaused ? AppTheme.warning : AppTheme.success,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isPaused ? 'PAUSED' : 'RECORDING',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isPaused ? AppTheme.warning : AppTheme.success,
                      letterSpacing: 2,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Duration
          Text(
            metrics.formattedDuration,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 64,
                  fontWeight: FontWeight.w200,
                  color: AppTheme.textPrimary,
                  letterSpacing: 4,
                ),
          ),
          const SizedBox(height: 40),

          // Distance & Pace
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LiveMetricTile(
                value: metrics.formattedDistance,
                unit: metrics.distanceUnit,
                label: 'Distance',
                color: AppTheme.distance,
              ),
              Container(width: 1, height: 60, color: AppTheme.surfaceLight),
              _LiveMetricTile(
                value: metrics.formattedPace,
                unit: '/km',
                label: 'Pace',
                color: AppTheme.pace,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Speed & Points
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LiveMetricTile(
                value: metrics.currentSpeedKmh.toStringAsFixed(1),
                unit: 'km/h',
                label: 'Speed',
                color: AppTheme.elevation,
              ),
              Container(width: 1, height: 60, color: AppTheme.surfaceLight),
              _LiveMetricTile(
                value: '${metrics.routePoints.length}',
                unit: 'pts',
                label: 'GPS Points',
                color: AppTheme.info,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    TrackingControllerState controllerState,
  ) {
    final isIdle = controllerState.trackingState == TrackingState.idle;
    final isPaused = controllerState.trackingState == TrackingState.paused;
    final isSaving = controllerState.isSaving;

    if (isSaving) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(color: AppTheme.electricLime),
            SizedBox(height: 12),
            Text('Saving activity...'),
          ],
        ),
      );
    }

    if (isIdle) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _handleStartTracking(context),
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: const Text('Start Run'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CircularButton(
            icon: Icons.delete_outline_rounded,
            label: 'Discard',
            color: AppTheme.error,
            onTap: () => _showDiscardConfirmation(context),
          ),
          _CircularButton(
            icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: isPaused ? 'Resume' : 'Pause',
            color: AppTheme.warning,
            size: 72,
            onTap: () {
              if (isPaused) {
                ref.read(trackingControllerProvider.notifier).resumeTracking();
              } else {
                ref.read(trackingControllerProvider.notifier).pauseTracking();
              }
            },
          ),
          _CircularButton(
            icon: Icons.stop_rounded,
            label: 'Finish',
            color: AppTheme.electricLime,
            onTap: () => ref
                .read(trackingControllerProvider.notifier)
                .stopAndSaveTracking(),
          ),
        ],
      ),
    );
  }

  void _showDiscardConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Discard Activity?'),
        content: const Text(
            'This will stop tracking and discard all recorded data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(trackingControllerProvider.notifier).discardTracking();
            },
            child:
                const Text('Discard', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  /// Handle start tracking with proper permission popups
  Future<void> _handleStartTracking(BuildContext context) async {
    final result = await ref
        .read(trackingControllerProvider.notifier)
        .startTracking();

    if (result == PermissionResult.granted) return;
    if (!mounted) return;

    // Show the appropriate dialog based on the denial reason
    final shouldRetry =
        await PermissionUtils.handlePermissionResult(context, result);

    // If user chose to retry (e.g. after enabling settings), try again
    if (shouldRetry && mounted) {
      final retryResult = await ref
          .read(trackingControllerProvider.notifier)
          .startTracking();

      if (retryResult != PermissionResult.granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location permission is still required. Please try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showActivitySavedDialog(
    BuildContext context,
    TrackingControllerState state,
  ) {
    final activity = state.lastSavedActivity!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success),
            SizedBox(width: 8),
            Text('Activity Saved!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow('Distance', activity.formattedDistance),
            _SummaryRow('Duration', activity.formattedDuration),
            _SummaryRow('Avg Pace', activity.formattedPace),
            if (activity.elevationGainMeters != null)
              _SummaryRow('Elevation',
                  '${activity.elevationGainMeters!.toStringAsFixed(0)}m'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityDetailScreen(activity: activity),
                ),
              );
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Helper Widgets
// ============================================================

class _LiveMetricTile extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color color;
  const _LiveMetricTile({
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextSpan(
                text: ' $unit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color.withOpacity(0.7),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CircularButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _CircularButton({
    required this.icon,
    required this.label,
    required this.color,
    this.size = 56,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppTheme.electricLime)),
        ],
      ),
    );
  }
}
