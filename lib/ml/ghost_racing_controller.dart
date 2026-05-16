import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'agent_service.dart';
import 'ml_providers.dart';
import '../domain/models/activity.dart';
import '../domain/models/tracking_metrics.dart';
import '../presentation/providers/tracking_provider.dart';

final selectedGhostActivityProvider = StateProvider<Activity?>((ref) => null);

final ghostRacingControllerProvider = StateNotifierProvider<GhostRacingController, GhostStatusResponse?>((ref) {
  return GhostRacingController(ref);
});

class GhostRacingController extends StateNotifier<GhostStatusResponse?> {
  final Ref _ref;
  Timer? _syncTimer;
  bool _isSyncing = false;
  List<ActivityPoint>? _cachedGhostStream;
  String? _cachedGhostId;

  GhostRacingController(this._ref) : super(null) {
    _ref.listen<TrackingControllerState>(trackingControllerProvider, (prev, next) {
      if (next.trackingState == TrackingState.tracking) {
        _startSync();
      } else {
        _stopSync();
      }
    });
  }

  void _startSync() {
    if (_syncTimer != null) return;
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) => _syncGhost());
  }

  void _stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void clearGhost() {
    _ref.read(selectedGhostActivityProvider.notifier).state = null;
    state = null;
    _cachedGhostStream = null;
    _cachedGhostId = null;
  }

  Future<void> _syncGhost() async {
    if (_isSyncing) return;
    
    final selectedGhost = _ref.read(selectedGhostActivityProvider);
    if (selectedGhost == null) {
      state = null;
      return;
    }

    final metrics = _ref.read(trackingMetricsProvider).valueOrNull;
    if (metrics == null || metrics.durationSeconds == 0) return;

    _isSyncing = true;
    try {
      if (_cachedGhostId != selectedGhost.id || _cachedGhostStream == null) {
        _cachedGhostStream = _buildGhostStream(selectedGhost);
        _cachedGhostId = selectedGhost.id;
      }

      if (_cachedGhostStream!.isEmpty) return;

      final request = GhostMatchRequest(
        userElapsedS: metrics.durationSeconds,
        userDistM: metrics.distanceMeters,
        ghostStream: _cachedGhostStream!,
      );

      final agentService = _ref.read(agentServiceProvider);
      final response = await agentService.syncGhost(request);
      
      if (mounted && response != null) {
        state = response;
      }
    } catch (e) {
      // Ignore network failures, keep last state
    } finally {
      _isSyncing = false;
    }
  }

  List<ActivityPoint> _buildGhostStream(Activity activity) {
    final stream = <ActivityPoint>[];
    double cumulativeDistance = 0.0;
    
    if (activity.rawGpsPoints.isEmpty) return stream;

    for (int i = 0; i < activity.rawGpsPoints.length; i++) {
      final p = activity.rawGpsPoints[i];
      final timeS = p.timestamp.difference(activity.rawGpsPoints.first.timestamp).inSeconds;
      
      if (i > 0) {
        final prev = activity.rawGpsPoints[i - 1];
        cumulativeDistance += Geolocator.distanceBetween(
          prev.latitude, prev.longitude,
          p.latitude, p.longitude,
        );
      }

      stream.add(ActivityPoint(
        timeS: timeS < 0 ? 0 : timeS,
        distM: cumulativeDistance,
        lat: p.latitude,
        lng: p.longitude,
      ));
    }
    return stream;
  }
}
