import 'weather/weather_logic.dart';

///入力：現在地の経度と緯度
///出力：入道雲がある方向のリスト
class WeatherService {
  static Future<List<String>> getThunderCloudDirections(
    double latitude, 
    double longitude
  ) async {
    return await fetchWeatherInDirections(latitude, longitude);
  }
}