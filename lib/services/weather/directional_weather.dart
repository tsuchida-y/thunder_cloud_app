import 'dart:math' as math;
import 'package:thunder_cloud_app/services/weather/weather_api.dart';

class DirectionalWeather {
  final WeatherApi weatherApi;

  DirectionalWeather(this.weatherApi);

  static const double distanceKm = WeatherApi.distanceKm;
  static const double latitudePerDegreeKm = WeatherApi.latitudePerDegreeKm;

  /// 北方向の天候を取得
  Future<Map<String, dynamic>> fetchNorthWeather(
      double currentLatitude, double currentLongitude) async {
    const double latitudeOffset = distanceKm / latitudePerDegreeKm;
    return weatherApi.fetchWeather(
        currentLatitude + latitudeOffset, currentLongitude);
  }

  /// 南方向の天候を取得
  Future<Map<String, dynamic>> fetchSouthWeather(
      double currentLatitude, double currentLongitude) async {
    const double latitudeOffset = distanceKm / latitudePerDegreeKm;
    return weatherApi.fetchWeather(
        currentLatitude - latitudeOffset, currentLongitude);
  }

  /// 東方向の天候を取得
  Future<Map<String, dynamic>> fetchEastWeather(
      double currentLatitude, double currentLongitude) async {
    final double longitudeOffset = distanceKm /
        (latitudePerDegreeKm * math.cos(currentLatitude * math.pi / 180.0));
    return weatherApi.fetchWeather(
        currentLatitude, currentLongitude + longitudeOffset);
  }

  /// 西方向の天候を取得
  Future<Map<String, dynamic>> fetchWestWeather(
      double currentLatitude, double currentLongitude) async {
    final double longitudeOffset = distanceKm /
        (latitudePerDegreeKm * math.cos(currentLatitude * math.pi / 180.0));
    return weatherApi.fetchWeather(
        currentLatitude, currentLongitude - longitudeOffset);
  }
}
