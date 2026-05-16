import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/layout/responsive.dart';
import 'core/logger/app_logger.dart';
import 'core/storage/secure_hive.dart';
import 'core/theme/app_theme.dart';
import 'data/services/revenue_cat_service.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/screens/auth_wrapper.dart';

/// Background FCM handler. Must be a top-level function (not a closure)
/// so the Dart isolate can locate it when the app is killed.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  // No-op for now. FCM displays the notification automatically when the
  // message has a `notification` payload. We'd hook user-data-only messages
  // here in the future (e.g. silent sync triggers).
}

/// ApexRun — Performance Running Platform
///
/// Entry point. ALL secret config injected via --dart-define / .env.json.
/// On startup we initialize crash reporting first so any later failure is captured.
Future<void> main() async {
  // Wrap the entire bootstrap so async errors caught even before runApp.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final log = AppLogger.tag('Boot');

    assert(() {
      if (!Env.isConfigured) {
        debugPrint('==== ApexRun config error ====\n${Env.configurationErrorMessage}\n==============================');
      }
      return true;
    }());

    // ── Crash reporting ──────────────────────────────────────────────
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (Env.isSentryConfigured && kReleaseMode) {
        Sentry.captureException(details.exception, stackTrace: details.stack);
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (Env.isSentryConfigured && kReleaseMode) {
        Sentry.captureException(error, stackTrace: stack);
      }
      return true;
    };

    // ── Local storage (encrypted) ────────────────────────────────────
    await Hive.initFlutter();
    await SecureHive.openBox<Map>('daily_activity');

    // ── Mapbox ───────────────────────────────────────────────────────
    if (Env.isMapboxConfigured) {
      MapboxOptions.setAccessToken(Env.mapboxAccessToken);
    }

    // ── RevenueCat ───────────────────────────────────────────────────
    await RevenueCatService.init();

    // ── Firebase + FCM ───────────────────────────────────────────────
    // Firebase initialization is best-effort. If google-services.json /
    // GoogleService-Info.plist are absent or invalid, the app still runs;
    // push notifications are just disabled.
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
      log.i('Firebase initialized');
    } catch (e, st) {
      log.w('Firebase init skipped (config missing?)', error: e, stackTrace: st);
    }

    // ── Supabase ─────────────────────────────────────────────────────
    if (Env.isConfigured) {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
    } else {
      log.w('Supabase not initialized — required config missing');
    }

    // ── Run inside Sentry-wrapped runApp when configured ─────────────
    if (Env.isSentryConfigured) {
      await SentryFlutter.init(
        (options) {
          options.dsn = Env.sentryDsn;
          options.environment = Env.sentryEnvironment;
          options.release = '${Env.appName}@${Env.appVersion}';
          options.tracesSampleRate = Env.sentryTracesSampleRate;
          options.attachStacktrace = true;
          options.sendDefaultPii = false;
          options.beforeSend = (event, hint) async {
            // Strip request bodies and headers that may contain tokens.
            final stripped = event.copyWith(
              request: event.request?.copyWith(
                data: null,
                cookies: null,
                headers: const {},
              ),
              user: event.user?.copyWith(email: null, ipAddress: null),
            );
            return stripped;
          };
        },
        appRunner: () => runApp(const ProviderScope(child: ApexRunApp())),
      );
    } else {
      runApp(const ProviderScope(child: ApexRunApp()));
    }
  }, (error, stack) {
    // Last-resort zone catcher.
    if (Env.isSentryConfigured && kReleaseMode) {
      Sentry.captureException(error, stackTrace: stack);
    }
    debugPrint('Uncaught zone error: $error');
  });
}

class ApexRunApp extends StatelessWidget {
  const ApexRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Env.isConfigured) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.error),
                  const SizedBox(height: 24),
                  Text(
                    'Configuration Error',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    Env.configurationErrorMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'ApexRun',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Clamp accessibility text-scale so extreme settings don't shred layouts.
      builder: (context, child) => TextScaleClamp(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AuthWrapper(),
    );
  }
}
