import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Centralized application logger.
///
/// In debug: pretty-prints to console with redaction.
/// In release: forwards warnings/errors to Sentry; drops debug/info entirely.
///
/// NEVER pass raw user input, tokens, emails, or PII through any of these
/// methods without redaction — the [_redact] pass is best-effort, not perfect.
///
/// Usage:
///   final log = AppLogger.tag('Auth');
///   log.i('Sign-in started');                          // no PII
///   log.e('Sign-in failed', error: e, stackTrace: st); // sent to Sentry in release
class AppLogger {
  AppLogger._(this._tag, this._logger);

  final String _tag;
  final Logger _logger;

  static AppLogger tag(String tag) => AppLogger._(tag, _shared);

  static final Logger _shared = Logger(
    filter: _AppLogFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 100,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    output: ConsoleOutput(),
  );

  void d(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.d(_format(message), error: error, stackTrace: stackTrace);
  }

  void i(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.i(_format(message), error: error, stackTrace: stackTrace);
  }

  void w(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.w(_format(message), error: error, stackTrace: stackTrace);
    _toSentry(SentryLevel.warning, message, error: error, stackTrace: stackTrace);
  }

  void e(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(_format(message), error: error, stackTrace: stackTrace);
    _toSentry(SentryLevel.error, message, error: error, stackTrace: stackTrace);
  }

  String _format(String message) => '[$_tag] ${_redact(message)}';

  void _toSentry(
    SentryLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kReleaseMode) return;
    if (error != null) {
      Sentry.captureException(error, stackTrace: stackTrace, hint: Hint.withMap({'message': _redact(message), 'tag': _tag}));
    } else {
      Sentry.captureMessage(_redact(message), level: level);
    }
  }
}

class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      return event.level.index >= Level.warning.index;
    }
    return true;
  }
}

/// Best-effort redaction of common PII patterns. NOT a substitute for not
/// passing PII in the first place — treat as defense-in-depth only.
String _redact(String input) {
  var out = input;
  out = out.replaceAll(_emailPattern, '<email>');
  out = out.replaceAll(_jwtPattern, '<jwt>');
  out = out.replaceAll(_bearerPattern, 'Bearer <redacted>');
  out = out.replaceAll(_uuidPattern, '<uuid>');
  return out;
}

final RegExp _emailPattern = RegExp(
  r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
);
final RegExp _jwtPattern = RegExp(
  r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',
);
final RegExp _bearerPattern = RegExp(
  r'Bearer\s+[A-Za-z0-9._\-]{20,}',
);
final RegExp _uuidPattern = RegExp(
  r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);
