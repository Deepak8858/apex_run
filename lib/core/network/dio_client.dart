import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../logger/app_logger.dart';
import 'api_exceptions.dart';

class DioClient {
  static Dio? _instance;
  static final _log = AppLogger.tag('Http');

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  /// Reset instance (testing or URL changes only).
  static void reset() {
    _instance = null;
  }

  static String get _effectiveBaseUrl => Env.backendApiUrl;

  static Dio _createDio() {
    final baseUrl = _effectiveBaseUrl;
    _log.i('Initializing Dio (base=$baseUrl)');

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(_AuthInterceptor());
    dio.interceptors.add(_LoggingInterceptor());

    // Pin backend certificate chain when fingerprints are provided.
    // Build with --dart-define=BACKEND_CERT_SHA256_FINGERPRINTS=<pin1>,<pin2>
    // (two pins so cert rotation does not brick the app).
    final pins = Env.backendCertSha256Fingerprints;
    if (pins.isNotEmpty) {
      final fingerprints =
          pins.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();

      final adapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) {
            // Compute SHA-256 over the DER-encoded leaf cert + base64 it.
            final sha = base64Encode(sha256.convert(cert.der).bytes);
            final ok = fingerprints.contains(sha);
            if (!ok) {
              _log.w('Cert pin mismatch for $host (got $sha)');
            }
            return ok;
          };
          return client;
        },
      );
      dio.httpClientAdapter = adapter;
      _log.i('Certificate pinning ENABLED (${fingerprints.length} pins)');
    } else {
      _log.w('Certificate pinning DISABLED (no fingerprints configured)');
    }

    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  static Completer<Session?>? _refreshInFlight;
  static final _log = AppLogger.tag('Auth.http');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    var session = Supabase.instance.client.auth.currentSession;

    if (session != null && session.isExpired) {
      session = await _singleFlightRefresh();
    }

    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }

  /// Single-flight token refresh: concurrent expired-token requests
  /// share one refresh call instead of stampeding the auth endpoint.
  Future<Session?> _singleFlightRefresh() async {
    final pending = _refreshInFlight;
    if (pending != null) return pending.future;

    final completer = Completer<Session?>();
    _refreshInFlight = completer;
    try {
      final refreshed = await Supabase.instance.client.auth.refreshSession();
      _log.i('Token refresh OK');
      completer.complete(refreshed.session);
      return refreshed.session;
    } catch (e, st) {
      _log.w('Token refresh failed', error: e, stackTrace: st);
      completer.complete(null);
      return null;
    } finally {
      _refreshInFlight = null;
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.response?.statusCode) {
      case 401:
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: const UnauthorizedException('Authentication required'),
          type: DioExceptionType.badResponse,
        ));
        return;
      case 404:
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: const NotFoundException('Resource not found'),
          type: DioExceptionType.badResponse,
        ));
        return;
    }

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      handler.reject(DioException(
        requestOptions: err.requestOptions,
        error: const NetworkException('Network connection failed'),
        type: err.type,
      ));
      return;
    }

    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  static final _log = AppLogger.tag('Http');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log.i('${options.method} ${options.uri.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log.i('${response.statusCode} ${response.requestOptions.uri.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log.w('${err.response?.statusCode ?? '-'} ${err.requestOptions.uri.path}: ${err.message ?? err.type.name}');
    handler.next(err);
  }
}
