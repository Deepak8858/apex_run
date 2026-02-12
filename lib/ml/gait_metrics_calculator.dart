import 'dart:math' as math;

/// GaitMetricsCalculator — Biomechanical Analysis Engine
///
/// Processes raw MediaPipe pose landmark data to extract running-specific
/// gait metrics. Uses the 33-landmark BlazePose model.
///
/// Key landmarks for running form analysis:
/// - 23/24: Left/Right Hip
/// - 25/26: Left/Right Knee
/// - 27/28: Left/Right Ankle
/// - 29/30: Left/Right Heel
/// - 31/32: Left/Right Foot Index (toe)
/// - 11/12: Left/Right Shoulder
/// - 13/14: Left/Right Elbow
/// - 15/16: Left/Right Wrist
/// - 0: Nose (for forward lean reference)
class GaitMetricsCalculator {
  // ── Landmark indices (BlazePose 33-point model) ──────────────────
  static const int nose = 0;
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
  static const int leftHeel = 29;
  static const int rightHeel = 30;
  static const int leftFootIndex = 31;
  static const int rightFootIndex = 32;

  final List<_PoseFrame> _frames = [];
  final List<double> _groundContactTimes = [];
  final List<double> _verticalOscillations = [];
  final List<double> _strideLengths = [];
  final List<int> _stepTimestamps = [];
  final List<double> _hipYHistory = [];

  // Track left/right foot contact separately for better step detection
  bool _leftFootDown = false;
  bool _rightFootDown = false;
  int _lastLeftContactMs = 0;
  int _lastRightContactMs = 0;

  /// Whether we have enough data to produce results
  bool get hasEnoughData => _frames.length >= 30; // ~1 second at 30fps

  /// Add a new pose frame from MediaPipe detection
  void addPoseFrame({
    required List<PoseLandmark> landmarks,
    required int timestampMs,
    required double confidence,
  }) {
    if (landmarks.length < 33 || confidence < 0.4) return;

    final frame = _PoseFrame(
      landmarks: landmarks,
      timestampMs: timestampMs,
      confidence: confidence,
    );

    _frames.add(frame);
    _processFrame(frame);

    // Keep a rolling window of ~5 seconds (150 frames at 30fps)
    if (_frames.length > 150) {
      _frames.removeAt(0);
    }
  }

  void _processFrame(_PoseFrame frame) {
    if (_frames.length < 3) return;

    final prev = _frames[_frames.length - 2];
    final prevPrev = _frames[_frames.length - 3];
    final curr = frame;

    // ── Detect ground contact events ──────────────────────────
    _detectGroundContact(prevPrev, prev, curr);

    // ── Track vertical oscillation ─────────────────────────
    _trackVerticalOscillation(curr);
  }

  /// Improved ground contact detection using velocity reversal
  /// with smoothing from 3 consecutive frames
  void _detectGroundContact(
      _PoseFrame prevPrev, _PoseFrame prev, _PoseFrame curr) {
    // Left foot: track ankle + heel Y positions
    final leftAnkleY = curr.landmarks[leftAnkle].y;
    final prevLeftAnkleY = prev.landmarks[leftAnkle].y;
    final ppLeftAnkleY = prevPrev.landmarks[leftAnkle].y;

    final rightAnkleY = curr.landmarks[rightAnkle].y;
    final prevRightAnkleY = prev.landmarks[rightAnkle].y;
    final ppRightAnkleY = prevPrev.landmarks[rightAnkle].y;

    // Velocity: positive = moving down (in image coords, down = higher Y)
    final leftVel1 = prevLeftAnkleY - ppLeftAnkleY;
    final leftVel2 = leftAnkleY - prevLeftAnkleY;

    final rightVel1 = prevRightAnkleY - ppRightAnkleY;
    final rightVel2 = rightAnkleY - prevRightAnkleY;

    // Ground contact = foot was moving down, then stopped or reversed
    // (velocity sign change from positive to near-zero/negative)
    final leftLanding = leftVel1 > 0.003 && leftVel2 < 0.002;
    final rightLanding = rightVel1 > 0.003 && rightVel2 < 0.002;

    if (leftLanding && !_leftFootDown) {
      _leftFootDown = true;
      _stepTimestamps.add(curr.timestampMs);
      if (_lastLeftContactMs > 0) {
        final contactDuration = curr.timestampMs - _lastLeftContactMs;
        if (contactDuration > 100 && contactDuration < 800) {
          _groundContactTimes.add(contactDuration.toDouble());
        }
      }
      _lastLeftContactMs = curr.timestampMs;
    }

    if (rightLanding && !_rightFootDown) {
      _rightFootDown = true;
      _stepTimestamps.add(curr.timestampMs);
      if (_lastRightContactMs > 0) {
        final contactDuration = curr.timestampMs - _lastRightContactMs;
        if (contactDuration > 100 && contactDuration < 800) {
          _groundContactTimes.add(contactDuration.toDouble());
        }
      }
      _lastRightContactMs = curr.timestampMs;
    }

    // Detect foot lift-off (ankle moving up fast)
    final leftLiftoff = leftVel2 < -0.005;
    final rightLiftoff = rightVel2 < -0.005;

    if (leftLiftoff) _leftFootDown = false;
    if (rightLiftoff) _rightFootDown = false;
  }

  /// Track vertical center-of-mass oscillation via hip midpoint
  void _trackVerticalOscillation(_PoseFrame frame) {
    final hipMidY = (frame.landmarks[leftHip].y +
            frame.landmarks[rightHip].y) /
        2;
    _hipYHistory.add(hipMidY);
    _verticalOscillations.add(hipMidY);

    // Keep history bounded
    if (_hipYHistory.length > 200) _hipYHistory.removeAt(0);
  }

  /// Calculate the average Ground Contact Time in milliseconds
  ///
  /// Uses step interval approach: GCT ≈ 60% of step interval for
  /// recreational runners, ~55% for competitive runners
  double calculateGroundContactTimeMs() {
    if (_stepTimestamps.length < 4) return 0;

    final intervals = <int>[];
    for (var i = 1; i < _stepTimestamps.length; i++) {
      final interval = _stepTimestamps[i] - _stepTimestamps[i - 1];
      // Filter unrealistic intervals (< 100ms or > 800ms per step)
      if (interval >= 100 && interval <= 800) {
        intervals.add(interval);
      }
    }

    if (intervals.isEmpty) return 0;

    // Remove outliers (> 2 SD from mean)
    final avgInterval =
        intervals.reduce((a, b) => a + b) / intervals.length;
    final sd = _standardDeviation(intervals.map((e) => e.toDouble()).toList());
    final filtered = intervals.where(
        (i) => (i - avgInterval).abs() < 2 * sd).toList();

    if (filtered.isEmpty) return avgInterval * 0.6;

    final cleanAvg = filtered.reduce((a, b) => a + b) / filtered.length;

    // GCT ratio varies by running speed and level
    // Recreational: ~60%, Competitive: ~55%, Elite: ~50%
    return cleanAvg * 0.58;
  }

  /// Calculate vertical oscillation in centimeters
  /// Uses normalized coordinates with body-proportional scaling
  double calculateVerticalOscillationCm({double heightCm = 175}) {
    if (_hipYHistory.length < 30) return 0;

    // Use recent 2 seconds of data for stability
    final recent = _hipYHistory.length > 60
        ? _hipYHistory.sublist(_hipYHistory.length - 60)
        : _hipYHistory.toList();

    if (recent.length < 10) return 0;

    // Find peak-to-trough amplitude using local min/max
    double sumAmplitude = 0;
    int cycleCount = 0;

    double localMax = recent[0];
    double localMin = recent[0];
    bool goingUp = false;

    for (int i = 1; i < recent.length; i++) {
      if (recent[i] > localMax) {
        localMax = recent[i];
        if (!goingUp && (localMax - localMin) > 0.005) {
          sumAmplitude += localMax - localMin;
          cycleCount++;
          localMin = localMax;
          goingUp = true;
        }
      }
      if (recent[i] < localMin) {
        localMin = recent[i];
        if (goingUp && (localMax - localMin) > 0.005) {
          goingUp = false;
          localMax = localMin;
        }
      }
    }

    if (cycleCount == 0) {
      // Fallback: simple peak-trough
      final maxY = recent.reduce(math.max);
      final minY = recent.reduce(math.min);
      return ((maxY - minY).abs() * heightCm).clamp(2.0, 20.0);
    }

    final avgAmplitude = sumAmplitude / cycleCount;
    // Convert normalized amplitude to cm using body height as reference
    return (avgAmplitude * heightCm).clamp(2.0, 20.0);
  }

  /// Calculate cadence (steps per minute) from step timestamps
  int calculateCadence() {
    if (_stepTimestamps.length < 4) return 0;

    // Use only recent timestamps (last 3 seconds worth)
    final cutoff = _stepTimestamps.last - 3000;
    final recentSteps =
        _stepTimestamps.where((t) => t >= cutoff).toList();

    if (recentSteps.length < 3) {
      // Fallback to full range
      final timeSpanMs =
          _stepTimestamps.last - _stepTimestamps.first;
      if (timeSpanMs <= 0) return 0;
      return ((_stepTimestamps.length / timeSpanMs) * 60000).round();
    }

    final timeSpanMs = recentSteps.last - recentSteps.first;
    if (timeSpanMs <= 0) return 0;

    final stepsPerMs = recentSteps.length / timeSpanMs;
    return (stepsPerMs * 60000).round().clamp(100, 240);
  }

  /// Calculate forward lean angle from shoulder-hip alignment
  double calculateForwardLeanDegrees() {
    if (_frames.length < 5) return 0;

    // Average over recent frames for stability
    double sumAngle = 0;
    final count = math.min(10, _frames.length);
    for (int i = _frames.length - count; i < _frames.length; i++) {
      final frame = _frames[i];
      final shoulderMid = _midpoint(
        frame.landmarks[leftShoulder],
        frame.landmarks[rightShoulder],
      );
      final hipMid = _midpoint(
        frame.landmarks[leftHip],
        frame.landmarks[rightHip],
      );

      // Angle of trunk from vertical
      final dx = shoulderMid.x - hipMid.x;
      final dy = shoulderMid.y - hipMid.y;
      final angleRad = math.atan2(dx.abs(), dy.abs());
      sumAngle += angleRad * 180 / math.pi;
    }

    return sumAngle / count;
  }

  /// Calculate hip drop angle (Trendelenburg sign)
  ///
  /// Averaged over recent frames to detect persistent weakness
  double calculateHipDropDegrees() {
    if (_frames.length < 5) return 0;

    double maxDrop = 0;
    final count = math.min(15, _frames.length);

    for (int i = _frames.length - count; i < _frames.length; i++) {
      final frame = _frames[i];
      final leftHipY = frame.landmarks[leftHip].y;
      final rightHipY = frame.landmarks[rightHip].y;
      final hipDist =
          (frame.landmarks[leftHip].x - frame.landmarks[rightHip].x).abs();

      if (hipDist < 0.01) continue;

      final dropRad = math.atan2((leftHipY - rightHipY).abs(), hipDist);
      final dropDeg = dropRad * 180 / math.pi;
      if (dropDeg > maxDrop) maxDrop = dropDeg;
    }

    return maxDrop;
  }

  /// Detect foot strike type based on ankle-heel-toe positions at contact
  ///
  /// Uses multiple frames for statistical reliability
  FootStrikeDetection detectFootStrike() {
    if (_frames.length < 10) return FootStrikeDetection.unknown;

    int heelCount = 0;
    int midCount = 0;
    int foreCount = 0;
    final count = math.min(20, _frames.length);

    for (int i = _frames.length - count; i < _frames.length; i++) {
      final frame = _frames[i];

      // Check both feet
      for (final side in [
        [leftHeel, leftFootIndex],
        [rightHeel, rightFootIndex]
      ]) {
        final heelY = frame.landmarks[side[0]].y;
        final toeY = frame.landmarks[side[1]].y;

        // In image coordinates: higher Y = lower in frame = closer to ground
        if (heelY > toeY + 0.015) {
          heelCount++;
        } else if (toeY > heelY + 0.015) {
          foreCount++;
        } else {
          midCount++;
        }
      }
    }

    final total = heelCount + midCount + foreCount;
    if (total == 0) return FootStrikeDetection.unknown;

    // Return dominant pattern
    if (heelCount > midCount && heelCount > foreCount) {
      return FootStrikeDetection.heel;
    }
    if (foreCount > midCount && foreCount > heelCount) {
      return FootStrikeDetection.forefoot;
    }
    return FootStrikeDetection.midfoot;
  }

  /// Calculate arm swing symmetry using wrist trajectory analysis
  ///
  /// Improved: uses actual wrist positions instead of shoulder proxy
  double calculateArmSwingSymmetry() {
    if (_frames.length < 30) return 1.0;

    final recent = _frames.sublist(
        math.max(0, _frames.length - 45), _frames.length);

    // Calculate range of motion for each wrist
    double leftMinX = 1.0, leftMaxX = 0.0;
    double rightMinX = 1.0, rightMaxX = 0.0;
    double leftMinY = 1.0, leftMaxY = 0.0;
    double rightMinY = 1.0, rightMaxY = 0.0;

    for (final frame in recent) {
      final lw = frame.landmarks[leftWrist];
      final rw = frame.landmarks[rightWrist];

      if (lw.x < leftMinX) leftMinX = lw.x;
      if (lw.x > leftMaxX) leftMaxX = lw.x;
      if (lw.y < leftMinY) leftMinY = lw.y;
      if (lw.y > leftMaxY) leftMaxY = lw.y;

      if (rw.x < rightMinX) rightMinX = rw.x;
      if (rw.x > rightMaxX) rightMaxX = rw.x;
      if (rw.y < rightMinY) rightMinY = rw.y;
      if (rw.y > rightMaxY) rightMaxY = rw.y;
    }

    // Calculate arc length (combined X + Y range) for each arm
    final leftArc = math.sqrt(
        math.pow(leftMaxX - leftMinX, 2) + math.pow(leftMaxY - leftMinY, 2));
    final rightArc = math.sqrt(math.pow(rightMaxX - rightMinX, 2) +
        math.pow(rightMaxY - rightMinY, 2));

    if (leftArc == 0 && rightArc == 0) return 1.0;
    if (leftArc == 0 || rightArc == 0) return 0.5;

    final ratio = math.min(leftArc, rightArc) /
        math.max(leftArc, rightArc);
    return ratio.clamp(0.0, 1.0);
  }

  /// Generate overall form score (0-100) using weighted multi-factor assessment
  int calculateFormScore() {
    int score = 40; // Base score (showing up is half the battle)

    final gct = calculateGroundContactTimeMs();
    if (gct > 0) {
      if (gct < 200) score += 18;
      else if (gct < 230) score += 14;
      else if (gct < 260) score += 10;
      else if (gct < 300) score += 5;
      else score += 2;
    }

    final cadence = calculateCadence();
    if (cadence > 0) {
      if (cadence >= 175 && cadence <= 190) score += 18;
      else if (cadence >= 170) score += 14;
      else if (cadence >= 165) score += 10;
      else if (cadence >= 160) score += 5;
      else score += 2;
    }

    final lean = calculateForwardLeanDegrees();
    if (lean >= 5 && lean <= 10) score += 8;
    else if (lean >= 3 && lean <= 15) score += 5;
    else if (lean > 0) score += 2;

    final hipDrop = calculateHipDropDegrees();
    if (hipDrop < 4) score += 8;
    else if (hipDrop < 6) score += 5;
    else if (hipDrop < 8) score += 3;

    final armSym = calculateArmSwingSymmetry();
    if (armSym >= 0.9) score += 8;
    else if (armSym >= 0.8) score += 5;
    else if (armSym >= 0.7) score += 3;

    return score.clamp(0, 100);
  }

  /// Generate coaching tips based on current metrics
  List<String> generateCoachingTips() {
    final tips = <String>[];

    final gct = calculateGroundContactTimeMs();
    if (gct > 280) {
      tips.add(
          'Reduce ground contact time (${gct.toInt()}ms). Focus on "quick feet" with light, springy steps.');
    } else if (gct > 250) {
      tips.add(
          'Ground contact (${gct.toInt()}ms) is average. Drills like high knees and bounds can help.');
    }

    final cadence = calculateCadence();
    if (cadence > 0 && cadence < 165) {
      tips.add(
          'Cadence is low ($cadence spm). Use a 170-180 BPM metronome during easy runs to build habit.');
    } else if (cadence > 0 && cadence < 175) {
      tips.add(
          'Cadence ($cadence spm) could improve. Target 175-185 spm for optimal efficiency.');
    }

    final lean = calculateForwardLeanDegrees();
    if (lean < 3) {
      tips.add('Lean slightly forward from the ankles (not waist) for better propulsion.');
    } else if (lean > 15) {
      tips.add(
          'Forward lean (${lean.toStringAsFixed(1)}°) is excessive. Stand taller and hinge from ankles.');
    }

    final hipDrop = calculateHipDropDegrees();
    if (hipDrop > 8) {
      tips.add(
          'Significant hip drop (${hipDrop.toStringAsFixed(1)}°). Strengthen glutes with clamshells and single-leg squats.');
    } else if (hipDrop > 5) {
      tips.add(
          'Moderate hip drop. Include lateral band walks in your warm-up routine.');
    }

    final armSym = calculateArmSwingSymmetry();
    if (armSym < 0.75) {
      tips.add(
          'Arm swing asymmetry detected (${(armSym * 100).toInt()}%). Check for compensatory patterns or carry items.');
    }

    final footStrike = detectFootStrike();
    if (footStrike == FootStrikeDetection.heel) {
      tips.add(
          'Heel striking detected. Try landing with feet under your center of mass.');
    }

    if (tips.isEmpty) {
      tips.add('Excellent running form! Maintain consistency and focus on gradual progression.');
    }

    return tips;
  }

  PoseLandmark _midpoint(PoseLandmark a, PoseLandmark b) {
    return PoseLandmark(
      x: (a.x + b.x) / 2,
      y: (a.y + b.y) / 2,
      z: (a.z + b.z) / 2,
    );
  }

  double _standardDeviation(List<double> data) {
    if (data.length < 2) return 0;
    final mean = data.reduce((a, b) => a + b) / data.length;
    final variance = data.map((d) => math.pow(d - mean, 2)).reduce((a, b) => a + b) / data.length;
    return math.sqrt(variance);
  }

  /// Reset all accumulated data
  void reset() {
    _frames.clear();
    _groundContactTimes.clear();
    _verticalOscillations.clear();
    _strideLengths.clear();
    _stepTimestamps.clear();
    _hipYHistory.clear();
    _leftFootDown = false;
    _rightFootDown = false;
    _lastLeftContactMs = 0;
    _lastRightContactMs = 0;
  }
}

/// Simple pose landmark model (compatible with MediaPipe output)
class PoseLandmark {
  final double x; // Normalized [0.0, 1.0]
  final double y; // Normalized [0.0, 1.0]
  final double z; // Depth (relative)

  const PoseLandmark({
    required this.x,
    required this.y,
    this.z = 0.0,
  });

  factory PoseLandmark.fromMap(Map<String, dynamic> map) {
    return PoseLandmark(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      z: (map['z'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Internal pose frame for time-series analysis
class _PoseFrame {
  final List<PoseLandmark> landmarks;
  final int timestampMs;
  final double confidence;

  const _PoseFrame({
    required this.landmarks,
    required this.timestampMs,
    required this.confidence,
  });
}

/// Foot strike detection result
enum FootStrikeDetection {
  heel,
  midfoot,
  forefoot,
  unknown,
}
