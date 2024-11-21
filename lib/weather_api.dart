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
          "description": data["weather"][0]["description"],//天気の説明を取得
          "temperature": data["main"]["temp"]//温度を取得
        };
      } else {
        throw Exception("気象データの読み込みに失敗しました");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }
}