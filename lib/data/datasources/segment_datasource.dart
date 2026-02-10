import 'package:dio/dio.dart';
import '../../domain/models/segment.dart';
import '../../domain/models/segment_effort.dart';

class SegmentDataSource {
  final Dio _dio;

  SegmentDataSource(this._dio);

  /// Get list of segments, optionally filtered by proximity
  Future<List<Segment>> getSegments({
    double? nearLat,
    double? nearLng,
    double? radiusKm,
  }) async {
    final queryParams = <String, dynamic>{};
    if (nearLat != null) queryParams['near_lat'] = nearLat;
    if (nearLng != null) queryParams['near_lng'] = nearLng;
    if (radiusKm != null) queryParams['radius_km'] = radiusKm;

    final response = await _dio.get(
      '/api/v1/segments',
      queryParameters: queryParams,
    );

    return (response.data['segments'] as List)
        .map((json) => Segment.fromSupabaseJson(json))
        .toList();
  }

  /// Get segment by ID
  Future<Segment> getSegmentById(String id) async {
    final response = await _dio.get('/api/v1/segments/$id');
    return Segment.fromSupabaseJson(response.data);
  }

  /// Get leaderboard for a segment
  Future<List<SegmentEffort>> getLeaderboard(
    String segmentId, {
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/api/v1/segments/$segmentId/leaderboard',
      queryParameters: {'limit': limit},
    );

    return (response.data['leaderboard'] as List)
        .map((json) => SegmentEffort.fromSupabaseJson(json))
        .toList();
  }

  /// Match segments for an activity (called after saving)
  Future<List<Map<String, dynamic>>> matchSegments(
      String activityId) async {
    final response = await _dio.post(
      '/api/v1/segments/match',
      data: {'activity_id': activityId},
    );

    return (response.data['matches'] as List)
        .map((json) => Map<String, dynamic>.from(json))
        .toList();
  }
}
