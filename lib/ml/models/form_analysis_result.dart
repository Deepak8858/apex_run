/// Result of a running form analysis session using MediaPipe pose estimation.
///
/// Captures key biomechanical metrics from the 33 body landmarks provided
/// by MediaPipe's BlazePose model running on-device.
class FormAnalysisResult {
  /// Ground Contact Time in milliseconds (elite: 160-200ms)
  final double groundContactTimeMs;

  /// Vertical oscillation in centimeters (elite: 6-8cm)
  final double verticalOscillationCm;

  /// Cadence — steps per minute (ideal: 170-185 spm)
  final int cadenceSpm;

  /// Stride length in meters
  final double strideLengthM;

  /// Forward lean angle in degrees (ideal: 5-10°)
  final double? forwardLeanDeg;

  /// Hip drop angle — excessive indicates weak glutes (ideal: < 5°)
  final double? hipDropDeg;

  /// Arm swing symmetry percentage (0-100, 100 = perfectly symmetric)
  final double? armSwingSymmetryPct;

  /// Foot strike pattern detected
  final String? footStrikeType;

  /// Overall form score (0-100)
  final int formScore;

  /// Coaching tips based on the analysis
  final List<String> coachingTips;

  /// Timestamp of the analysis
  final DateTime? analyzedAt;

  /// Number of frames analyzed
  final int framesAnalyzed;

  /// Average confidence of landmark detections (0.0-1.0)
  final double avgLandmarkConfidence;

  const FormAnalysisResult({
    required this.groundContactTimeMs,
    required this.verticalOscillationCm,
    required this.cadenceSpm,
    required this.strideLengthM,
    this.forwardLeanDeg,
    this.hipDropDeg,
    this.armSwingSymmetryPct,
    this.footStrikeType,
    required this.formScore,
    this.coachingTips = const [],
    this.analyzedAt,
    this.framesAnalyzed = 0,
    this.avgLandmarkConfidence = 0.0,
  });

  factory FormAnalysisResult.fromSupabaseJson(Map<String, dynamic> json) {
    return FormAnalysisResult(
      groundContactTimeMs: (json['ground_contact_time_ms'] as num).toDouble(),
      verticalOscillationCm: (json['vertical_oscillation_cm'] as num).toDouble(),
      cadenceSpm: json['cadence_spm'] as int,
      strideLengthM: (json['stride_length_m'] as num).toDouble(),
      forwardLeanDeg: (json['forward_lean_degrees'] as num?)?.toDouble(),
      hipDropDeg: (json['hip_drop_degrees'] as num?)?.toDouble(),
      armSwingSymmetryPct: (json['arm_swing_symmetry_pct'] as num?)?.toDouble(),
      footStrikeType: json['foot_strike'] as String?,
      formScore: json['form_score'] as int,
      coachingTips: (json['coaching_tips'] as List<dynamic>?)?.cast<String>() ?? [],
      analyzedAt: json['analyzed_at'] != null
          ? DateTime.parse(json['analyzed_at'] as String)
          : null,
      framesAnalyzed: (json['frames_analyzed'] as int?) ?? 0,
      avgLandmarkConfidence: (json['avg_landmark_confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'ground_contact_time_ms': groundContactTimeMs,
      'vertical_oscillation_cm': verticalOscillationCm,
      'cadence_spm': cadenceSpm,
      'stride_length_m': strideLengthM,
      'forward_lean_degrees': forwardLeanDeg,
      'hip_drop_degrees': hipDropDeg,
      'arm_swing_symmetry_pct': armSwingSymmetryPct,
      'foot_strike': footStrikeType,
      'form_score': formScore,
      'coaching_tips': coachingTips,
      'analyzed_at': (analyzedAt ?? DateTime.now()).toIso8601String(),
      'frames_analyzed': framesAnalyzed,
      'avg_landmark_confidence': avgLandmarkConfidence,
    };
  }

  /// Human-readable GCT assessment
  String get gctAssessment {
    if (groundContactTimeMs < 200) return 'Elite';
    if (groundContactTimeMs < 250) return 'Good';
    if (groundContactTimeMs < 300) return 'Average';
    return 'Needs Work';
  }

  /// Human-readable vertical oscillation assessment
  String get oscillationAssessment {
    if (verticalOscillationCm < 8) return 'Elite';
    if (verticalOscillationCm < 10) return 'Good';
    if (verticalOscillationCm < 12) return 'Average';
    return 'Needs Work';
  }

  /// Human-readable cadence assessment
  String get cadenceAssessment {
    if (cadenceSpm >= 180) return 'Optimal';
    if (cadenceSpm >= 170) return 'Good';
    if (cadenceSpm >= 160) return 'Below Optimal';
    return 'Low';
  }
}
