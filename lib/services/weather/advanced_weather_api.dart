import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

/// Open-Meteo APIを使用した高度な気象データ取得クラス
class AdvancedWeatherApi {
  static const String baseUrl = 'https://api.open-meteo.com/v1/forecast';
  
  /// 積乱雲判定に必要な気象パラメータを取得
  Future<Map<String, dynamic>> fetchAdvancedWeatherData(
    double latitude, 
    double longitude
  ) async {
    try {
      log("高度気象データ取得中: lat=$latitude, lon=$longitude");
      
      // Open-Meteo APIから積乱雲判定に必要なパラメータを取得
      final url = Uri.parse('$baseUrl?'
          'latitude=$latitude&'
          'longitude=$longitude&'
          'current=temperature_2m,relative_humidity_2m,surface_pressure&'
          'hourly=cape,lifted_index,convective_inhibition&'
          'timezone=auto&'
          'forecast_days=1');

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception("Advanced weather API timeout");
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseAdvancedWeatherData(data);
      } else {
        throw Exception("Advanced API error: ${response.statusCode}");
      }
    } catch (e) {
      log("Advanced weather API error: $e");
      rethrow;
    }
  }

  /// Open-Meteo APIレスポンスを解析
  Map<String, dynamic> _parseAdvancedWeatherData(Map<String, dynamic> data) {
    final current = data['current'];
    final hourly = data['hourly'];
    
    // 現在時刻のデータを取得（配列の最初の要素）
    const currentIndex = 0;

    return {
      // 基本パラメータ
      'temperature': current['temperature_2m']?.toDouble() ?? 20.0,
      'humidity': current['relative_humidity_2m']?.toDouble() ?? 50.0,
      'pressure': current['surface_pressure']?.toDouble() ?? 1013.25,
      
      // 積乱雲判定用高度パラメータ
      'cape': hourly['cape']?[currentIndex]?.toDouble() ?? 0.0,
      'lifted_index': hourly['lifted_index']?[currentIndex]?.toDouble() ?? 2.0,
      'convective_inhibition': hourly['convective_inhibition']?[currentIndex]?.toDouble() ?? 100.0,
    };
  }
}