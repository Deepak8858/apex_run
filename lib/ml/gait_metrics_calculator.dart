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
/// - 0: Nose (for forward lean reference)
class GaitMetricsCalculator {
  // ── Landmark indices (BlazePose 33-point model) ──────────────────
  static const int nose = 0;
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
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

  /// Whether we have enough data to produce results
  bool get hasEnoughData => _frames.length >= 30; // ~1 second at 30fps

  /// Add a new pose frame from MediaPipe detection
  void addPoseFrame({
    required List<PoseLandmark> landmarks,
    required int timestampMs,
    required double confidence,
  }) {
    if (landmarks.length < 33 || confidence < 0.5) return;

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
    if (_frames.length < 2) return;

    final prev = _frames[_frames.length - 2];
    final curr = frame;

    // ── Detect ground contact ──────────────────────────────
    _detectGroundContact(prev, curr);

    // ── Track vertical oscillation ─────────────────────────
    _trackVerticalOscillation(curr);
  }

  /// Detect when foot makes/breaks contact with ground surface
  void _detectGroundContact(_PoseFrame prev, _PoseFrame curr) {
    final leftAnkleY = curr.landmarks[leftAnkle].y;
    final rightAnkleY = curr.landmarks[rightAnkle].y;
    final prevLeftAnkleY = prev.landmarks[leftAnkle].y;
    final prevRightAnkleY = prev.landmarks[rightAnkle].y;

    // Detect foot strike (ankle Y velocity reversal — going down then stopping)
    final leftVelocity = leftAnkleY - prevLeftAnkleY;
    final rightVelocity = rightAnkleY - prevRightAnkleY;

    // Simple ground contact detection: ankle moving down then stopping
    if (leftVelocity.abs() < 0.005 && prevLeftAnkleY < leftAnkleY) {
      _stepTimestamps.add(curr.timestampMs);
    }
    if (rightVelocity.abs() < 0.005 && prevRightAnkleY < rightAnkleY) {
      _stepTimestamps.add(curr.timestampMs);
    }
  }

  /// Track vertical center-of-mass oscillation via hip midpoint
  void _trackVerticalOscillation(_PoseFrame frame) {
    final hipMidY = (frame.landmarks[leftHip].y +
            frame.landmarks[rightHip].y) /
        2;
    _verticalOscillations.add(hipMidY);
  }

  /// Calculate the average Ground Contact Time in milliseconds
  double calculateGroundContactTimeMs() {
    if (_stepTimestamps.length < 4) return 0;

    final intervals = <int>[];
    for (var i = 1; i < _stepTimestamps.length; i++) {
      intervals.add(_stepTimestamps[i] - _stepTimestamps[i - 1]);
    }

    // GCT is approximately 60% of step interval for recreational runners
    final avgInterval =
        intervals.reduce((a, b) => a + b) / intervals.length;
    return avgInterval * 0.6;
  }

  /// Calculate vertical oscillation in centimeters
  /// Requires camera calibration; uses normalized coordinates as proxy
  double calculateVerticalOscillationCm({double heightCm = 175}) {
    if (_verticalOscillations.length < 30) return 0;

    // Calculate peak-to-trough amplitude in normalized coords
    final recent =
        _verticalOscillations.skip(_verticalOscillations.length - 60).toList();
    if (recent.length < 10) return 0;

    final maxY = recent.reduce(math.max);
    final minY = recent.reduce(math.min);
    final amplitude = (maxY - minY).abs();

    // Convert normalized amplitude to cm (rough approximation)
    // Assuming full-body view covers ~heightCm
    return amplitude * heightCm;
  }

  /// Calculate cadence (steps per minute) from step timestamps
  int calculateCadence() {
    if (_stepTimestamps.length < 4) return 0;

    final timeSpanMs =
        _stepTimestamps.last - _stepTimestamps.first;
    if (timeSpanMs <= 0) return 0;

    final stepsPerMs = _stepTimestamps.length / timeSpanMs;
    return (stepsPerMs * 60000).round(); // Convert to steps per minute
  }

  /// Calculate forward lean angle from shoulder-hip alignment
  double calculateForwardLeanDegrees() {
    if (_frames.isEmpty) return 0;

    final frame = _frames.last;
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
    return angleRad * 180 / math.pi;
  }

  /// Calculate hip drop angle (Trendelenburg sign)
  double calculateHipDropDegrees() {
    if (_frames.isEmpty) return 0;

    final frame = _frames.last;
    final leftHipY = frame.landmarks[leftHip].y;
    final rightHipY = frame.landmarks[rightHip].y;
    final hipDist = (frame.landmarks[leftHip].x -
                frame.landmarks[rightHip].x)
            .abs();

    if (hipDist < 0.01) return 0;

    final dropRad = math.atan2((leftHipY - rightHipY).abs(), hipDist);
    return dropRad * 180 / math.pi;
  }

  /// Detect foot strike type based on ankle-heel-toe positions at contact
  FootStrikeDetection detectFootStrike() {
    if (_frames.length < 5) {
      return FootStrikeDetection.unknown;
    }

    final frame = _frames.last;
    final heelY = frame.landmarks[leftHeel].y;
    final toeY = frame.landmarks[leftFootIndex].y;

    // If heel is notably lower (higher Y in image coords) than toe at contact
    if (heelY > toeY + 0.02) return FootStrikeDetection.heel;
    if (toeY > heelY + 0.02) return FootStrikeDetection.forefoot;
    return FootStrikeDetection.midfoot;
  }

  /// Calculate arm swing symmetry (0.0-1.0)
  double calculateArmSwingSymmetry() {
    if (_frames.length < 30) return 1.0;

    // Compare wrist trajectories over recent frames
    final recent = _frames.skip(_frames.length - 30).toList();

    double leftRange = 0;
    double rightRange = 0;

    for (final frame in recent) {
      // Using shoulders as proxy since wrists may be less reliable
      leftRange += frame.landmarks[leftShoulder].x;
      rightRange += frame.landmarks[rightShoulder].x;
    }

    leftRange /= recent.length;
    rightRange /= recent.length;

    if (leftRange == 0 && rightRange == 0) return 1.0;

    final ratio = math.min(leftRange, rightRange) /
        math.max(leftRange, rightRange);
    return ratio.clamp(0.0, 1.0);
  }

  /// Generate overall form score (0-100)
  int calculateFormScore() {
    int score = 50; // Base score

    final gct = calculateGroundContactTimeMs();
    if (gct > 0) {
      if (gct < 200) score += 15;
      else if (gct < 250) score += 10;
      else if (gct < 300) score += 5;
    }

    final cadence = calculateCadence();
    if (cadence > 0) {
      if (cadence >= 180) score += 15;
      else if (cadence >= 170) score += 10;
      else if (cadence >= 160) score += 5;
    }

    final lean = calculateForwardLeanDegrees();
    if (lean >= 5 && lean <= 12) score += 10;
    else if (lean > 0 && lean < 20) score += 5;

    final hipDrop = calculateHipDropDegrees();
    if (hipDrop < 5) score += 10;
    else if (hipDrop < 8) score += 5;

    return score.clamp(0, 100);
  }

  /// Generate coaching tips based on current metrics
  List<String> generateCoachingTips() {
    final tips = <String>[];

    final gct = calculateGroundContactTimeMs();
    if (gct > 280) {
      tips.add(
          'Try to reduce ground contact time. Think "quick feet" and light steps.');
    }

    final cadence = calculateCadence();
    if (cadence > 0 && cadence < 170) {
      tips.add(
          'Your cadence is ${cadence} spm. Try to increase to 170-180 for better efficiency.');
    }

    final lean = calculateForwardLeanDegrees();
    if (lean < 3) {
      tips.add('Lean slightly forward from the ankles, not the waist.');
    } else if (lean > 15) {
      tips.add('You\'re leaning too far forward. Stand taller and lean from ankles.');
    }

    final hipDrop = calculateHipDropDegrees();
    if (hipDrop > 8) {
      tips.add(
          'Excessive hip drop detected. Strengthen glutes with single-leg exercises.');
    }

    if (tips.isEmpty) {
      tips.add('Great form! Keep up the good work.');
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

  /// Reset all accumulated data
  void reset() {
    _frames.clear();
    _groundContactTimes.clear();
    _verticalOscillations.clear();
    _strideLengths.clear();
    _stepTimestamps.clear();
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
