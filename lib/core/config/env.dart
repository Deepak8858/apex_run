/// Environment Configuration for ApexRun
///
/// This file contains environment-specific configuration values.
/// Credentials should be passed via --dart-define flags or environment variables.
class Env {
  // ── Supabase Configuration ──────────────────────────────────────────
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://voddddmmiarnbvwmgzgo.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvZGRkZG1taWFybmJ2d21nemdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NTE3OTcsImV4cCI6MjA4NjIyNzc5N30.i7Ni-NHsmbwaXEoyOut_26PH1PK_Xycw3ChzkvPtklM',
  );

  static const String supabaseServiceKey = String.fromEnvironment(
    'SUPABASE_SERVICE_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvZGRkZG1taWFybmJ2d21nemdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NTE3OTcsImV4cCI6MjA4NjIyNzc5N30.i7Ni-NHsmbwaXEoyOut_26PH1PK_Xycw3ChzkvPtklM',
  );

  // ── Mapbox Configuration ────────────────────────────────────────────
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: 'pk.eyJ1IjoiZGVlcGFrNzIzOCIsImEiOiJjbWxnZjAwMTMwOWo5M2xzaHF3eTd1eTd6In0.cNbgPuE749GMnCztExzPgg',
  );

  static const String mapboxStyleUrl = String.fromEnvironment(
    'MAPBOX_STYLE_URL',
    defaultValue: 'mapbox://styles/deepak7238/cmlgf5u11002901s73tdc1xk9',
  );

  // ── Backend API Configuration ───────────────────────────────────────
  static const String backendApiUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: 'http://localhost:8080',
  );

  // ── Google Cloud / Gemini Configuration ─────────────────────────────
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AQ.Ab8RN6JLx52aNNnmEVb6IoVrkCrsN5Hq3XKUW3hRn2gRKaxHyQ',
  );

  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );

  // ── Redis Configuration (for direct client access if needed) ────────
  static const String redisUrl = String.fromEnvironment(
    'REDIS_URL',
    defaultValue: '134.199.187.2:6379',
  );

  static const String redisPassword = String.fromEnvironment(
    'REDIS_PASSWORD',
    defaultValue: 'Dream@885890',
  );

  // ── App Configuration ───────────────────────────────────────────────
  static const String appVersion = '1.0.0';
  static const String appName = 'ApexRun';

  // ── Feature Flags (for gradual rollout) ─────────────────────────────
  static const bool enableAiCoaching = bool.fromEnvironment(
    'ENABLE_AI_COACHING',
    defaultValue: true,
  );

  static const bool enableEdgeFunctions = bool.fromEnvironment(
    'ENABLE_EDGE_FUNCTIONS',
    defaultValue: true,
  );

  static const bool enableFormAnalysis = bool.fromEnvironment(
    'ENABLE_FORM_ANALYSIS',
    defaultValue: true,
  );

  static const bool enableSegmentLeaderboards = bool.fromEnvironment(
    'ENABLE_SEGMENT_LEADERBOARDS',
    defaultValue: true,
  );

  static const bool enableBackgroundGps = bool.fromEnvironment(
    'ENABLE_BACKGROUND_GPS',
    defaultValue: true,
  );

  static const bool enablePrivacyShroud = bool.fromEnvironment(
    'ENABLE_PRIVACY_SHROUD',
    defaultValue: true,
  );

  // ── GPS Configuration ───────────────────────────────────────────────
  static const int gpsUpdateIntervalMs = int.fromEnvironment(
    'GPS_UPDATE_INTERVAL_MS',
    defaultValue: 1500,
  );

  static const int gpsAccuracyThresholdMeters = int.fromEnvironment(
    'GPS_ACCURACY_THRESHOLD_METERS',
    defaultValue: 20,
  );

  static const int gpsDistanceFilterMeters = int.fromEnvironment(
    'GPS_DISTANCE_FILTER_METERS',
    defaultValue: 5,
  );

  // ── Privacy Configuration ───────────────────────────────────────────
  static const int homePrivacyRadiusMeters = int.fromEnvironment(
    'HOME_PRIVACY_RADIUS_METERS',
    defaultValue: 200,
  );

  /// Validate that all required environment variables are set
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }

  /// Check if Mapbox is configured
  static bool get isMapboxConfigured => mapboxAccessToken.isNotEmpty;

  /// Check if Gemini AI is configured
  static bool get isGeminiConfigured => geminiApiKey.isNotEmpty;

  /// Get user-friendly error message for missing configuration
  static String get configurationErrorMessage {
    final List<String> missing = [];

    if (supabaseUrl.isEmpty) {
      missing.add('SUPABASE_URL');
    }
    if (supabaseAnonKey.isEmpty) {
      missing.add('SUPABASE_ANON_KEY');
    }

    if (missing.isEmpty) {
      return 'Configuration is valid';
    }

    return 'Missing required environment variables: ${missing.join(', ')}\n\n'
        'Please run with:\n'
        'flutter run --dart-define=SUPABASE_URL=your_url '
        '--dart-define=SUPABASE_ANON_KEY=your_key';
  }

  /// Full list of all dart-define flags for reference
  static String get dartDefineHelp => '''
flutter run \\
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \\
  --dart-define=SUPABASE_ANON_KEY=eyJ... \\
  --dart-define=SUPABASE_SERVICE_KEY=eyJ... \\
  --dart-define=MAPBOX_ACCESS_TOKEN=pk.eyJ... \\
  --dart-define=MAPBOX_STYLE_URL=mapbox://styles/... \\
  --dart-define=BACKEND_API_URL=http://your-server:8080 \\
  --dart-define=GEMINI_API_KEY=AI... \\
  --dart-define=GEMINI_MODEL=gemini-1.5-flash \\
  --dart-define=REDIS_URL=134.199.187.2:6379 \\
  --dart-define=REDIS_PASSWORD=your_password \\
  --dart-define=ENABLE_AI_COACHING=true \\
  --dart-define=ENABLE_EDGE_FUNCTIONS=true \\
  --dart-define=ENABLE_BACKGROUND_GPS=true \\
  --dart-define=ENABLE_PRIVACY_SHROUD=true \\
  --dart-define=GPS_UPDATE_INTERVAL_MS=1500 \\
  --dart-define=GPS_ACCURACY_THRESHOLD_METERS=20 \\
  --dart-define=GPS_DISTANCE_FILTER_METERS=5 \\
  --dart-define=HOME_PRIVACY_RADIUS_METERS=200
''';
}
