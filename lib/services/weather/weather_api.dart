import 'dart:convert';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:thunder_cloud_app/exception/weatherapi_exc.dart';

class WeatherApi {
  /// OpenWeatherMap API を使用して天候データを取得するクラス。
  ///
  /// このクラスは、指定した緯度・経度の天候データを取得するほか、
  /// 東西南北それぞれ30km離れた地点の天候データを取得するメソッドを提供します。
  ///

  final String apiKey = dotenv.env['OpenWhetherAPI_Key'] ?? '';
  static const double distanceKm = 30.0; // 入道雲を探す距離 (km)
  static const double latitudePerDegreeKm = 111.0; //緯度1度あたり約111km

  Future<Map<String, dynamic>> fetchWeather(
      double latitude, double longitude) async {
    /// 指定した緯度・経度の天候データを取得します。
    ///
    /// [latitude]: 緯度
    /// [longitude]: 経度
    /// 戻り値: 天候データを含むマップ

    try {
      log("api取得 (緯度経度)");
      final url =
          "https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric";

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "humidity": data["main"]["humidity"],
          "weather": data["weather"][0]["main"],
          "detailed_weather": data["weather"][0]["description"],
          "clouds": data["clouds"]["all"],
          "atmospheric_pressure": data["main"]["pressure"],
          "temperature": data["main"]["temp"],
        };
      } else {
        log("APIエラー: ステータスコード ${response.statusCode}, レスポンス: ${response.body}");
        throw WeatherApiException("APIエラー: ステータスコード ${response.statusCode}");
      }
    } on FormatException catch (e) {
      log("デコードエラー: $e");
      throw WeatherApiException("デコードエラー: $e");
    } on http.ClientException catch (e) {
      log("ネットワークエラー: $e");
      throw WeatherApiException("ネットワークエラー: $e");
    } catch (e) {
      log("不明なエラー: $e");
      throw WeatherApiException("不明なエラー: $e");
    }
  }
}
