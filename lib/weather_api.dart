import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherApi {
  final String apiKey = "4647b7a69711570dbc2b475779b61ded"; // OpenWeatherMapで取得したAPIキーを設定

  Future<Map<String, dynamic>> fetchWeather(String cityName) async {
    try {
      
      // APIエンドポイント
      final url =//// OpenWeatherMapで取得したAPIキーを設定
          "https://api.openweathermap.org/data/2.5/weather?q=$cityName&appid=$apiKey&units=metric";
      
      // HTTP GETリクエストを非同期に送信し、そのレスポンスを取得する
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {  
        // HTTPレスポンスのボディをJSON形式からDartのオブジェクトにデコード
        final data = jsonDecode(response.body);
        return {
          "humidity":data["main"]["humidity"],//湿度を取得
          "weather":data["weather"][0]["main"],//天気を取得
          "detailed_weather":data["weather"][0]["description"],//詳しい天気を取得
          "clouds":data["clouds"]["all"],//雲の量を取得
          "atmospheric_pressure":data["main"]["pressure"],//大気圧を取得
        };
      } else {
        throw Exception("気象データの読み込みに失敗しました");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }
}