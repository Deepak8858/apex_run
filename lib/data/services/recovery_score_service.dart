import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/models/activity.dart';

/// Recovery score 0-100. Computed from:
///   * HRV (RMSSD) — primary signal
///   * Sleep duration last night
///   * Acute:Chronic Workload Ratio (ACWR) — 7-day load / 28-day load
///
/// Algorithm is intentionally simple + transparent. Pro tier can later swap
/// to a learned model. All inputs are optional — missing values count as
/// "neutral" rather than penalizing the score.
class RecoveryScoreService {
  RecoveryScoreService(this._supabase);

  final SupabaseClient _supabase;
  final _log = AppLogger.tag('Recovery');

  /// Compute and persist today's score. Returns the computed `RecoveryScore`.
  Future<RecoveryScore> computeAndPersist({
    double? hrvMs,
    double? hrvBaselineMs,
    double? sleepHours,
    required List<Activity> last28Days,
  }) async {
    final score = compute(
      hrvMs: hrvMs,
      hrvBaselineMs: hrvBaselineMs,
      sleepHours: sleepHours,
      last28Days: last28Days,
    );

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final date = DateTime.now();
        await _supabase.from('recovery_scores').upsert({
          'user_id': user.id,
          'date':
              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'score': score.score,
          'hrv_ms': hrvMs,
          'sleep_hours': sleepHours,
          'load_acwr': score.acwr,
          'notes': score.recommendation,
        }, onConflict: 'user_id,date');
      } catch (e, st) {
        _log.w('Persist recovery score failed', error: e, stackTrace: st);
      }
    }
    return score;
  }

  RecoveryScore compute({
    double? hrvMs,
    double? hrvBaselineMs,
    double? sleepHours,
    required List<Activity> last28Days,
  }) {
    // ── HRV component (40% weight) ──────────────────────────────────
    double hrvPoints = 28; // neutral when no data
    if (hrvMs != null && hrvBaselineMs != null && hrvBaselineMs > 0) {
      final ratio = (hrvMs / hrvBaselineMs).clamp(0.5, 1.5);
      // 0.5×baseline → 0 pts, 1.0×baseline → 28 pts, 1.5×baseline → 40 pts
      hrvPoints = ((ratio - 0.5) / 1.0) * 40;
    }

    // ── Sleep component (30% weight) ────────────────────────────────
    double sleepPoints = 21; // neutral when no data
    if (sleepHours != null) {
      if (sleepHours >= 8) {
        sleepPoints = 30;
      } else if (sleepHours >= 7) {
        sleepPoints = 27;
      } else if (sleepHours >= 6) {
        sleepPoints = 18;
      } else if (sleepHours >= 5) {
        sleepPoints = 10;
      } else {
        sleepPoints = 4;
      }
    }

    // ── Load component (30% weight) — ACWR sweet spot 0.8 - 1.3 ─────
    final now = DateTime.now();
    final last7 = last28Days.where((a) =>
        a.startTime.isAfter(now.subtract(const Duration(days: 7))));
    final dist7 = last7.fold<double>(0, (s, a) => s + a.distanceMeters);
    final dist28 = last28Days.fold<double>(0, (s, a) => s + a.distanceMeters);
    final acuteWeekly = dist7;
    final chronicWeekly = dist28 / 4;
    final acwr = chronicWeekly > 0 ? acuteWeekly / chronicWeekly : 1.0;

    double loadPoints;
    if (acwr.isNaN || acwr.isInfinite) {
      loadPoints = 21;
    } else if (acwr <= 0.5) {
      loadPoints = 18; // detraining
    } else if (acwr < 0.8) {
      loadPoints = 25;
    } else if (acwr <= 1.3) {
      loadPoints = 30; // sweet spot
    } else if (acwr <= 1.5) {
      loadPoints = 22;
    } else {
      loadPoints = 10; // injury risk
    }

    final raw = hrvPoints + sleepPoints + loadPoints;
    final score = raw.clamp(0, 100).round();

    return RecoveryScore(
      score: score,
      hrvMs: hrvMs,
      sleepHours: sleepHours,
      acwr: acwr.isFinite ? acwr : null,
      recommendation: _recommendation(score, acwr),
    );
  }

  String _recommendation(int score, double acwr) {
    if (score >= 80) return 'Fresh. Quality session encouraged.';
    if (score >= 65) return 'Good to go. Moderate effort recommended.';
    if (score >= 50) return 'Light to moderate effort. Listen to your body.';
    if (acwr.isFinite && acwr > 1.5) {
      return 'Overload risk. Easy or rest day strongly suggested.';
    }
    return 'Recover. Easy walk, sleep, hydrate.';
  }

  /// Latest persisted score for today (or null).
  Future<RecoveryScore?> latestForToday() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final today = DateTime.now();
    final dateStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    try {
      final row = await _supabase
          .from('recovery_scores')
          .select()
          .eq('user_id', user.id)
          .eq('date', dateStr)
          .maybeSingle();
      if (row == null) return null;
      return RecoveryScore(
        score: row['score'] as int,
        hrvMs: (row['hrv_ms'] as num?)?.toDouble(),
        sleepHours: (row['sleep_hours'] as num?)?.toDouble(),
        acwr: (row['load_acwr'] as num?)?.toDouble(),
        recommendation: row['notes'] as String? ?? '',
      );
    } catch (e, st) {
      _log.w('Latest recovery fetch failed', error: e, stackTrace: st);
      return null;
    }
  }
}

class RecoveryScore {
  const RecoveryScore({
    required this.score,
    required this.recommendation,
    this.hrvMs,
    this.sleepHours,
    this.acwr,
  });

  final int score;
  final String recommendation;
  final double? hrvMs;
  final double? sleepHours;
  final double? acwr;

  String get band {
    if (score >= 80) return 'Primed';
    if (score >= 65) return 'Ready';
    if (score >= 50) return 'OK';
    if (score >= 35) return 'Tired';
    return 'Recover';
  }

  /// Returns a hue between 0 (red) and 120 (green) mapped from score.
  double get hue => math.min(120, math.max(0, score * 1.2));
}
