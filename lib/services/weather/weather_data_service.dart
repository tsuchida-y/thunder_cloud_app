import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/app_constants.dart';

/// 気象データの管理と共有を行うサービスクラス
class WeatherDataService extends ChangeNotifier {
  static WeatherDataService? _instance;
  static WeatherDataService get instance => _instance ??= WeatherDataService._();

  WeatherDataService._();

  // Firestore インスタンス
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Firestoreから気象データを取得・保存
  Future<void> fetchAndStoreWeatherData(LatLng? providedLocation) async {
    print("🌦️ === Firestoreから気象データ取得開始 ===");

    LatLng? currentLocation = providedLocation;

    // 位置情報が提供されていない場合は、Firestoreから最新のユーザー位置を取得
    if (currentLocation == null) {
      print("📍 位置情報が未提供のため、Firestoreからユーザー位置を取得");
      currentLocation = await _getUserLocationFromFirestore();
    }

    if (currentLocation == null) {
      print("❌ 位置情報を取得できませんでした");
      return;
    }

    print("📍 使用する位置情報: 緯度 ${currentLocation.latitude}, 経度 ${currentLocation.longitude}");

    try {
      // Firestoreのweather_cacheコレクションからデータを取得
      final cacheKey = _generateCacheKey(currentLocation);
      final cacheDoc = await _firestore.collection('weather_cache').doc(cacheKey).get();

      if (cacheDoc.exists) {
        final cachedData = cacheDoc.data();
        if (cachedData != null && cachedData.containsKey('data')) {
          final weatherData = Map<String, Map<String, dynamic>>.from(
            cachedData['data'].cast<String, Map<String, dynamic>>()
          );

          // データを保存
          _lastWeatherData = weatherData;
          _lastUpdateTime = (cachedData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          _lastLocation = currentLocation;

          // ログ出力
          for (String direction in ['north', 'south', 'east', 'west']) {
            if (weatherData.containsKey(direction)) {
              _logWeatherData(weatherData[direction]!, direction);
              if (weatherData[direction]!.containsKey('analysis')) {
                _logAnalysisResults(weatherData[direction]!['analysis'], direction);
              }
            }
          }

          // リスナーに変更を通知
          notifyListeners();

          print("✅ Firestoreから気象データ取得完了: ${weatherData.length}方向");
          return;
        }
      }

      print("⚠️ Firestoreにキャッシュデータが見つかりません。Firebase Functionsによる自動更新を待機中...");

      // キャッシュがない場合は空のデータで初期化
      _lastWeatherData = {};
      _lastUpdateTime = null;
      _lastLocation = currentLocation;
      notifyListeners();

    } catch (e) {
      print("❌ Firestore気象データ取得エラー: $e");

      // エラー時は空のデータで初期化
      _lastWeatherData = {};
      _lastUpdateTime = null;
      _lastLocation = currentLocation;
      notifyListeners();
    }

    print("🌦️ === Firestoreから気象データ取得終了 ===");
  }

  /// Firestoreからユーザーの最新位置情報を取得
  Future<LatLng?> _getUserLocationFromFirestore() async {
    try {
      print("🔍 Firestoreからユーザー位置情報を取得中...");

      // 固定ユーザーIDから位置情報を取得
      const userId = 'user_001';
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null &&
            userData.containsKey('latitude') &&
            userData.containsKey('longitude')) {

          final latitude = userData['latitude']?.toDouble();
          final longitude = userData['longitude']?.toDouble();

          if (latitude != null && longitude != null) {
            print("✅ Firestoreからユーザー位置取得成功: 緯度 $latitude, 経度 $longitude");
            return LatLng(latitude, longitude);
          }
        }
      }

      print("⚠️ Firestoreにユーザー位置情報が見つかりません");
      return null;

    } catch (e) {
      print("❌ Firestoreからのユーザー位置取得エラー: $e");
      return null;
    }
  }

  /// Firestoreの気象データをリアルタイム監視
  void startRealtimeWeatherDataListener(LatLng currentLocation) {
    print("🔄 気象データのリアルタイム監視を開始");

    final cacheKey = _generateCacheKey(currentLocation);

    _firestore.collection('weather_cache').doc(cacheKey).snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null && data.containsKey('data')) {
            final weatherData = Map<String, Map<String, dynamic>>.from(
              data['data'].cast<String, Map<String, dynamic>>()
            );

            // データを更新
            _lastWeatherData = weatherData;
            _lastUpdateTime = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            _lastLocation = currentLocation;

            print("🔄 リアルタイム更新: ${weatherData.length}方向のデータを受信");

            // リスナーに変更を通知
            notifyListeners();
          }
        }
      },
      onError: (error) {
        print("❌ リアルタイム監視エラー: $error");
      }
    );
  }

  /// キャッシュキーを生成
  String _generateCacheKey(LatLng location) {
    return AppConstants.generateCacheKey(location.latitude, location.longitude);
  }

  /// 気象データをログ出力
  void _logWeatherData(Map<String, dynamic> weatherData, String direction) {
    print("📊 === [$direction] 受信した気象データ ===");
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

  /// リアルタイム監視を停止
  void stopRealtimeListener() {
    // StreamSubscriptionがあれば停止処理を追加
    print("🛑 リアルタイム監視を停止");
  }
}