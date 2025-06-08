import 'dart:convert';
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../utils/coordinate_utils.dart';
import 'weather/thunder_cloud_analyzer.dart';

/// 気象データのデバッグ機能を提供するサービスクラス
class WeatherDebugService {

  /// 現在地の各方向の気象データを取得・分析してログ出力
  static Future<void> debugWeatherData(LatLng currentLocation) async {
    print("🌦️ === 気象データデバッグ開始 ===");
    print("📍 現在地: 緯度 ${currentLocation.latitude}, 経度 ${currentLocation.longitude}");

    // 各方向の気象データを取得
    for (String direction in ['north', 'south', 'east', 'west']) {
      await _analyzeDirection(direction, currentLocation.latitude, currentLocation.longitude);
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
      // Open-Meteo APIからデータ取得
      final weatherData = await _fetchWeatherData(targetLat, targetLon);

      if (weatherData != null) {
        _logWeatherData(weatherData);

        // 入道雲分析を実行
        final analysis = ThunderCloudAnalyzer.analyzeWeatherData(weatherData);
        _logAnalysisResults(analysis);
      }
    } catch (e) {
      print("❌ 気象データ取得エラー: $e");
    }
  }

  /// Open-Meteo APIから気象データを取得
  static Future<Map<String, dynamic>?> _fetchWeatherData(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?'
      'latitude=${lat.toStringAsFixed(6)}&longitude=${lon.toStringAsFixed(6)}&'
      'hourly=cape,lifted_index,convective_inhibition&'
      'current=temperature_2m&timezone=auto&forecast_days=1'
    );

    print("🌐 API URL: $uri");

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      return {
        'cape': data['hourly']['cape'][0] ?? 0.0,
        'lifted_index': data['hourly']['lifted_index'][0] ?? 0.0,
        'convective_inhibition': data['hourly']['convective_inhibition'][0] ?? 0.0,
        'temperature': data['current']['temperature_2m'] ?? 20.0,
      };
    } else {
      print("❌ API エラー: ${response.statusCode}");
      return null;
    }
  }

  /// 気象データをログ出力
  static void _logWeatherData(Map<String, dynamic> weatherData) {
    print("📊 === 取得した気象データ ===");
    print("🔥 CAPE: ${weatherData['cape'].toStringAsFixed(1)} J/kg");
    print("📈 Lifted Index: ${weatherData['lifted_index'].toStringAsFixed(1)}");
    print("🚧 CIN: ${weatherData['convective_inhibition'].toStringAsFixed(1)} J/kg");
    print("🌡️ 温度: ${weatherData['temperature'].toStringAsFixed(1)}°C");
  }

  /// 分析結果をログ出力
  static void _logAnalysisResults(Map<String, dynamic> analysis) {
    print("⚡ === 入道雲分析結果 ===");
    print("🎯 判定: ${analysis['isLikely'] ? '入道雲の可能性あり' : '入道雲なし'}");
    print("📊 総合スコア: ${(analysis['totalScore'] * 100).toStringAsFixed(1)}%");
    print("🏷️ リスクレベル: ${analysis['riskLevel']}");
    print("📋 詳細スコア:");
    print("   - CAPE: ${(analysis['capeScore'] * 100).toStringAsFixed(1)}%");
    print("   - Lifted Index: ${(analysis['liScore'] * 100).toStringAsFixed(1)}%");
    print("   - CIN: ${(analysis['cinScore'] * 100).toStringAsFixed(1)}%");
    print("   - 温度: ${(analysis['tempScore'] * 100).toStringAsFixed(1)}%");
  }
}