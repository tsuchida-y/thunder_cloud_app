import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;


/// OpenWeatherMap API を使用して天候データを取得するクラス。
/// このクラスは、指定した緯度・経度の天候データを取得するほか、東西南北それぞれ30km離れた地点の天候データを取得するメソッドを提供します。
class WeatherApi {
  final String apiKey = dotenv.env['OpenWhetherAPI_Key'] ?? '';
  static const double distanceKm = 30.0; // 入道雲を探す距離 (km)
  static const double latitudePerDegreeKm = 111.0; //緯度1度あたり約111km

  /// API レスポンスを非同期で解析するメソッド。
  /// 戻り値: 解析された天候データを含むマップ。
  Future<Map<String, dynamic>> _parseWeatherResponse(
      String responseBody) async {
    return await compute(_decodeWeatherResponse, responseBody);
  }

  /// API レスポンスをデコードするメソッド。
  /// 戻り値: デコードされた天候データを含むマップ。
  Map<String, dynamic> _decodeWeatherResponse(String responseBody) {
    final data = jsonDecode(responseBody);
    return {
      "humidity": data["main"]["humidity"],
      "weather": data["weather"][0]["main"],
      "detailed_weather": data["weather"][0]["description"],
      "clouds": data["clouds"]["all"],
      "atmospheric_pressure": data["main"]["pressure"],
      "temperature": data["main"]["temp"],
    };
  }

  /// 指定した緯度・経度の天候データを取得するメソッド。
  /// [latitude]: 緯度
  /// [longitude]: 経度
  /// 戻り値: 天候データを含むマップ
  Future<Map<String, dynamic>> fetchWeather(
      double latitude, double longitude) async {
    try {
      log("api取得 (緯度経度)");
      final url =
          "https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric";

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10), onTimeout: () {
        log("タイムアウトエラー: リクエストが10秒以内に完了しませんでした");
        throw Exception("タイムアウトエラー: リクエストが10秒以内に完了しませんでした");
      });

      if (response.statusCode == 200) {
        return await _parseWeatherResponse(response.body);
      } else {
        log("APIエラー: ステータスコード ${response.statusCode}, レスポンス: ${response.body}");
        throw Exception("APIエラー: ステータスコード ${response.statusCode}");
      }
    } catch (e) {
      log("エラー: $e");
      rethrow;
    }
  }
}
