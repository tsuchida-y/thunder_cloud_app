import 'dart:developer';
import 'dart:math' as math;
import 'package:thunder_cloud_app/constants/weather_constants.dart';
import 'package:thunder_cloud_app/services/weather/weather_api.dart';
import 'package:thunder_cloud_app/services/weather/advanced_weather_api.dart';
import 'package:thunder_cloud_app/services/weather/thunder_cloud_analyzer.dart';

// インスタンス作成
final WeatherApi weatherApi = WeatherApi();
final AdvancedWeatherApi advancedWeatherApi = AdvancedWeatherApi();

/// 高度な入道雲判定ロジック（Open-Meteoのみ使用）
Future<bool> isAdvancedThunderCloudConditionMet(
    double latitude, double longitude) async {
  try {
    // ✅ 座標の詳細ログ追加
    log("🌍 気象データ取得開始:");
    log("  座標: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}");

    final advancedWeather =
        await AdvancedWeatherApi.fetchAdvancedWeatherData(latitude, longitude);

    // ✅ 取得データの詳細ログ追加
    log("📊 取得データ詳細:");
    log("  CAPE: ${advancedWeather['cape']}");
    log("  LI: ${advancedWeather['lifted_index']}");
    log("  CIN: ${advancedWeather['convective_inhibition']}");
    log("  温度: ${advancedWeather['temperature']}");

    final assessment =
        ThunderCloudAnalyzer.analyzeWithMeteoDataOnly(advancedWeather);

    log("=== 積乱雲分析結果（Open-Meteoのみ）===");
    log("総合判定: ${assessment.isThunderCloudLikely ? '積乱雲の可能性あり' : '積乱雲の可能性低い'}");
    log("総合スコア: ${(assessment.totalScore * 100).toStringAsFixed(1)}%");
    log("信頼度: ${(assessment.confidence * 100).toStringAsFixed(1)}%");
    log("リスクレベル: ${assessment.riskLevel}");

    return assessment.isThunderCloudLikely;
  } catch (e) {
    log("❌ Open-Meteo API取得エラー: $e");
    return false;
  }
}

/// 3つの距離での方向別天気チェック（拡張版）
Future<List<String>> fetchAdvancedWeatherInDirections(
    double currentLatitude, double currentLongitude) async {
  List<String> tempMatchingCities = [];
  const directions = ["north", "south", "east", "west"];
  final distances = WeatherConstants.getAllSearchDistances(); // 3つの距離（km）

  try {
    for (final direction in directions) {
      bool foundThunderCloud = false;

      // 各方向で3つの距離をチェック
      for (final distance in distances) {
        final coordinates = _calculateDirectionCoordinates(
            direction, currentLatitude, currentLongitude, distance);

        final isThunderCloud = await isAdvancedThunderCloudConditionMet(
            coordinates['latitude']!, coordinates['longitude']!);

        // ✅ 距離ラベルを使用したログ出力
        final distanceLabel = WeatherConstants.getDistanceLabel(distance);
        log("$direction ($distanceLabel - ${distance}km): ${isThunderCloud ? '積乱雲あり' : '積乱雲なし'}");

        if (isThunderCloud) {
          foundThunderCloud = true;
          // 最初に見つかった距離で記録（近い方を優先）
          break;
        }
      }

      if (foundThunderCloud) {
        tempMatchingCities.add(direction);
      }
    }
  } catch (e) {
    log("Open-Meteo方向別チェックエラー: $e");
  }

  return tempMatchingCities;
}

// 詳細な結果を返すバージョン（オプション）
Future<Map<String, dynamic>> fetchDetailedWeatherInDirections(
    double currentLatitude, double currentLongitude) async {
  Map<String, dynamic> detailedResults = {};
  const directions = ["north", "south", "east", "west"];
  final distances = WeatherConstants.getAllSearchDistances();

  try {
    for (final direction in directions) {
      List<Map<String, dynamic>> directionResults = [];

      for (final distance in distances) {
        final coordinates = _calculateDirectionCoordinates(
            direction, currentLatitude, currentLongitude, distance);

        final isThunderCloud = await isAdvancedThunderCloudConditionMet(
            coordinates['latitude']!, coordinates['longitude']!);

        directionResults.add({
          'distance': distance,
          'hasThunderCloud': isThunderCloud,
          'coordinates': coordinates,
          'distanceLabel': WeatherConstants.getDistanceLabel(distance),
        });

        final distanceLabel = WeatherConstants.getDistanceLabel(distance);
        log("$direction ($distanceLabel - ${distance}km): ${isThunderCloud ? '積乱雲あり' : '積乱雲なし'}");
      }

      detailedResults[direction] = directionResults;
    }
  } catch (e) {
    log("詳細天気チェックエラー: $e");
  }

  return detailedResults;
}

/// 距離を指定可能な方向座標計算（拡張版）
Map<String, double> _calculateDirectionCoordinates(String direction,
    double currentLatitude, double currentLongitude, double distanceKm) {
  const double latitudePerDegreeKm = WeatherConstants.latitudePerDegreeKm;

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
  final newLatitude = currentLatitude + latitudeOffset;
  final newLongitude = currentLongitude + longitudeOffset;

  // ✅ 座標計算結果のログ追加
  log("📍 座標計算結果:");
  log("  方向: $direction, 距離: ${distanceKm}km");
  log("  元座標: ${currentLatitude.toStringAsFixed(6)}, ${currentLongitude.toStringAsFixed(6)}");
  log("  新座標: ${newLatitude.toStringAsFixed(6)}, ${newLongitude.toStringAsFixed(6)}");
  log("  オフセット: lat=${latitudeOffset.toStringAsFixed(6)}, lon=${longitudeOffset.toStringAsFixed(6)}");
  return {
    'latitude': currentLatitude + latitudeOffset,
    'longitude': currentLongitude + longitudeOffset,
  };
}
