import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geolocator/geolocator.dart';

part 'gps_point.freezed.dart';
part 'gps_point.g.dart';

@freezed
class GpsPoint with _$GpsPoint {
  const factory GpsPoint({
    required double latitude,
    required double longitude,
    @Default(0.0) double altitude,
    @Default(0.0) double accuracy,
    @Default(0.0) double speed,
    required DateTime timestamp,
  }) = _GpsPoint;

  factory GpsPoint.fromJson(Map<String, dynamic> json) =>
      _$GpsPointFromJson(json);

  factory GpsPoint.fromPosition(Position position) => GpsPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        speed: position.speed,
        timestamp: position.timestamp,
      );
}
