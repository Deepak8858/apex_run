import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/permission_utils.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/tracking_metrics.dart';
import '../providers/app_providers.dart';
import '../providers/tracking_provider.dart';
import '../widgets/route_map_widget.dart';
import 'activity_detail_screen.dart';

/// Record Screen - Strava-inspired GPS Activity Tracking
///
/// Features:
/// - Full-screen map with route overlay
/// - Large central timer display
/// - Swipeable metric panels
/// - Activity type selector
/// - GPS signal indicator
/// - Hold-to-finish gesture
/// - Lock screen button
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen>
    with TickerProviderStateMixin {
  final TextEditingController _activityNameController = TextEditingController(
    text: 'Morning Run',
  );

  late AnimationController _pulseController;
  late AnimationController _startButtonController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _startButtonScale;

  int _selectedActivityType = 0;
  final List<_ActivityType> _activityTypes = const [
    _ActivityType('Run', Icons.directions_run_rounded),
    _ActivityType('Walk', Icons.directions_walk_rounded),
    _ActivityType('Cycle', Icons.directions_bike_rounded),
    _ActivityType('Hike', Icons.terrain_rounded),
  ];

  bool _isLocked = false;
  int _currentMetricPage = 0;
  final PageController _metricPageController = PageController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _startButtonScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _startButtonController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _activityNameController.dispose();
    _pulseController.dispose();
    _startButtonController.dispose();
    _metricPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(trackingControllerProvider);
    final metrics = ref.watch(trackingMetricsProvider);

    ref.listen<TrackingControllerState>(trackingControllerProvider, (
      prev,
      next,
    ) {
      // ── Audio coach state transitions ───────────────────────────────
      final coach = ref.read(audioCoachServiceProvider);
      final prevState = prev?.trackingState;
      final nextState = next.trackingState;
      if (prevState != nextState) {
        switch (nextState) {
          case TrackingState.tracking:
            if (prevState == null || prevState == TrackingState.idle) {
              coach.resetForNewSession();
              coach.announceStart();
              HapticFeedback.heavyImpact();
            } else if (prevState == TrackingState.paused) {
              coach.announceResume();
              HapticFeedback.lightImpact();
            }
            break;
          case TrackingState.paused:
            coach.announcePause();
            HapticFeedback.mediumImpact();
            break;
          case TrackingState.idle:
            break;
        }
      }

      if (next.lastSavedActivity != null && prev?.lastSavedActivity == null) {
        HapticFeedback.heavyImpact();
        _showActivitySavedSheet(context, next);
      }
      if (next.errorMessage != null && prev?.errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    });

    // Per-km / per-mile split announcer. Fires on every metric tick but
    // [AudioCoachService.maybeAnnounceSplit] gates by whole-unit crossings.
    ref.listen<AsyncValue<TrackingMetrics>>(trackingMetricsProvider, (
      prev,
      next,
    ) {
      final m = next.valueOrNull;
      if (m == null) return;
      if (m.state == TrackingState.tracking) {
        ref.read(audioCoachServiceProvider).maybeAnnounceSplit(m);
      }
    });

    final isIdle = controllerState.trackingState == TrackingState.idle;
    final isSaving = controllerState.isSaving;

    if (isSaving) return _buildSavingView(context);
    if (isIdle) return _buildIdleView(context);
    return _buildTrackingView(context, controllerState, metrics);
  }

  // ============================================================
  // IDLE / PRE-TRACKING VIEW
  // ============================================================
  Widget _buildIdleView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Record',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  const _GpsSignalIndicator(),
                ],
              ),
            ),
            // Activity type selector
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _activityTypes.length,
                separatorBuilder: (_, i) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final type = _activityTypes[index];
                  final isSelected = index == _selectedActivityType;
                  return _ActivityTypeChip(
                    label: type.name,
                    icon: type.icon,
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedActivityType = index),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Activity name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _activityNameController,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: const InputDecoration(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppTheme.textTertiary,
                    ),
                    hintText: 'Name your activity',
                    hintStyle: TextStyle(color: AppTheme.textTertiary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const Spacer(),
            _buildStartButton(context),
            const SizedBox(height: 16),
            Text(
              'Tap to start ${_activityTypes[_selectedActivityType].name.toLowerCase()}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startButtonController.forward(),
      onTapUp: (_) {
        _startButtonController.reverse();
        HapticFeedback.mediumImpact();
        _handleStartTracking(context);
      },
      onTapCancel: () => _startButtonController.reverse(),
      child: AnimatedBuilder(
        animation: _startButtonScale,
        builder: (context, child) =>
            Transform.scale(scale: _startButtonScale.value, child: child),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ring
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) => Container(
                width: 160 * _pulseAnimation.value,
                height: 160 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.electricLime.withValues(
                      alpha: 0.12 * (1.0 - _pulseAnimation.value + 0.5),
                    ),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Main button
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.electricLime,
                    AppTheme.electricLime.withValues(alpha: 0.85),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.electricLime.withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 48,
                    color: AppTheme.background,
                  ),
                  Text(
                    'START',
                    style: TextStyle(
                      color: AppTheme.background,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TRACKING VIEW
  // ============================================================
  Widget _buildTrackingView(
    BuildContext context,
    TrackingControllerState controllerState,
    AsyncValue<TrackingMetrics> metricsAsync,
  ) {
    final isPaused = controllerState.trackingState == TrackingState.paused;
    final metrics = metricsAsync.valueOrNull ?? const TrackingMetrics();

    if (_isLocked) return _buildLockedView(context, metrics, isPaused);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Full-screen map
          Positioned.fill(
            child: RouteMapWidget(
              routePoints: metrics.routePoints,
              isLiveTracking: true,
              padding: const EdgeInsets.only(
                top: 80,
                bottom: 380,
                left: 40,
                right: 40,
              ),
            ),
          ),
          // Bottom gradient overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.55,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.background.withValues(alpha: 0.6),
                    AppTheme.background.withValues(alpha: 0.95),
                    AppTheme.background,
                  ],
                  stops: const [0.0, 0.25, 0.5, 0.7],
                ),
              ),
            ),
          ),
          // Top status bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: (isPaused ? AppTheme.warning : AppTheme.success)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPaused
                                  ? AppTheme.warning
                                  : AppTheme.success,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPaused ? 'PAUSED' : 'REC',
                            style: TextStyle(
                              color: isPaused
                                  ? AppTheme.warning
                                  : AppTheme.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isLocked = true);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surfaceLight.withValues(alpha: 0.6),
                        ),
                        child: const Icon(
                          Icons.lock_open_rounded,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _GpsSignalIndicator(compact: true),
                  ],
                ),
              ),
            ),
          ),
          // Metrics overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: _buildMetricsOverlay(context, metrics, isPaused),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsOverlay(
    BuildContext context,
    TrackingMetrics metrics,
    bool isPaused,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Duration (hero metric)
        Text(
          metrics.formattedDuration,
          style: const TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w100,
            color: AppTheme.textPrimary,
            letterSpacing: 4,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Duration',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textTertiary,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        // Swipeable metric panels
        SizedBox(
          height: 88,
          child: PageView(
            controller: _metricPageController,
            onPageChanged: (i) => setState(() => _currentMetricPage = i),
            children: [
              _MetricRow(
                left: _MetricInfo(
                  'Distance',
                  metrics.formattedDistance,
                  metrics.distanceUnit,
                  AppTheme.distance,
                ),
                right: _MetricInfo(
                  'Avg Pace',
                  metrics.formattedPace,
                  'min/km',
                  AppTheme.pace,
                ),
              ),
              _MetricRow(
                left: _MetricInfo(
                  'Speed',
                  metrics.currentSpeedKmh.toStringAsFixed(1),
                  'km/h',
                  AppTheme.elevation,
                ),
                right: _MetricInfo(
                  'GPS Points',
                  '${metrics.routePoints.length}',
                  'pts',
                  AppTheme.info,
                ),
              ),
            ],
          ),
        ),
        // Page dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            2,
            (i) => Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentMetricPage == i
                    ? AppTheme.electricLime
                    : AppTheme.surfaceLight,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildTrackingControls(context, isPaused),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTrackingControls(BuildContext context, bool isPaused) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: Icons.close_rounded,
            label: 'Discard',
            color: AppTheme.error,
            size: 52,
            onTap: () => _showDiscardConfirmation(context),
          ),
          _ControlButton(
            icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: isPaused ? 'Resume' : 'Pause',
            color: isPaused ? AppTheme.success : AppTheme.warning,
            size: 68,
            filled: true,
            onTap: () {
              HapticFeedback.mediumImpact();
              if (isPaused) {
                ref.read(trackingControllerProvider.notifier).resumeTracking();
              } else {
                ref.read(trackingControllerProvider.notifier).pauseTracking();
              }
            },
          ),
          _FinishButton(
            onFinish: () {
              HapticFeedback.heavyImpact();
              ref
                  .read(trackingControllerProvider.notifier)
                  .stopAndSaveTracking();
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOCKED VIEW
  // ============================================================
  Widget _buildLockedView(
    BuildContext context,
    TrackingMetrics metrics,
    bool isPaused,
  ) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: GestureDetector(
        onLongPress: () {
          HapticFeedback.heavyImpact();
          setState(() => _isLocked = false);
        },
        child: Container(
          color: Colors.transparent,
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Text(
                  metrics.formattedDuration,
                  style: TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.w100,
                    color: AppTheme.textPrimary.withValues(alpha: 0.9),
                    letterSpacing: 4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LockedMetric(
                      value: metrics.formattedDistance,
                      unit: metrics.distanceUnit,
                    ),
                    const SizedBox(width: 32),
                    _LockedMetric(value: metrics.formattedPace, unit: 'min/km'),
                  ],
                ),
                const Spacer(),
                const Icon(
                  Icons.lock_rounded,
                  size: 40,
                  color: AppTheme.textTertiary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Long press to unlock',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SAVING VIEW
  // ============================================================
  Widget _buildSavingView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                color: AppTheme.electricLime,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Saving activity...',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOGS & SHEETS
  // ============================================================
  void _showDiscardConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 24),
            SizedBox(width: 8),
            Text('Discard Activity?'),
          ],
        ),
        content: const Text(
          'All recorded data will be permanently deleted.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Recording'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(trackingControllerProvider.notifier).discardTracking();
            },
            child: const Text(
              'Discard',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartTracking(BuildContext context) async {
    final result = await ref
        .read(trackingControllerProvider.notifier)
        .startTracking();
    if (result == PermissionResult.granted) return;
    if (!context.mounted) return;

    final shouldRetry = await PermissionUtils.handlePermissionResult(
      context,
      result,
    );
    if (!context.mounted) return;
    if (shouldRetry) {
      final retryResult = await ref
          .read(trackingControllerProvider.notifier)
          .startTracking();
      if (!context.mounted) return;
      if (retryResult != PermissionResult.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Location permission is required to track your activity.',
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _showActivitySavedSheet(
    BuildContext context,
    TrackingControllerState state,
  ) {
    final activity = state.lastSavedActivity!;
    final unlocked = state.newlyUnlockedAchievements;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ActivitySavedSheet(
        activity: activity,
        newlyUnlocked: unlocked,
        onShare: () async {
          final reel = ref.read(highlightReelServiceProvider);
          try {
            await reel.share(activity);
          } catch (e) {
            if (!ctx.mounted) return;
            ScaffoldMessenger.of(
              ctx,
            ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
          }
        },
      ),
    );
  }
}

class _ActivitySavedSheet extends StatefulWidget {
  const _ActivitySavedSheet({
    required this.activity,
    required this.newlyUnlocked,
    required this.onShare,
  });

  final Activity activity;
  final List<String> newlyUnlocked;
  final Future<void> Function() onShare;

  @override
  State<_ActivitySavedSheet> createState() => _ActivitySavedSheetState();
}

class _ActivitySavedSheetState extends State<_ActivitySavedSheet> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    if (widget.newlyUnlocked.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final unlocked = widget.newlyUnlocked;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.success.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.success,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  unlocked.isEmpty
                      ? 'Activity Saved!'
                      : 'Activity Saved + ${unlocked.length} unlocked!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (unlocked.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: unlocked
                        .map(
                          (code) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.electricLime.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.electricLime.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Text(
                              code.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.electricLime,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _SavedStat(
                        label: 'Distance',
                        value: activity.formattedDistance,
                      ),
                    ),
                    Expanded(
                      child: _SavedStat(
                        label: 'Duration',
                        value: activity.formattedDuration,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _SavedStat(
                        label: 'Avg Pace',
                        value: activity.formattedPace,
                      ),
                    ),
                    Expanded(
                      child: activity.elevationGainMeters != null
                          ? _SavedStat(
                              label: 'Elevation',
                              value:
                                  '${activity.elevationGainMeters!.toStringAsFixed(0)}m',
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onShare,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.electricLime,
                          side: const BorderSide(color: AppTheme.electricLime),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ActivityDetailScreen(activity: activity),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.electricLime,
                          foregroundColor: AppTheme.background,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 24,
          maxBlastForce: 18,
          minBlastForce: 6,
          gravity: 0.4,
          colors: const [
            Color(0xFFCCFF00),
            Color(0xFFFFD166),
            Color(0xFFB8A4FF),
            Color(0xFF7AD3FF),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// Helper Widgets
// ============================================================

class _ActivityType {
  final String name;
  final IconData icon;
  const _ActivityType(this.name, this.icon);
}

class _ActivityTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _ActivityTypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.electricLime.withValues(alpha: 0.15)
              : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppTheme.electricLime : AppTheme.surfaceLight,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? AppTheme.electricLime
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.electricLime
                    : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsSignalIndicator extends StatelessWidget {
  final bool compact;
  const _GpsSignalIndicator({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.gps_fixed_rounded,
          size: compact ? 14 : 16,
          color: AppTheme.success,
        ),
        if (!compact) ...[
          const SizedBox(width: 4),
          const Text(
            'GPS',
            style: TextStyle(
              color: AppTheme.success,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricInfo {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _MetricInfo(this.label, this.value, this.unit, this.color);
}

class _MetricRow extends StatelessWidget {
  final _MetricInfo left;
  final _MetricInfo right;
  const _MetricRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _MetricTile(info: left)),
          Container(
            width: 1,
            height: 50,
            color: AppTheme.surfaceLight.withValues(alpha: 0.5),
          ),
          Expanded(child: _MetricTile(info: right)),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final _MetricInfo info;
  const _MetricTile({required this.info});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              info.value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: info.color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 3),
            Text(
              info.unit,
              style: TextStyle(
                fontSize: 12,
                color: info.color.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          info.label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textTertiary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final bool filled;
  final VoidCallback onTap;
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.size,
    this.filled = false,
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
              color: filled ? color : color.withValues(alpha: 0.12),
              border: filled ? null : Border.all(color: color, width: 2),
            ),
            child: Icon(
              icon,
              color: filled ? AppTheme.background : color,
              size: size * 0.45,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FinishButton extends StatefulWidget {
  final VoidCallback onFinish;
  const _FinishButton({required this.onFinish});

  @override
  State<_FinishButton> createState() => _FinishButtonState();
}

class _FinishButtonState extends State<_FinishButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _holdController;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinish();
        _holdController.reset();
        setState(() => _isHolding = false);
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onLongPressStart: (_) {
            HapticFeedback.lightImpact();
            setState(() => _isHolding = true);
            _holdController.forward();
          },
          onLongPressEnd: (_) {
            if (_holdController.status != AnimationStatus.completed) {
              _holdController.reverse();
              setState(() => _isHolding = false);
            }
          },
          onLongPressCancel: () {
            _holdController.reverse();
            setState(() => _isHolding = false);
          },
          child: AnimatedBuilder(
            animation: _holdController,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: _holdController.value,
                    color: AppTheme.electricLime,
                    backgroundColor: AppTheme.electricLime.withValues(
                      alpha: 0.15,
                    ),
                    strokeWidth: 3,
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isHolding
                        ? AppTheme.electricLime.withValues(alpha: 0.3)
                        : AppTheme.electricLime.withValues(alpha: 0.12),
                    border: Border.all(color: AppTheme.electricLime, width: 2),
                  ),
                  child: const Icon(
                    Icons.stop_rounded,
                    color: AppTheme.electricLime,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Hold to Finish',
          style: TextStyle(
            color: AppTheme.electricLime,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LockedMetric extends StatelessWidget {
  final String value;
  final String unit;
  const _LockedMetric({required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          unit,
          style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
        ),
      ],
    );
  }
}

class _SavedStat extends StatelessWidget {
  final String label;
  final String value;
  const _SavedStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.electricLime,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
