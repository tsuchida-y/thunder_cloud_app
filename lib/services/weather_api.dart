import 'dart:convert';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

import 'package:thunder_cloud_app/exception/weatherapi_exc.dart';

class WeatherApi {
  /// OpenWeatherMap API を使用して天候データを取得するクラス。
  ///
  /// このクラスは、指定した緯度・経度の天候データを取得するほか、
  /// 東西南北それぞれ30km離れた地点の天候データを取得するメソッドを提供します。

  WeatherApi();
  final String apiKey = '4647b7a69711570dbc2b475779b61ded';
  static const double distanceKm = 30.0; // 入道雲を探す距離 (km)
  static const double latitudePerDegreeKm = 111.0; //緯度1度あたり約111km

  Future<Map<String, dynamic>> fetchWeather(

      /// 指定した緯度・経度の天候データを取得します。
      ///
      /// [latitude]: 緯度
      /// [longitude]: 経度
      /// 戻り値: 天候データを含むマップ

      double latitude,
      double longitude) async {
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
        throw WeatherApiException("APIエラー: ステータスコード ${response.statusCode}");
      }
    } on FormatException catch (e) {
      throw WeatherApiException("デコードエラー: $e");
    } on http.ClientException catch (e) {
      throw WeatherApiException("ネットワークエラー: $e");
    } catch (e) {
      throw WeatherApiException("不明なエラー: $e");
    }
  }

  /// 北方向に30km離れた地点の天候データを取得します。
  Future<Map<String, dynamic>> fetchNorthWeather(
      double currentLatitude, double currentLongitude) async {
    const double latitudeOffset = distanceKm / latitudePerDegreeKm;
    return fetchWeather(currentLatitude + latitudeOffset, currentLongitude);
  }

  // 南方向の天候を取得
  Future<Map<String, dynamic>> fetchSouthWeather(
      double currentLatitude, double currentLongitude) async {
    const double latitudeOffset = distanceKm / latitudePerDegreeKm;
    return fetchWeather(currentLatitude - latitudeOffset, currentLongitude);
  }

  // 東方向の天候を取得
  // 経度1度あたりの距離は緯度によって変わるため、簡易的な計算
  Future<Map<String, dynamic>> fetchEastWeather(
      double currentLatitude, double currentLongitude) async {
    final double longitudeOffset = distanceKm /
        (latitudePerDegreeKm * math.cos(currentLatitude * math.pi / 180.0));
    return fetchWeather(currentLatitude, currentLongitude + longitudeOffset);
  }

  // 西方向の天候を取得
  Future<Map<String, dynamic>> fetchWestWeather(
      double currentLatitude, double currentLongitude) async {
    final double longitudeOffset = distanceKm /
        (latitudePerDegreeKm * math.cos(currentLatitude * math.pi / 180.0));
    return fetchWeather(currentLatitude, currentLongitude - longitudeOffset);
  }
}
