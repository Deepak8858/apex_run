import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';
import 'api_exceptions.dart';

class DioClient {
  static Dio? _instance;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  /// Reset instance (useful for testing or URL changes)
  static void reset() {
    _instance = null;
  }

  /// Get the platform-appropriate backend URL.
  /// On Android emulator, localhost maps to 10.0.2.2.
  /// On iOS simulator, localhost works normally.
  static String get _effectiveBaseUrl {
    final configured = Env.backendApiUrl;

    // Only remap if it's a localhost URL and we're on a mobile platform
    if (!kIsWeb && configured.contains('localhost')) {
      try {
        if (Platform.isAndroid) {
          return configured.replaceFirst('localhost', '10.0.2.2');
        }
      } catch (_) {
        // Platform not available in some test contexts
      }
    }
    return configured;
  }

  static Dio _createDio() {
    final baseUrl = _effectiveBaseUrl;
    debugPrint('DioClient baseUrl: $baseUrl');

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(_AuthInterceptor());
    dio.interceptors.add(_LoggingInterceptor());
    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.response?.statusCode) {
      case 401:
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: const UnauthorizedException('Authentication required'),
            type: DioExceptionType.badResponse,
          ),
        );
        return;
      case 404:
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: const NotFoundException('Resource not found'),
            type: DioExceptionType.badResponse,
          ),
        );
        return;
    }

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: const NetworkException('Network connection failed'),
          type: err.type,
        ),
      );
      return;
    }

    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[API] ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('[API] ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[API ERROR] ${err.response?.statusCode} ${err.requestOptions.uri}: ${err.message}');
    handler.next(err);
  }
}
