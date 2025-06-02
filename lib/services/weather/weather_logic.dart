import 'dart:developer';
import 'dart:math' as math;
import 'package:thunder_cloud_app/constants/weather_constants.dart';
import 'package:thunder_cloud_app/services/weather/weather_api.dart';
import 'package:thunder_cloud_app/services/weather/thunder_cloud_analyzer.dart';


/// 4つの方向と3つの距離での方向別天気チェック
Future<List<String>> fetchAdvancedWeatherInDirections(
    double currentLatitude, double currentLongitude) async {
  List<String> tempMatchingCities = [];
  const directions = WeatherConstants.checkDirections;// 4つの方向（北、南、東、西）
  const distances = WeatherConstants.checkDistances; // 3つの距離（50.0km, 160.0km, 250.0km）

  try {
    //4つの方向でループ
    for (final direction in directions) {
      bool thunderCloudExists = false;

      // 3つの距離でループ
      for (final distance in distances) {

        // 現在地からの座標を計算
        final coordinates = _calculateDirectionCoordinates(direction, currentLatitude, currentLongitude, distance);

        //入道雲判定ロジック+ログ
        final isThunderCloud = await isAdvancedThunderCloudConditionMet(coordinates['latitude']!, coordinates['longitude']!);
        log("$direction方向 ${distance}km: ${isThunderCloud ? '積乱雲あり' : '積乱雲なし'}");


        if (isThunderCloud) {
          // 最初に見つかった距離で記録（近い方を優先）
          thunderCloudExists = true;
          break;
        }
      }

      //判定結果をリストに追加
      if (thunderCloudExists) {
        tempMatchingCities.add(direction);
      }
    }
  } catch (e) {
    log("Open-Meteo方向別チェックエラー: $e");
  }

  return tempMatchingCities;
}


/// 観測対象の座標を計算するメソッド
Map<String, double> _calculateDirectionCoordinates(String direction,
    double currentLatitude, double currentLongitude, double distanceKm) {
  const double latitudePerDegreeKm = WeatherConstants.latitudePerDegreeKm;

  double latitudeOffset = 0.0;
  double longitudeOffset = 0.0;

  //現在地からどれだけ座標が離れているかを計算
  //経度は緯度によって間隔が変わるため、計算が複雑になる
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

  // 座標計算結果のログ追加
  log("📍 座標計算結果:");
  log("  方向: $direction, 距離: ${distanceKm}km");
  //log("  オフセット: lat=${latitudeOffset.toStringAsFixed(6)}, lon=${longitudeOffset.toStringAsFixed(6)}");

  //観測する座標を返す
  return {
    'latitude': currentLatitude + latitudeOffset,
    'longitude': currentLongitude + longitudeOffset,
  };
}

/// 入道雲判定ロジック
Future<bool> isAdvancedThunderCloudConditionMet(
    double latitude, double longitude) async {
  try {
    // 座標の詳細ログ追加
    log("🌍 気象データ取得開始:");
    log("  座標: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}");

    final advancedWeather = await WeatherApi.fetchThunderCloudData(latitude, longitude);

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