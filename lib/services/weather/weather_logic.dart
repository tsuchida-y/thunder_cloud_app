// filepath: [weather_logic.dart](http://_vscodecontentref_/4)
import 'dart:developer';
import 'dart:math' as math;
import 'package:thunder_cloud_app/services/weather/weather_api.dart';
import 'package:thunder_cloud_app/services/weather/advanced_weather_api.dart';
import 'package:thunder_cloud_app/services/weather/thunder_cloud_analyzer.dart';

// インスタンス作成
final WeatherApi weatherApi = WeatherApi();
final AdvancedWeatherApi advancedWeatherApi = AdvancedWeatherApi();

/// 高度な入道雲判定ロジック（Open-Meteoのみ使用）
Future<bool> isAdvancedThunderCloudConditionMet(
  double latitude, 
  double longitude
) async {
  try {
    // Open-Meteo APIのみでデータ取得
    final advancedWeather = await advancedWeatherApi.fetchAdvancedWeatherData(latitude, longitude);

    // Open-Meteoデータのみで分析実行
    final assessment = ThunderCloudAnalyzer.analyzeWithMeteoDataOnly(advancedWeather);

    // 詳細ログ出力（構文エラー修正）
    log("=== 積乱雲分析結果（Open-Meteoのみ）===");
    log("総合判定: ${assessment.isThunderCloudLikely ? '積乱雲の可能性あり' : '積乱雲の可能性低い'}");
    log("総合スコア: ${(assessment.totalScore * 100).toStringAsFixed(1)}%");
    log("信頼度: ${(assessment.confidence * 100).toStringAsFixed(1)}%");
    log("リスクレベル: ${assessment.riskLevel}");

    return assessment.isThunderCloudLikely;
  } catch (e) {
    log("Open-Meteo API取得エラー: $e");
    return false;
  }
}

/// Open-Meteoのみでの方向別天気チェック（追加）
Future<List<String>> fetchAdvancedWeatherInDirections(
    double currentLatitude, double currentLongitude) async {
  List<String> tempMatchingCities = [];
  const directions = ["north", "south", "east", "west"];

  try {
    for (final direction in directions) {
      // 方向ごとの座標計算
      final coordinates = _calculateDirectionCoordinates(
          direction, currentLatitude, currentLongitude);
      
      // Open-Meteoでの積乱雲判定を実行
      final isThunderCloud = await isAdvancedThunderCloudConditionMet(
          coordinates['latitude']!, coordinates['longitude']!);
      
      log("$direction: ${isThunderCloud ? '積乱雲あり' : '積乱雲なし'}");
      
      if (isThunderCloud) {
        tempMatchingCities.add(direction);
      }
    }
  } catch (e) {
    log("Open-Meteo方向別チェックエラー: $e");
  }

  return tempMatchingCities;
}

/// 方向ごとの座標計算
Map<String, double> _calculateDirectionCoordinates(
    String direction, double currentLatitude, double currentLongitude) {
  const double distanceKm = 30.0;
  const double latitudePerDegreeKm = 111.0;
  
  double latitudeOffset = 0.0;
  double longitudeOffset = 0.0;

  switch (direction.toLowerCase()) {
    case "north":
      latitudeOffset = distanceKm / latitudePerDegreeKm;
      break;
    case "south":
      latitudeOffset = -distanceKm / latitudePerDegreeKm;
      break;
    case "east":
      longitudeOffset = distanceKm /
          (latitudePerDegreeKm * math.cos(currentLatitude * math.pi / 180.0));
      break;
    case "west":
      longitudeOffset = -distanceKm /
          (latitudePerDegreeKm * math.cos(currentLatitude * math.pi / 180.0));
      break;
    default:
      throw ArgumentError("無効な方向: $direction");
  }

  return {
    'latitude': currentLatitude + latitudeOffset,
    'longitude': currentLongitude + longitudeOffset,
  };
}