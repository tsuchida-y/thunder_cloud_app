import 'dart:developer';
import 'dart:math' as math;
import 'package:thunder_cloud_app/services/weather/directional_weather.dart';
import 'package:thunder_cloud_app/services/weather/weather_api.dart';
import 'package:thunder_cloud_app/services/weather/advanced_weather_api.dart';
import 'package:thunder_cloud_app/services/weather/thunder_cloud_analyzer.dart';

final WeatherApi weatherApi = WeatherApi();
final AdvancedWeatherApi advancedWeatherApi = AdvancedWeatherApi();
final DirectionalWeather directionalWeather = DirectionalWeather(weatherApi);

/// 従来の入道雲判定ロジック（フォールバック用）
bool isCloudyConditionMet(Map<String, dynamic> weatherData) {
  final isThunderstorm = weatherData["weather"] == "Thunderstorm";
  final isCloudy = weatherData["weather"] == "Clouds" &&
      (weatherData["detailed_weather"].contains("thunderstorm") ||
          weatherData["detailed_weather"].contains("heavy rain") ||
          weatherData["detailed_weather"].contains("squalls") ||
          weatherData["detailed_weather"].contains("hail"));
  final isHot = weatherData["temperature"] > 25.0;

  return (isThunderstorm || isCloudy) && isHot;
}

/// 高度な入道雲判定ロジック
Future<bool> isAdvancedThunderCloudConditionMet(
  double latitude, 
  double longitude
) async {
  try {
    // 基本天気データと高度気象データを並行取得
    final basicWeatherFuture = weatherApi.fetchWeather(latitude, longitude);
    final advancedWeatherFuture = advancedWeatherApi.fetchAdvancedWeatherData(latitude, longitude);

    final results = await Future.wait([basicWeatherFuture, advancedWeatherFuture]);
    final basicWeather = results[0];
    final advancedWeather = results[1];

    // 高度な分析実行
    final assessment = ThunderCloudAnalyzer.analyzeThunderCloudPotential(
      basicWeather,
      advancedWeather 
    );

    // 詳細ログ出力
    log("=== 積乱雲分析結果 ===");
    log("総合判定: ${assessment.isThunderCloudLikely ? '積乱雲の可能性あり' : '積乱雲の可能性低い'}");
    log("総合スコア: ${(assessment.totalScore * 100).toStringAsFixed(1)}%");
    log("信頼度: ${(assessment.confidence * 100).toStringAsFixed(1)}%");
    log("リスクレベル: ${assessment.riskLevel}");

    return assessment.isThunderCloudLikely;
  } catch (e) {
    log("高度な入道雲判定でエラー発生、従来判定にフォールバック: $e");
    
    // エラー時は従来のシンプル判定を使用
    final basicWeather = await weatherApi.fetchWeather(latitude, longitude);
    return isCloudyConditionMet(basicWeather);
  }
}

/// 高度な方向別天気チェック（新規実装）
Future<List<String>> fetchAdvancedWeatherInDirections(
    double currentLatitude, double currentLongitude) async {
  List<String> tempMatchingCities = [];
  const directions = ["north", "south", "east", "west"];

  try {
    for (final direction in directions) {
      // 方向ごとの座標計算
      final coordinates = _calculateDirectionCoordinates(
          direction, currentLatitude, currentLongitude);
      
      // 高度な積乱雲判定を実行
      final isThunderCloud = await isAdvancedThunderCloudConditionMet(
          coordinates['latitude']!, coordinates['longitude']!);
      
      log("$direction: ${isThunderCloud ? '積乱雲あり' : '積乱雲なし'}");
      
      if (isThunderCloud) {
        tempMatchingCities.add(direction);
      }
    }
  } catch (e) {
    log("高度な方向別チェックでエラー、従来手法にフォールバック: $e");
    return await fetchWeatherInDirections(currentLatitude, currentLongitude);
  }

  return tempMatchingCities;
}

/// 従来の方向別天気チェック（既存）
Future<List<String>> fetchWeatherInDirections(
    double currentLatitude, double currentLongitude) async {
  List<String> tempMatchingCities = [];
  const directions = ["north", "south", "east", "west"];

  try {
    for (final direction in directions) {
      final weather = await directionalWeather.fetchWeatherInDirection(
          direction, currentLatitude, currentLongitude);
      log("$direction: $weather");
      if (isCloudyConditionMet(weather)) {
        tempMatchingCities.add(direction);
      }
    }
  } catch (e) {
    log("Error checking weather in directions: $e");
  }

  return tempMatchingCities;
}

/// 方向ごとの座標計算（DirectionalWeatherから移植）
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