import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:thunder_cloud_app/constants/weather_constants.dart';

/// Open-Meteo API を使用して天候データを取得するクラス。
/// OpenWeatherMap APIは削除し、Open-Meteoのみを使用します。
class WeatherApi {
  static const String baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static List<double> get searchDistances => WeatherConstants.getAllSearchDistances();
  static double get latitudePerDegreeKm => WeatherConstants.latitudePerDegreeKm;
  /// 指定した緯度・経度の天候データを取得するメソッド。
  /// [latitude]: 緯度
  /// [longitude]: 経度
  /// 戻り値: 天候データを含むマップ
  Future<Map<String, dynamic>> fetchWeather(
      double latitude, double longitude) async {
    try {
      log("Open-Meteo API取得 (緯度: $latitude, 経度: $longitude)");
      
      // Open-Meteo APIのURL構築
      final url = Uri.parse('$baseUrl?'
          'latitude=$latitude&'
          'longitude=$longitude&'
          'current=temperature_2m,relative_humidity_2m,surface_pressure,cloud_cover,weather_code&'
          'hourly=cape,lifted_index,convective_inhibition&'
          'timezone=auto&'
          'forecast_days=1');

      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        log("タイムアウトエラー: Open-Meteo APIリクエストが15秒以内に完了しませんでした");
        throw Exception("タイムアウトエラー: Open-Meteo APIリクエストが15秒以内に完了しませんでした");
      });

      if (response.statusCode == 200) {
        return _parseOpenMeteoResponse(response.body);
      } else {
        log("Open-Meteo APIエラー: ステータスコード ${response.statusCode}, レスポンス: ${response.body}");
        throw Exception("Open-Meteo APIエラー: ステータスコード ${response.statusCode}");
      }
    } catch (e) {
      log("Open-Meteo API取得エラー: $e");
      rethrow;
    }
  }

  /// Open-Meteo APIレスポンスを解析するメソッド
  Map<String, dynamic> _parseOpenMeteoResponse(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      final current = data['current'];
      final hourly = data['hourly'];
      const currentIndex = 0;

      // Open-Meteoのweather_codeから天気状態を判定
      final weatherCode = current['weather_code'] ?? 0;
      final weatherInfo = _interpretWeatherCode(weatherCode);

      final parsedData = {
        // 基本データ
        "humidity": current['relative_humidity_2m']?.toDouble() ?? 50.0,
        "weather": weatherInfo['main'],
        "detailed_weather": weatherInfo['description'],
        "clouds": current['cloud_cover']?.toDouble() ?? 0.0,
        "atmospheric_pressure": current['surface_pressure']?.toDouble() ?? 1013.25,
        "temperature": current['temperature_2m']?.toDouble() ?? 20.0,
        
        // 高度気象データ
        "cape": hourly['cape']?[currentIndex]?.toDouble() ?? 0.0,
        "lifted_index": hourly['lifted_index']?[currentIndex]?.toDouble() ?? 2.0,
        "convective_inhibition": hourly['convective_inhibition']?[currentIndex]?.toDouble() ?? 100.0,
      };

      // デバッグログ
      log("=== Open-Meteo解析データ ===");
      log("天気コード: $weatherCode (${weatherInfo['main']})");
      log("気温: ${parsedData['temperature']}°C");
      log("湿度: ${parsedData['humidity']}%");
      log("雲量: ${parsedData['clouds']}%");
      log("CAPE: ${parsedData['cape']} J/kg");
      log("LI: ${parsedData['lifted_index']}");
      log("CIN: ${parsedData['convective_inhibition']} J/kg");

      return parsedData;
    } catch (e) {
      log("Open-Meteoレスポンス解析エラー: $e");
      rethrow;
    }
  }

  /// Open-Meteoの天気コードを解釈するメソッド
  Map<String, String> _interpretWeatherCode(int weatherCode) {
    switch (weatherCode) {
      // 晴天
      case 0:
        return {'main': 'Clear', 'description': 'clear sky'};
      case 1:
      case 2:
      case 3:
        return {'main': 'Clouds', 'description': 'partly cloudy'};
      
      // 霧
      case 45:
      case 48:
        return {'main': 'Mist', 'description': 'fog'};
      
      // 小雨
      case 51:
      case 53:
      case 55:
        return {'main': 'Drizzle', 'description': 'drizzle'};
      
      // 雨
      case 61:
      case 63:
      case 65:
        return {'main': 'Rain', 'description': 'rain'};
      
      // 激しい雨
      case 80:
      case 81:
      case 82:
        return {'main': 'Rain', 'description': 'heavy rain'};
      
      // 雷雨
      case 95:
        return {'main': 'Thunderstorm', 'description': 'thunderstorm'};
      case 96:
      case 99:
        return {'main': 'Thunderstorm', 'description': 'thunderstorm with hail'};
      
      // 雪
      case 71:
      case 73:
      case 75:
      case 77:
        return {'main': 'Snow', 'description': 'snow'};
      
      // その他
      default:
        return {'main': 'Unknown', 'description': 'unknown weather'};
    }
  }
}