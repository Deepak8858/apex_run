import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/models/tracking_metrics.dart';

/// Speaks mid-run cues: per-km splits, pace deviation, halfway/finish.
///
/// Uses on-device TTS (offline, free). For premium voice quality the
/// Pro tier can swap to ElevenLabs conversational AI — keep the public
/// surface (`speak`, `announceSplit`, `announceStart`, `announceStop`)
/// identical so callers don't change.
class AudioCoachService {
  AudioCoachService();

  final FlutterTts _tts = FlutterTts();
  final _log = AppLogger.tag('AudioCoach');

  bool _initialized = false;
  bool _enabled = true;
  int _lastSpokenKm = -1;
  DateTime? _lastSpokeAt;

  /// Distance unit. `'km'` or `'mi'` — caller pulls from user profile.
  String _distanceUnit = 'km';

  Future<void> init({String distanceUnit = 'km'}) async {
    if (_initialized) return;
    _distanceUnit = distanceUnit;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(0.9);
      await _tts.setPitch(1.0);
      // iOS: duck other audio rather than pause Spotify outright.
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
      _initialized = true;
    } catch (e, st) {
      _log.w('TTS init failed', error: e, stackTrace: st);
    }
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) _tts.stop();
  }

  void setDistanceUnit(String unit) {
    _distanceUnit = unit;
  }

  Future<void> speak(String text) async {
    if (!_enabled || !_initialized) return;
    // Throttle: ignore identical cue within 5 seconds.
    if (_lastSpokeAt != null &&
        DateTime.now().difference(_lastSpokeAt!).inSeconds < 5) {
      return;
    }
    _lastSpokeAt = DateTime.now();
    try {
      await _tts.speak(text);
    } catch (e) {
      _log.w('TTS speak failed', error: e);
    }
  }

  /// Reset per-session counters at the start of a new run.
  void resetForNewSession() {
    _lastSpokenKm = -1;
    _lastSpokeAt = null;
  }

  Future<void> announceStart() => speak('Run started. Have a great workout.');

  Future<void> announcePause() => speak('Paused.');

  Future<void> announceResume() => speak('Resumed.');

  Future<void> announceStop(TrackingMetrics finalMetrics) {
    final dist = _formatDistance(finalMetrics.distanceMeters);
    final pace = _formatPace(finalMetrics.currentPaceMinPerKm);
    final mins = (finalMetrics.durationSeconds / 60).round();
    return speak('Run complete. $dist in $mins minutes. Average pace $pace.');
  }

  /// Call on every metrics tick; speaks only when crossing whole km/mile.
  Future<void> maybeAnnounceSplit(TrackingMetrics m) async {
    final unitDist = _distanceUnit == 'mi'
        ? m.distanceMeters / 1609.344
        : m.distanceMeters / 1000.0;
    final wholeUnit = unitDist.floor();
    if (wholeUnit <= _lastSpokenKm) return;
    if (wholeUnit < 1) return;
    _lastSpokenKm = wholeUnit;

    final unitName = _distanceUnit == 'mi' ? 'mile' : 'kilometer';
    final pluralSuffix = wholeUnit > 1 ? 's' : '';
    final pace = _formatPace(m.currentPaceMinPerKm);
    await speak('$wholeUnit $unitName$pluralSuffix. Average pace $pace.');
  }

  Future<void> announcePaceTarget({
    required double currentPaceMinPerKm,
    required double targetPaceMinPerKm,
  }) async {
    final delta = currentPaceMinPerKm - targetPaceMinPerKm;
    if (delta.abs() < 0.15) return; // within ±9s/km of target, stay quiet
    final msg = delta > 0
        ? 'Pick up the pace. ${(delta * 60).round()} seconds behind target.'
        : 'Ease off slightly. ${(-delta * 60).round()} seconds ahead of target.';
    await speak(msg);
  }

  String _formatDistance(double meters) {
    if (_distanceUnit == 'mi') {
      final mi = meters / 1609.344;
      return '${mi.toStringAsFixed(2)} miles';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(2)} kilometers';
  }

  String _formatPace(double? paceMinPerKm) {
    if (paceMinPerKm == null || paceMinPerKm.isNaN || paceMinPerKm.isInfinite) {
      return 'unknown';
    }
    final pace = _distanceUnit == 'mi' ? paceMinPerKm * 1.609344 : paceMinPerKm;
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    final unit = _distanceUnit == 'mi' ? 'mile' : 'kilometer';
    return '$minutes minutes $seconds seconds per $unit';
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
