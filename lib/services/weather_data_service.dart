import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../utils/coordinate.dart';
import 'weather/analyzer.dart';

/// 気象データの管理と共有を行うサービスクラス
class WeatherDataService extends ChangeNotifier {
  static WeatherDataService? _instance;
  static WeatherDataService get instance => _instance ??= WeatherDataService._();

  WeatherDataService._();

  // 最後に取得した気象データ
  Map<String, Map<String, dynamic>> _lastWeatherData = {};
  DateTime? _lastUpdateTime;
  LatLng? _lastLocation;

  /// 最後に取得した気象データを取得
  Map<String, Map<String, dynamic>> get lastWeatherData => Map.from(_lastWeatherData);

  /// 最終更新時刻を取得
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// 最終更新位置を取得
  LatLng? get lastLocation => _lastLocation;

  /// 気象データが利用可能かどうか
  bool get hasData => _lastWeatherData.isNotEmpty;

  /// 現在地の各方向の気象データを取得・保存
  Future<void> fetchAndStoreWeatherData(LatLng currentLocation) async {
    print("🌦️ === 気象データ取得開始 ===");
    print("📍 現在地: 緯度 ${currentLocation.latitude}, 経度 ${currentLocation.longitude}");

    try {
      final Map<String, Map<String, dynamic>> newData = {};

      // 各方向の気象データを取得
      for (String direction in ['north', 'south', 'east', 'west']) {
        final data = await _fetchWeatherDataForDirection(
          direction,
          currentLocation.latitude,
          currentLocation.longitude
        );
        if (data != null) {
          newData[direction] = data;
        }
      }

      // データを保存
      _lastWeatherData = newData;
      _lastUpdateTime = DateTime.now();
      _lastLocation = currentLocation;

      // リスナーに変更を通知
      notifyListeners();

      print("✅ 気象データ保存完了: ${newData.length}方向");
    } catch (e) {
      print("❌ 気象データ取得エラー: $e");
    }

    print("🌦️ === 気象データ取得終了 ===");
  }

  /// 指定方向の気象データを取得
  Future<Map<String, dynamic>?> _fetchWeatherDataForDirection(
    String direction,
    double lat,
    double lon
  ) async {
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
        // 座標情報を追加
        weatherData['coordinates'] = {'lat': targetLat, 'lon': targetLon};

        // 分析結果を追加
        final analysis = ThunderCloudAnalyzer.analyzeWeatherData(weatherData);
        weatherData['analysis'] = analysis;

        _logWeatherData(weatherData);
        _logAnalysisResults(analysis);

        return weatherData;
      }
    } catch (e) {
      print("❌ 気象データ取得エラー: $e");
    }

    return null;
  }

  /// Open-Meteo APIから気象データを取得
  Future<Map<String, dynamic>?> _fetchWeatherData(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?'
      'latitude=${lat.toStringAsFixed(6)}&longitude=${lon.toStringAsFixed(6)}&'
      'hourly=cape,lifted_index,convective_inhibition,cloud_cover,cloud_cover_mid,cloud_cover_high&'
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
        'cloud_cover': data['hourly']['cloud_cover'][0] ?? 0.0,
        'cloud_cover_mid': data['hourly']['cloud_cover_mid'][0] ?? 0.0,
        'cloud_cover_high': data['hourly']['cloud_cover_high'][0] ?? 0.0,
      };
    } else {
      print("❌ API エラー: ${response.statusCode}");
      return null;
    }
  }

  /// 気象データをログ出力
  void _logWeatherData(Map<String, dynamic> weatherData) {
    print("📊 === 取得した気象データ ===");
    print("🔥 CAPE: ${weatherData['cape'].toStringAsFixed(1)} J/kg");
    print("📈 Lifted Index: ${weatherData['lifted_index'].toStringAsFixed(1)}");
    print("🚧 CIN: ${weatherData['convective_inhibition'].toStringAsFixed(1)} J/kg");
    print("🌡️ 温度: ${weatherData['temperature'].toStringAsFixed(1)}°C");
    print("☁️ 全雲量: ${weatherData['cloud_cover'].toStringAsFixed(1)}%");
    print("🌫️ 中層雲: ${weatherData['cloud_cover_mid'].toStringAsFixed(1)}%");
    print("⛅ 高層雲: ${weatherData['cloud_cover_high'].toStringAsFixed(1)}%");
  }

  /// 分析結果をログ出力
  void _logAnalysisResults(Map<String, dynamic> analysis) {
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

  /// データをクリア
  void clearData() {
    _lastWeatherData.clear();
    _lastUpdateTime = null;
    _lastLocation = null;
    notifyListeners();
  }
}