import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

class AdvancedWeatherApi {
  static const String baseUrl = 'https://api.open-meteo.com/v1/forecast';

  static Future<Map<String, dynamic>> fetchAdvancedWeatherData(
      double latitude, double longitude) async {
    try {
      // ✅ キャッシュ回避のためタイムスタンプを追加
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final url = Uri.parse('$baseUrl?'
          'latitude=${latitude.toStringAsFixed(6)}&' // ✅ 精度向上
          'longitude=${longitude.toStringAsFixed(6)}&' // ✅ 精度向上
          'hourly=cape,lifted_index,convective_inhibition&'
          'current=temperature_2m&'
          'timezone=auto&'
          'forecast_days=1&'
          '_t=$timestamp'); // ✅ キャッシュバスター追加

      log("🌐 Advanced Weather API URL: $url");

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception("Advanced Weather API タイムアウト");
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // ✅ レスポンスデータのログ追加
        log("📥 API Response (${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}):");
        log("  Body length: ${response.body.length} chars");

        return _parseAdvancedWeatherData(data);
      } else {
        throw Exception('Advanced Weather API エラー: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Advanced Weather API 例外: $e");
      rethrow;
    }
  }

  static Map<String, dynamic> _parseAdvancedWeatherData(Map<String, dynamic> data) {
    final current = data['current'];
    final hourly = data['hourly'];
    const currentIndex = 0;

    return {
      'temperature': current['temperature_2m']?.toDouble() ?? 20.0,
      'humidity': current['relative_humidity_2m']?.toDouble() ?? 50.0,
      'pressure': current['surface_pressure']?.toDouble() ?? 1013.25,
      'cape': hourly['cape']?[currentIndex]?.toDouble() ?? 0.0,
      'lifted_index': hourly['lifted_index']?[currentIndex]?.toDouble() ?? 2.0,
      'convective_inhibition':
          hourly['convective_inhibition']?[currentIndex]?.toDouble() ?? 100.0,
    };
  }
}
