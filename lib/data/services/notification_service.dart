import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/config/env.dart';
import '../../core/logger/app_logger.dart';

/// Combined push + local notification service.
///
/// Responsibilities:
///   * Initialize Firebase Cloud Messaging (push from server)
///   * Initialize flutter_local_notifications (scheduled streak warnings)
///   * Persist the FCM token in `public.push_tokens` for the active user
///   * Channel/category configuration (Android channel, iOS critical alert)
///
/// Wire from main.dart after Supabase.initialize, or lazily on first
/// authenticated screen. All methods are safe to call when Firebase is
/// not configured (they no-op + log warning).
class NotificationService {
  NotificationService(this._supabase);

  final SupabaseClient _supabase;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final _log = AppLogger.tag('Notif');

  bool _initialized = false;
  StreamSubscription<String>? _tokenSub;

  static const _channelId = 'apexrun_default';
  static const _channelName = 'ApexRun';
  static const _channelDesc = 'Run reminders, streak warnings, achievements';

  static const int streakWarningNotificationId = 1001;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();

    await _initLocal();
    await _initPush();
  }

  // ── Local notifications ────────────────────────────────────────────

  Future<void> _initLocal() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );

    final androidImpl = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    ));
  }

  /// Schedule (or reschedule) tonight's streak warning at the given local time.
  /// If a warning is already scheduled for today it's replaced.
  Future<void> scheduleStreakWarning({
    required int currentStreak,
    int hour = 20,
    int minute = 0,
  }) async {
    if (!_initialized || currentStreak < 3) return;
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (when.isBefore(now)) {
      // Already past warning time today; skip.
      return;
    }

    await _local.zonedSchedule(
      streakWarningNotificationId,
      "Don't break your $currentStreak-day streak",
      'Log any activity by midnight — even a 1 km walk counts.',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelStreakWarning() =>
      _local.cancel(streakWarningNotificationId);

  // ── Push notifications ─────────────────────────────────────────────

  Future<void> _initPush() async {
    if (kIsWeb) return; // no FCM on web for this app surface

    try {
      // Android 13+ requires POST_NOTIFICATIONS at runtime. Use permission_handler
      // so the prompt is consistent with the rest of the app's permission UX,
      // and so we can detect permanently-denied state (must send user to
      // system settings; OS won't re-prompt).
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final status = await ph.Permission.notification.status;
        if (status.isDenied) {
          final result = await ph.Permission.notification.request();
          if (result.isPermanentlyDenied) {
            _log.w('Notifications permanently denied — push disabled');
            return;
          }
          if (!result.isGranted) {
            _log.w('Notifications not granted — push disabled');
            return;
          }
        } else if (status.isPermanentlyDenied) {
          _log.w('Notifications permanently denied — push disabled');
          return;
        }
      }

      final messaging = FirebaseMessaging.instance;

      // iOS-style permission request (also a no-op extra check on Android).
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _log.i('Push auth status: ${settings.authorizationStatus.name}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      _tokenSub?.cancel();
      _tokenSub = messaging.onTokenRefresh.listen(_registerToken);

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    } catch (e, st) {
      _log.w('Push init failed (Firebase not configured?)', error: e, stackTrace: st);
    }
  }

  Future<void> _registerToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await _supabase.from('push_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'platform': platform,
        'app_version': Env.appVersion,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,token');
      _log.i('Push token registered ($platform)');
    } catch (e, st) {
      _log.w('Failed to upsert push token', error: e, stackTrace: st);
    }
  }

  /// When the app is foreground, FCM doesn't auto-display. Show a local
  /// notification so the user still sees the alert.
  Future<void> _handleForegroundMessage(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;
    await _local.show(
      msg.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
  }
}
