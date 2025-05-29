import 'weather/weather_logic.dart';

class WeatherService {
  /// 高度な入道雲方向取得
  static Future<List<String>> getAdvancedThunderCloudDirections(
    double latitude, 
    double longitude
  ) async {
    return await fetchAdvancedWeatherInDirections(latitude, longitude);
  }
  
  /// 従来の入道雲方向取得（フォールバック）
  static Future<List<String>> getThunderCloudDirections(
    double latitude, 
    double longitude
  ) async {
    return await fetchWeatherInDirections(latitude, longitude);
  }
}