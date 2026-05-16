import 'dart:async';

import 'package:app_links/app_links.dart';

import '../../core/logger/app_logger.dart';

/// Centralized deep-link / universal-link router.
///
/// Routes handled:
///   apexrun://login-callback                — Supabase OAuth (handled by Supabase SDK)
///   apexrun://reset-password                — Supabase reset (handled by Supabase SDK)
///   apexrun://r/[CODE]                      — referral redemption
///   https://apexrun.app/r/[CODE]            — referral (universal link)
///   apexrun://activity/[ID]                 — open activity detail
///   apexrun://challenge/[CODE]              — open challenge
///   apexrun://friend/[USER_ID]              — friend profile
///
/// Subscribe via [stream]; the consumer decides navigation. We only parse.
class DeepLinkService {
  DeepLinkService();

  final AppLinks _appLinks = AppLinks();
  final _log = AppLogger.tag('DeepLink');
  final _controller = StreamController<DeepLinkAction>.broadcast();
  StreamSubscription<Uri>? _sub;

  Stream<DeepLinkAction> get stream => _controller.stream;

  Future<void> init() async {
    // Cold-start link (app opened from a tap while killed).
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _route(initial);
    } catch (e, st) {
      _log.w('Initial link failed', error: e, stackTrace: st);
    }

    // Warm links (app already running).
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      _route,
      onError: (Object e, StackTrace st) =>
          _log.w('uriLinkStream error', error: e, stackTrace: st),
    );
  }

  void _route(Uri uri) {
    _log.i('Routing ${uri.scheme}://${uri.host}${uri.path}');

    // apexrun://r/CODE  OR  https://apexrun.app/r/CODE
    if ((uri.scheme == 'apexrun' && uri.host == 'r') ||
        (uri.host == 'apexrun.app' && uri.pathSegments.firstOrNull == 'r')) {
      final code = uri.scheme == 'apexrun'
          ? uri.pathSegments.firstOrNull
          : uri.pathSegments.elementAtOrNull(1);
      if (code != null && code.isNotEmpty) {
        _controller.add(DeepLinkAction.referral(code));
        return;
      }
    }

    if (uri.scheme == 'apexrun' && uri.host == 'activity') {
      final id = uri.pathSegments.firstOrNull;
      if (id != null) {
        _controller.add(DeepLinkAction.activity(id));
        return;
      }
    }

    if (uri.scheme == 'apexrun' && uri.host == 'challenge') {
      final code = uri.pathSegments.firstOrNull;
      if (code != null) {
        _controller.add(DeepLinkAction.challenge(code));
        return;
      }
    }

    if (uri.scheme == 'apexrun' && uri.host == 'friend') {
      final userId = uri.pathSegments.firstOrNull;
      if (userId != null) {
        _controller.add(DeepLinkAction.friend(userId));
        return;
      }
    }

    // Login-callback + reset-password handled by Supabase SDK already.
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}

class DeepLinkAction {
  const DeepLinkAction._(this.kind, {this.value});

  factory DeepLinkAction.referral(String code) =>
      DeepLinkAction._(DeepLinkKind.referral, value: code);
  factory DeepLinkAction.activity(String id) =>
      DeepLinkAction._(DeepLinkKind.activity, value: id);
  factory DeepLinkAction.challenge(String code) =>
      DeepLinkAction._(DeepLinkKind.challenge, value: code);
  factory DeepLinkAction.friend(String userId) =>
      DeepLinkAction._(DeepLinkKind.friend, value: userId);

  final DeepLinkKind kind;
  final String? value;
}

enum DeepLinkKind { referral, activity, challenge, friend }
