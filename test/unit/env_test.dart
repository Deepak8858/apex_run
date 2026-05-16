import 'package:apex_run/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Env', () {
    // After the secret-rotation refactor these tests run in two modes:
    //   1) `flutter test` with no --dart-define: every secret-backed flag is empty.
    //   2) `flutter test --dart-define-from-file=.env.json`: flags populated.
    //
    // We test invariants that hold in BOTH modes.

    test('geminiModel keeps its non-secret default', () {
      expect(Env.geminiModel, 'gemini-2.0-flash');
    });

    test('appVersion and appName are present', () {
      expect(Env.appName, 'ApexRun');
      expect(Env.appVersion, isNotEmpty);
    });

    test('gpsDistanceFilterMeters has reasonable default', () {
      expect(Env.gpsDistanceFilterMeters, greaterThan(0));
      expect(Env.gpsDistanceFilterMeters, lessThanOrEqualTo(50));
    });

    test('gpsAccuracyThresholdMeters has reasonable default', () {
      expect(Env.gpsAccuracyThresholdMeters, greaterThan(0));
      expect(Env.gpsAccuracyThresholdMeters, lessThanOrEqualTo(100));
    });

    test('homePrivacyRadiusMeters has reasonable default', () {
      expect(Env.homePrivacyRadiusMeters, greaterThanOrEqualTo(100));
      expect(Env.homePrivacyRadiusMeters, lessThanOrEqualTo(500));
    });

    test('feature flags default to enabled', () {
      expect(Env.enableAiCoaching, true);
      expect(Env.enableEdgeFunctions, true);
      expect(Env.enableFormAnalysis, true);
      expect(Env.enableSegmentLeaderboards, true);
      expect(Env.enableBackgroundGps, true);
      expect(Env.enablePrivacyShroud, true);
    });

    test('configurationErrorMessage either valid or names missing vars', () {
      final msg = Env.configurationErrorMessage;
      if (Env.isConfigured) {
        expect(msg, 'Configuration is valid');
      } else {
        // Lists every required var that was empty.
        expect(msg, contains('Missing required environment variables'));
      }
    });

    test('sentryTracesSampleRate is between 0 and 1', () {
      expect(Env.sentryTracesSampleRate, greaterThanOrEqualTo(0));
      expect(Env.sentryTracesSampleRate, lessThanOrEqualTo(1));
    });
  });
}
