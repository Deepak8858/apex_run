/// Environment Configuration for ApexRun
///
/// ALL VALUES MUST BE INJECTED AT BUILD TIME via `--dart-define` or
/// `--dart-define-from-file=.env.json`. NEVER hardcode credentials here.
///
/// Example:
///   flutter run \
///     --dart-define-from-file=.env.json
///
/// Or per-flag:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// See `.env.example.json` for the full list of required variables.
/// See `SECURITY_ROTATION.md` for the credential rotation playbook.
class Env {
  // ── Supabase Configuration ──────────────────────────────────────────
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Service role key. NEVER ship in client builds. Reserved for CI / Edge Functions.
  static const String supabaseServiceKey = String.fromEnvironment('SUPABASE_SERVICE_KEY');

  // ── Mapbox Configuration ────────────────────────────────────────────
  static const String mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  static const String mapboxStyleUrl = String.fromEnvironment(
    'MAPBOX_STYLE_URL',
    defaultValue: 'mapbox://styles/mapbox/dark-v11',
  );

  // ── Backend API Configuration ───────────────────────────────────────
  static const String backendApiUrl = String.fromEnvironment('BACKEND_API_URL');
  static const String mlServiceUrl = String.fromEnvironment('ML_SERVICE_URL');

  // ── Gemini Configuration ────────────────────────────────────────────
  /// Gemini API key lives ONLY in Supabase Edge Function secrets. The client
  /// never holds it. `enableAiCoaching` toggles whether the client attempts
  /// to call AI Edge Functions at all (rule-based fallback otherwise).
  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.0-flash',
  );

  // ── Google Sign-In Configuration ───────────────────────────────────
  /// Web Client ID from Google Cloud Console.
  /// Must match the Web Client ID configured in Supabase Auth → Google provider.
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// iOS Client ID from Google Cloud Console (required for native Google Sign-In on iOS).
  static const String googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  // ── Redis Configuration ─────────────────────────────────────────────
  /// DEPRECATED on client. Direct Redis access from the app is forbidden;
  /// always route through the backend API. Kept only for legacy edge cases.
  static const String redisUrl = String.fromEnvironment('REDIS_URL');
  static const String redisPassword = String.fromEnvironment('REDIS_PASSWORD');

  // ── App Configuration ───────────────────────────────────────────────
  static const String appVersion = '1.0.0';
  static const String appName = 'ApexRun';

  // ── Observability ───────────────────────────────────────────────────
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const String sentryEnvironment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: 'development',
  );
  static const double sentryTracesSampleRate = 0.1;

  static bool get isSentryConfigured => sentryDsn.isNotEmpty;

  // ── RevenueCat ──────────────────────────────────────────────────────
  /// Public API keys (platform-specific). RevenueCat docs:
  ///   iOS:     appl_xxx
  ///   Android: goog_xxx
  /// These are safe to ship — entitlement enforcement happens server-side
  /// via webhook → `public.subscriptions`.
  static const String revenueCatIosKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const String revenueCatAndroidKey = String.fromEnvironment('REVENUECAT_ANDROID_KEY');

  static bool get isRevenueCatConfigured =>
      revenueCatIosKey.isNotEmpty || revenueCatAndroidKey.isNotEmpty;

  // ── Certificate Pinning ─────────────────────────────────────────────
  /// Comma-separated list of SHA-256 fingerprints (base64) for the backend
  /// API certificate chain. Get via:
  ///   openssl s_client -servername api.example.com -connect api.example.com:443 \
  ///     | openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER \
  ///     | openssl dgst -sha256 -binary | openssl enc -base64
  static const String backendCertSha256Fingerprints =
      String.fromEnvironment('BACKEND_CERT_SHA256_FINGERPRINTS');

  // ── Feature Flags ───────────────────────────────────────────────────
  static const bool enableAiCoaching = bool.fromEnvironment('ENABLE_AI_COACHING', defaultValue: true);
  static const bool enableEdgeFunctions = bool.fromEnvironment('ENABLE_EDGE_FUNCTIONS', defaultValue: true);
  static const bool enableFormAnalysis = bool.fromEnvironment('ENABLE_FORM_ANALYSIS', defaultValue: true);
  static const bool enableSegmentLeaderboards = bool.fromEnvironment('ENABLE_SEGMENT_LEADERBOARDS', defaultValue: true);
  static const bool enableBackgroundGps = bool.fromEnvironment('ENABLE_BACKGROUND_GPS', defaultValue: true);
  static const bool enablePrivacyShroud = bool.fromEnvironment('ENABLE_PRIVACY_SHROUD', defaultValue: true);

  // ── GPS Configuration ───────────────────────────────────────────────
  static const int gpsUpdateIntervalMs = int.fromEnvironment('GPS_UPDATE_INTERVAL_MS', defaultValue: 1500);
  static const int gpsAccuracyThresholdMeters = int.fromEnvironment('GPS_ACCURACY_THRESHOLD_METERS', defaultValue: 20);
  static const int gpsDistanceFilterMeters = int.fromEnvironment('GPS_DISTANCE_FILTER_METERS', defaultValue: 5);

  // ── Privacy Configuration ───────────────────────────────────────────
  static const int homePrivacyRadiusMeters = int.fromEnvironment('HOME_PRIVACY_RADIUS_METERS', defaultValue: 200);

  // ── Validation ──────────────────────────────────────────────────────

  /// All required secrets present.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      mapboxAccessToken.isNotEmpty &&
      googleWebClientId.isNotEmpty;

  static bool get isMapboxConfigured => mapboxAccessToken.isNotEmpty;

  /// Human-readable list of any missing required vars.
  static String get configurationErrorMessage {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    if (mapboxAccessToken.isEmpty) missing.add('MAPBOX_ACCESS_TOKEN');
    if (googleWebClientId.isEmpty) missing.add('GOOGLE_WEB_CLIENT_ID');

    if (missing.isEmpty) return 'Configuration is valid';

    return 'Missing required environment variables:\n'
        '  ${missing.join('\n  ')}\n\n'
        'Provide them at build time:\n'
        '  flutter run --dart-define-from-file=.env.json\n\n'
        'See .env.example.json for the template.';
  }

  /// Reference for CI / developer onboarding.
  static String get dartDefineHelp => '''
# Preferred: single-file injection
flutter run --dart-define-from-file=.env.json

# Or per-flag:
flutter run \\
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \\
  --dart-define=SUPABASE_ANON_KEY=eyJ... \\
  --dart-define=MAPBOX_ACCESS_TOKEN=pk.eyJ... \\
  --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com \\
  --dart-define=GOOGLE_IOS_CLIENT_ID=xxx.apps.googleusercontent.com \\
  --dart-define=BACKEND_API_URL=https://api.example.com \\
  --dart-define=ML_SERVICE_URL=https://api.example.com \\
  --dart-define=MAPBOX_STYLE_URL=mapbox://styles/... \\
  --dart-define=GEMINI_MODEL=gemini-2.0-flash
''';
}
