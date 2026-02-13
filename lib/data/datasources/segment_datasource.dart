import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/segment.dart';
import '../../domain/models/segment_effort.dart';

/// Custom exception for segment-specific errors with user-friendly messages
class SegmentException implements Exception {
  final String message;
  final String userMessage;
  final bool isRetryable;

  const SegmentException({
    required this.message,
    required this.userMessage,
    this.isRetryable = true,
  });

  @override
  String toString() => 'SegmentException: $message';
}

class SegmentDataSource {
  final Dio _dio;

  SegmentDataSource(this._dio);

  /// Get list of segments, optionally filtered by proximity
  Future<List<Segment>> getSegments({
    double? nearLat,
    double? nearLng,
    double? radiusKm,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (nearLat != null) queryParams['near_lat'] = nearLat;
      if (nearLng != null) queryParams['near_lng'] = nearLng;
      if (radiusKm != null) queryParams['radius_km'] = radiusKm;

      final response = await _dio.get(
        '/api/v1/segments',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data == null || data['segments'] == null) {
        return [];
      }

      return (data['segments'] as List)
          .map((json) => Segment.fromSupabaseJson(json))
          .toList();
    } on DioException catch (e) {
      throw _mapDioError(e, 'loading segments');
    } catch (e) {
      if (e is SegmentException) rethrow;
      debugPrint('Unexpected segment error: $e');
      throw SegmentException(
        message: e.toString(),
        userMessage: 'Something went wrong loading segments.',
      );
    }
  }

  /// Get segment by ID
  Future<Segment> getSegmentById(String id) async {
    try {
      final response = await _dio.get('/api/v1/segments/$id');
      return Segment.fromSupabaseJson(response.data);
    } on DioException catch (e) {
      throw _mapDioError(e, 'loading segment details');
    } catch (e) {
      if (e is SegmentException) rethrow;
      throw SegmentException(
        message: e.toString(),
        userMessage: 'Could not load segment details.',
      );
    }
  }

  /// Get leaderboard for a segment
  Future<List<SegmentEffort>> getLeaderboard(
    String segmentId, {
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/segments/$segmentId/leaderboard',
        queryParameters: {'limit': limit},
      );

      final data = response.data;
      if (data == null || data['leaderboard'] == null) {
        return [];
      }

      return (data['leaderboard'] as List)
          .map((json) => SegmentEffort.fromSupabaseJson(json))
          .toList();
    } on DioException catch (e) {
      throw _mapDioError(e, 'loading leaderboard');
    } catch (e) {
      if (e is SegmentException) rethrow;
      throw SegmentException(
        message: e.toString(),
        userMessage: 'Could not load leaderboard.',
      );
    }
  }

  /// Match segments for an activity (called after saving)
  Future<List<Map<String, dynamic>>> matchSegments(
      String activityId) async {
    try {
      final response = await _dio.post(
        '/api/v1/segments/match',
        data: {'activity_id': activityId},
      );

      final data = response.data;
      if (data == null || data['matches'] == null) {
        return [];
      }

      return (data['matches'] as List)
          .map((json) => Map<String, dynamic>.from(json))
          .toList();
    } on DioException catch (e) {
      throw _mapDioError(e, 'matching segments');
    } catch (e) {
      if (e is SegmentException) rethrow;
      throw SegmentException(
        message: e.toString(),
        userMessage: 'Could not match segments for this activity.',
      );
    }
  }

  /// Map Dio errors to user-friendly SegmentException
  SegmentException _mapDioError(DioException e, String action) {
    debugPrint('[Segments] DioException while $action: ${e.type} - ${e.message}');

    // Check for wrapped API exceptions from the Dio interceptor
    if (e.error is UnauthorizedException) {
      return SegmentException(
        message: 'Auth error: ${e.error}',
        userMessage: 'Your session has expired. Please sign in again.',
        isRetryable: false,
      );
    }

    if (e.error is NotFoundException) {
      return SegmentException(
        message: 'Not found: ${e.error}',
        userMessage: 'The requested segment was not found.',
        isRetryable: false,
      );
    }

    if (e.error is NetworkException) {
      return SegmentException(
        message: 'Network error: ${e.error}',
        userMessage: 'No internet connection. Check your network and try again.',
      );
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return SegmentException(
          message: 'Timeout: ${e.message}',
          userMessage: 'The server is taking too long to respond. Try again shortly.',
        );
      case DioExceptionType.connectionError:
        return SegmentException(
          message: 'Connection error: ${e.message}',
          userMessage: 'Could not connect to the server. Check your internet connection.',
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        if (statusCode >= 500) {
          return SegmentException(
            message: 'Server error $statusCode',
            userMessage: 'The segment server is experiencing issues. Try again later.',
          );
        }
        return SegmentException(
          message: 'Bad response $statusCode: ${e.message}',
          userMessage: 'Something went wrong while $action.',
        );
      default:
        return SegmentException(
          message: 'Unknown Dio error: ${e.type} - ${e.message}',
          userMessage: 'Could not load data. Please try again.',
        );
    }
  }
}
