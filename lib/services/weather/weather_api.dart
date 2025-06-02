import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

/// Open-Meteo API を使用して天候データを取得する統合クラス
class WeatherApi {
  static const String baseUrl = 'https://api.open-meteo.com/v1/forecast';
  

  /// ⚡ 積乱雲判定専用データ取得 (weather_logic用)
  static Future<Map<String, dynamic>> fetchThunderCloudData(
      double latitude, double longitude) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final url = Uri.parse('$baseUrl?'
          'latitude=${latitude.toStringAsFixed(6)}&'
          'longitude=${longitude.toStringAsFixed(6)}&'
          'hourly=cape,lifted_index,convective_inhibition&'
          'current=temperature_2m&'
          'timezone=auto&'
          'forecast_days=1&'
          '_t=$timestamp');

      log("🌐 ThunderCloud API URL: $url");

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception("ThunderCloud API タイムアウト"));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        log("📥 ThunderCloud API Response (${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}):");
        log("  Body length: ${response.body.length} chars");

        return _parseThunderCloudResponse(data);
      } else {
        throw Exception('ThunderCloud API エラー: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ ThunderCloud API 例外: $e");
      rethrow;
    }
  }


  /// ⚡ 積乱雲専用データ解析
  static Map<String, dynamic> _parseThunderCloudResponse(Map<String, dynamic> data) {
    final current = data['current'];
    final hourly = data['hourly'];
    const currentIndex = 0;

    return {
      'temperature': current['temperature_2m']?.toDouble() ?? 20.0,
      'humidity': current['relative_humidity_2m']?.toDouble() ?? 50.0,
      'pressure': current['surface_pressure']?.toDouble() ?? 1013.25,
      'cape': hourly['cape']?[currentIndex]?.toDouble() ?? 0.0,
      'lifted_index': hourly['lifted_index']?[currentIndex]?.toDouble() ?? 2.0,
      'convective_inhibition': hourly['convective_inhibition']?[currentIndex]?.toDouble() ?? 100.0,
    };
  }
}