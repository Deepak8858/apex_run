import 'package:flutter_test/flutter_test.dart';
import 'package:apex_run/core/config/env.dart';

void main() {
  group('Env', () {
    test('isConfigured returns true with default values', () {
      expect(Env.isConfigured, true);
    });

    test('isMapboxConfigured returns true with default token', () {
      expect(Env.isMapboxConfigured, true);
    });

    test('isGeminiConfigured returns true with default key', () {
      expect(Env.isGeminiConfigured, true);
    });

    test('supabaseUrl is set correctly', () {
      expect(Env.supabaseUrl, contains('supabase.co'));
    });

    test('backendApiUrl defaults to localhost', () {
      expect(Env.backendApiUrl, contains('localhost'));
    });

    test('geminiModel defaults to gemini-2.0-flash', () {
      expect(Env.geminiModel, 'gemini-2.0-flash');
    });

    test('gpsDistanceFilterMeters has reasonable default', () {
      expect(Env.gpsDistanceFilterMeters, greaterThan(0));
      expect(Env.gpsDistanceFilterMeters, lessThanOrEqualTo(50));
    });

    test('homePrivacyRadiusMeters has reasonable default', () {
      expect(Env.homePrivacyRadiusMeters, greaterThanOrEqualTo(100));
      expect(Env.homePrivacyRadiusMeters, lessThanOrEqualTo(500));
    });

    test('configurationErrorMessage is valid when configured', () {
      expect(Env.configurationErrorMessage, 'Configuration is valid');
    });
  });
}
