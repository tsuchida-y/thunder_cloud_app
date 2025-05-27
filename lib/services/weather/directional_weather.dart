import 'dart:math' as math;
import 'package:thunder_cloud_app/services/weather/weather_api.dart';



///指定方向の天気情報を取得するクラス
class DirectionalWeather {
  final WeatherApi weatherApi;

  DirectionalWeather(this.weatherApi);

  static const double distanceKm = WeatherApi.distanceKm;
  static const double latitudePerDegreeKm = WeatherApi.latitudePerDegreeKm;

  /// 指定した方向の天候を取得
  ///
  /// [direction]: 方向を指定する文字列 ("north", "south", "east", "west")。
  /// [currentLatitude]: 現在の緯度。
  /// [currentLongitude]: 現在の経度。
  /// 戻り値: 指定した方向の天候データを含むマップ。
  Future<Map<String, dynamic>> fetchWeatherInDirection(
      String direction, double currentLatitude, double currentLongitude) async {
    double latitudeOffset = 0.0;
    double longitudeOffset = 0.0;

    switch (direction.toLowerCase()) {
      case "north":
        latitudeOffset = distanceKm / latitudePerDegreeKm;
        break;
      case "south":
        latitudeOffset = -distanceKm / latitudePerDegreeKm;
        break;
      case "east":
        longitudeOffset = distanceKm /
            (latitudePerDegreeKm * math.cos(currentLatitude * math.pi / 180.0));
        break;
      case "west":
        longitudeOffset = -distanceKm /
            (latitudePerDegreeKm * math.cos(currentLatitude * math.pi / 180.0));
        break;
      default:
        throw ArgumentError("無効な方向: $direction");
    }

    return weatherApi.fetchWeather(
        currentLatitude + latitudeOffset, currentLongitude + longitudeOffset);
  }
}
