import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../utils/coordinate.dart';

/// 気象データの管理と共有を行うサービスクラス
class WeatherDataService extends ChangeNotifier {
  static WeatherDataService? _instance;
  static WeatherDataService get instance => _instance ??= WeatherDataService._();

  WeatherDataService._();

  // Firebase Functions インスタンス
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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
      // Firebase Functionsから複数方向の気象データを一括取得
      final result = await _functions.httpsCallable('getDirectionalWeatherData').call({
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
        'directions': 'north,south,east,west',
      });

      final Map<String, Map<String, dynamic>> newData = {};

      if (result.data != null) {
        final data = result.data as Map<String, dynamic>;

        // 各方向のデータを処理
        for (String direction in ['north', 'south', 'east', 'west']) {
          if (data.containsKey(direction)) {
            final directionData = Map<String, dynamic>.from(data[direction]);
            newData[direction] = directionData;

            _logWeatherData(directionData, direction);
            if (directionData.containsKey('analysis')) {
              _logAnalysisResults(directionData['analysis'], direction);
            }
          }
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

      // エラー時はローカル分析にフォールバック
      await _fetchWithFallback(currentLocation);
    }

    print("🌦️ === 気象データ取得終了 ===");
  }

  /// フォールバック用の単一地点データ取得
  Future<void> _fetchWithFallback(LatLng currentLocation) async {
    print("🔄 フォールバック処理開始");

    try {
      final Map<String, Map<String, dynamic>> newData = {};

      // 各方向の気象データを個別に取得
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

      print("✅ フォールバック処理完了: ${newData.length}方向");
    } catch (e) {
      print("❌ フォールバック処理エラー: $e");
    }
  }

  /// 指定方向の気象データを取得（フォールバック用）
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
      // Firebase Functionsから単一地点のデータを取得
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

        return weatherData;
      }
    } catch (e) {
      print("❌ 気象データ取得エラー: $e");
    }

    return null;
  }

  /// 気象データをログ出力
  void _logWeatherData(Map<String, dynamic> weatherData, String direction) {
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
  void _logAnalysisResults(Map<String, dynamic> analysis, String direction) {
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

  /// データをクリア
  void clearData() {
    _lastWeatherData.clear();
    _lastUpdateTime = null;
    _lastLocation = null;
    notifyListeners();
  }
}