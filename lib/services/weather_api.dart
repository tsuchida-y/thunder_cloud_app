import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

class WeatherApi {
  final String apiKey = "4647b7a69711570dbc2b475779b61ded"; // OpenWeatherMapで取得したAPIキーを設定
  static const double distanceKm = 30.0; // 入道雲を探す距離 (km)

  Future<Map<String, dynamic>> fetchWeather(double latitude, double longitude) async {
    try {
      log("api取得 (緯度経度)");
      // APIエンドポイント
      final url =//// OpenWeatherMapで取得したAPIキーを設定
          "https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric";
      
      // HTTP GETリクエストを非同期に送信し、そのレスポンスを取得する
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {  
        // HTTPレスポンスのボディをJSON形式からDartのオブジェクトにデコード
        final data = jsonDecode(response.body);
        return {
          "humidity": data["main"]["humidity"], // 湿度を取得
          "weather": data["weather"][0]["main"], // 天気を取得
          "detailed_weather": data["weather"][0]["description"], // 詳しい天気を取得
          "clouds": data["clouds"]["all"], // 雲の量を取得
          "atmospheric_pressure": data["main"]["pressure"], // 大気圧を取得
          "temperature": data["main"]["temp"], // 追加
        };
      } else {
        throw Exception("気象データの読み込みに失敗しました (Status Code: ${response.statusCode})");
      }
    } catch (e) {
      throw Exception("Error fetching weather by coordinates: $e");
    }
  }
  // 北方向の天候を取得
  Future<Map<String, dynamic>> fetchNorthWeather(double currentLatitude, double currentLongitude) async {
    const double latitudeOffset = distanceKm / 111.0; // 緯度1度あたり約111km
    return fetchWeather(currentLatitude + latitudeOffset, currentLongitude);
  }

  // 南方向の天候を取得
  Future<Map<String, dynamic>> fetchSouthWeather(double currentLatitude, double currentLongitude) async {
    const double latitudeOffset = distanceKm / 111.0;
    return fetchWeather(currentLatitude - latitudeOffset, currentLongitude);
  }

  // 東方向の天候を取得
  Future<Map<String, dynamic>> fetchEastWeather(double currentLatitude, double currentLongitude) async {
    // 経度1度あたりの距離は緯度によって変わるため、簡易的な計算
    final double longitudeOffset = distanceKm / (111.0 * math.cos(currentLatitude * math.pi / 180.0));
    return fetchWeather(currentLatitude, currentLongitude + longitudeOffset);
  }

  // 西方向の天候を取得
  Future<Map<String, dynamic>> fetchWestWeather(double currentLatitude, double currentLongitude) async {
    final double longitudeOffset = distanceKm / (111.0 * math.cos(currentLatitude * math.pi / 180.0));
    return fetchWeather(currentLatitude, currentLongitude - longitudeOffset);
  }
}