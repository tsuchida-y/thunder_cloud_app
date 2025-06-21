import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../utils/coordinate.dart';

/// 気象データのデバッグ機能を提供するサービスクラス
class WeatherDebugService {
  // Firebase Functions インスタンス
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// 現在地の各方向の気象データを取得・分析してログ出力
  static Future<void> debugWeatherData(LatLng currentLocation) async {
    print("🌦️ === 気象データデバッグ開始 ===");
    print("📍 現在地: 緯度 ${currentLocation.latitude}, 経度 ${currentLocation.longitude}");

    try {
      // Firebase Functionsから複数方向の気象データを一括取得
      final result = await _functions.httpsCallable('getDirectionalWeatherData').call({
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
        'directions': 'north,south,east,west',
      });

      if (result.data != null) {
        final data = result.data as Map<String, dynamic>;

        // 各方向のデータを処理
        for (String direction in ['north', 'south', 'east', 'west']) {
          if (data.containsKey(direction)) {
            final directionData = Map<String, dynamic>.from(data[direction]);
            _logWeatherData(directionData, direction);

            if (directionData.containsKey('analysis')) {
              _logAnalysisResults(directionData['analysis'], direction);
            }
          }
        }
      }
    } catch (e) {
      print("❌ 気象データ取得エラー: $e");

      // エラー時は個別取得にフォールバック
      for (String direction in ['north', 'south', 'east', 'west']) {
        await _analyzeDirection(direction, currentLocation.latitude, currentLocation.longitude);
      }
    }

    print("🌦️ === 気象データデバッグ終了 ===");
  }

  /// 指定方向の気象データを分析してログ出力
  static Future<void> _analyzeDirection(String direction, double lat, double lon) async {
    print("\n🧭 [$direction方向] 気象データ分析開始");

    // 方向ごとの座標計算（50km地点）
    final coordinates = CoordinateUtils.calculateDirectionCoordinates(direction, lat, lon, 50.0);
    double targetLat = coordinates.latitude;
    double targetLon = coordinates.longitude;

    print("🎯 分析地点: 緯度 ${targetLat.toStringAsFixed(6)}, 経度 ${targetLon.toStringAsFixed(6)}");

    try {
      // Firebase Functionsから気象データを取得
      final result = await _functions.httpsCallable('getWeatherData').call({
        'latitude': targetLat,
        'longitude': targetLon,
      });

      if (result.data != null) {
        final weatherData = Map<String, dynamic>.from(result.data);
        _logWeatherData(weatherData, direction);

        if (weatherData.containsKey('analysis')) {
          _logAnalysisResults(weatherData['analysis'], direction);
        }
      }
    } catch (e) {
      print("❌ 気象データ取得エラー: $e");
    }
  }

  /// 気象データをログ出力
  static void _logWeatherData(Map<String, dynamic> weatherData, String direction) {
    print("📊 === [$direction] 取得した気象データ ===");
    print("🔥 CAPE: ${weatherData['cape']?.toStringAsFixed(1) ?? 'N/A'} J/kg");
    print("📈 Lifted Index: ${weatherData['lifted_index']?.toStringAsFixed(1) ?? 'N/A'}");
    print("🚧 CIN: ${weatherData['convective_inhibition']?.toStringAsFixed(1) ?? 'N/A'} J/kg");
    print("🌡️ 温度: ${weatherData['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C");
    print("☁️ 全雲量: ${weatherData['cloud_cover']?.toStringAsFixed(1) ?? 'N/A'}%");
    print("🌫️ 中層雲: ${weatherData['cloud_cover_mid']?.toStringAsFixed(1) ?? 'N/A'}%");
    print("⛅ 高層雲: ${weatherData['cloud_cover_high']?.toStringAsFixed(1) ?? 'N/A'}%");
  }

  /// 分析結果をログ出力
  static void _logAnalysisResults(Map<String, dynamic> analysis, String direction) {
    print("⚡ === [$direction] 入道雲分析結果 ===");
    print("🎯 判定: ${analysis['isLikely'] == true ? '入道雲の可能性あり' : '入道雲なし'}");
    print("📊 総合スコア: ${((analysis['totalScore'] ?? 0) * 100).toStringAsFixed(1)}%");
    print("🏷️ リスクレベル: ${analysis['riskLevel'] ?? 'N/A'}");
    print("📋 詳細スコア:");
    print("   - CAPE: ${((analysis['capeScore'] ?? 0) * 100).toStringAsFixed(1)}%");
    print("   - Lifted Index: ${((analysis['liScore'] ?? 0) * 100).toStringAsFixed(1)}%");
    print("   - CIN: ${((analysis['cinScore'] ?? 0) * 100).toStringAsFixed(1)}%");
    print("   - 温度: ${((analysis['tempScore'] ?? 0) * 100).toStringAsFixed(1)}%");
  }

  /// 指定座標の気象データを分析してログ出力
  static Future<void> debugWeatherDataAtLocation(double lat, double lon) async {
    print("🎯 座標 (${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}) の気象データ分析");

    try {
      // Firebase Functionsから気象データを取得
      final result = await _functions.httpsCallable('getWeatherData').call({
        'latitude': lat,
        'longitude': lon,
      });

      if (result.data != null) {
        final weatherData = Map<String, dynamic>.from(result.data);
        _logWeatherData(weatherData, "指定地点");

        if (weatherData.containsKey('analysis')) {
          _logAnalysisResults(weatherData['analysis'], "指定地点");
        }
      }
    } catch (e) {
      print("❌ 気象データ取得エラー: $e");
    }
  }
}