import 'package:flutter_test/flutter_test.dart';
import 'package:apex_run/ml/gait_metrics_calculator.dart';

void main() {
  late GaitMetricsCalculator calculator;

  setUp(() {
    calculator = GaitMetricsCalculator();
  });

  group('GaitMetricsCalculator', () {
    test('hasEnoughData returns false with no frames', () {
      expect(calculator.hasEnoughData, false);
    });

    test('hasEnoughData returns true after 30+ frames', () {
      // Feed 35 dummy frames
      for (int i = 0; i < 35; i++) {
        calculator.addPoseFrame(
          landmarks: _generateDummyLandmarks(i),
          timestampMs: i * 33, // ~30fps
          confidence: 0.9,
        );
      }
      expect(calculator.hasEnoughData, true);
    });

    test('rejects low confidence frames', () {
      calculator.addPoseFrame(
        landmarks: _generateDummyLandmarks(0),
        timestampMs: 0,
        confidence: 0.1, // Too low
      );
      expect(calculator.hasEnoughData, false);
    });

    test('rejects frames with too few landmarks', () {
      calculator.addPoseFrame(
        landmarks: [
          const PoseLandmark(x: 0.5, y: 0.5),
        ], // Only 1 landmark
        timestampMs: 0,
        confidence: 0.9,
      );
      expect(calculator.hasEnoughData, false);
    });

    test('calculateFormScore returns score between 0-100', () {
      _feedSufficientFrames(calculator);
      final score = calculator.calculateFormScore();
      expect(score, greaterThanOrEqualTo(0));
      expect(score, lessThanOrEqualTo(100));
    });

    test('calculateCadence returns positive value with data', () {
      _feedSufficientFrames(calculator, frameCount: 60);
      final cadence = calculator.calculateCadence();
      expect(cadence, greaterThanOrEqualTo(0));
    });

    test('calculateForwardLeanDegrees returns non-negative', () {
      _feedSufficientFrames(calculator);
      final lean = calculator.calculateForwardLeanDegrees();
      expect(lean, greaterThanOrEqualTo(0));
    });

    test('calculateHipDropDegrees returns non-negative', () {
      _feedSufficientFrames(calculator);
      final drop = calculator.calculateHipDropDegrees();
      expect(drop, greaterThanOrEqualTo(0.0));
    });

    test('calculateArmSwingSymmetry returns value in 0-1 range', () {
      _feedSufficientFrames(calculator);
      final symmetry = calculator.calculateArmSwingSymmetry();
      expect(symmetry, greaterThanOrEqualTo(0.0));
      expect(symmetry, lessThanOrEqualTo(1.0));
    });

    test('detectFootStrike returns a valid detection', () {
      _feedSufficientFrames(calculator);
      final strike = calculator.detectFootStrike();
      expect(FootStrikeDetection.values, contains(strike));
    });

    test('generateCoachingTips returns non-empty list', () {
      _feedSufficientFrames(calculator);
      final tips = calculator.generateCoachingTips();
      expect(tips, isNotEmpty);
    });

    test('reset clears all data', () {
      _feedSufficientFrames(calculator);
      expect(calculator.hasEnoughData, true);
      calculator.reset();
      expect(calculator.hasEnoughData, false);
    });
  });
}

/// Generate dummy 33-landmark pose data simulating a runner
List<PoseLandmark> _generateDummyLandmarks(int frameIndex) {
  final landmarks = <PoseLandmark>[];
  final phase = (frameIndex % 30) / 30.0; // Running gait cycle phase

  for (int i = 0; i < 33; i++) {
    double x = 0.5;
    double y = 0.5;
    double z = 0.0;

    switch (i) {
      case 0: // Nose
        x = 0.5;
        y = 0.15 + 0.01 * _oscillate(phase);
        break;
      case 11: // Left Shoulder
        x = 0.45;
        y = 0.25 + 0.01 * _oscillate(phase);
        break;
      case 12: // Right Shoulder
        x = 0.55;
        y = 0.25 + 0.01 * _oscillate(phase);
        break;
      case 23: // Left Hip
        x = 0.47;
        y = 0.50 + 0.015 * _oscillate(phase);
        break;
      case 24: // Right Hip
        x = 0.53;
        y = 0.50 + 0.015 * _oscillate(phase + 0.5);
        break;
      case 25: // Left Knee
        x = 0.46;
        y = 0.65 + 0.03 * _oscillate(phase);
        break;
      case 26: // Right Knee
        x = 0.54;
        y = 0.65 + 0.03 * _oscillate(phase + 0.5);
        break;
      case 27: // Left Ankle
        x = 0.45;
        y = 0.85 + 0.02 * _oscillate(phase);
        break;
      case 28: // Right Ankle
        x = 0.55;
        y = 0.85 + 0.02 * _oscillate(phase + 0.5);
        break;
      case 29: // Left Heel
        x = 0.44;
        y = 0.88 + 0.01 * _oscillate(phase);
        break;
      case 30: // Right Heel
        x = 0.56;
        y = 0.88 + 0.01 * _oscillate(phase + 0.5);
        break;
      case 31: // Left Foot Index
        x = 0.46;
        y = 0.90;
        break;
      case 32: // Right Foot Index
        x = 0.54;
        y = 0.90;
        break;
      default:
        x = 0.5;
        y = i / 33.0;
    }

    landmarks.add(PoseLandmark(x: x, y: y, z: z));
  }

  return landmarks;
}

double _oscillate(double phase) {
  return (phase * 2 * 3.14159).abs() % 1.0 > 0.5 ? 1.0 : -1.0;
}

void _feedSufficientFrames(GaitMetricsCalculator calculator,
    {int frameCount = 60}) {
  for (int i = 0; i < frameCount; i++) {
    calculator.addPoseFrame(
      landmarks: _generateDummyLandmarks(i),
      timestampMs: i * 33,
      confidence: 0.9,
    );
  }
}
