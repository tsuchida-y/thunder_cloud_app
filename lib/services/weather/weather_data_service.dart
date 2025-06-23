import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// 気象データの管理と共有を行うサービスクラス
/// Firestoreからの気象データ取得とリアルタイム監視を提供
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
    AppLogger.info('Firestoreから気象データ取得開始', tag: 'WeatherDataService');

    LatLng? currentLocation = providedLocation;

    // 位置情報が提供されていない場合は、Firestoreから最新のユーザー位置を取得
    if (currentLocation == null) {
      AppLogger.info('位置情報が未提供のため、Firestoreからユーザー位置を取得', tag: 'WeatherDataService');
      currentLocation = await _getUserLocationFromFirestore();
    }

    if (currentLocation == null) {
      AppLogger.warning('位置情報を取得できませんでした', tag: 'WeatherDataService');
      return;
    }

    AppLogger.info('使用する位置情報: 緯度 ${currentLocation.latitude.toStringAsFixed(2)}, 経度 ${currentLocation.longitude.toStringAsFixed(2)}', tag: 'WeatherDataService');

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

          AppLogger.success('Firestoreから気象データ取得完了: ${weatherData.length}方向', tag: 'WeatherDataService');
          return;
        }
      }

      AppLogger.warning('Firestoreにキャッシュデータが見つかりません。Firebase Functionsによる自動更新を待機中...', tag: 'WeatherDataService');

      // キャッシュがない場合は空のデータで初期化
      _lastWeatherData = {};
      _lastUpdateTime = null;
      _lastLocation = currentLocation;
      notifyListeners();

    } catch (e) {
      AppLogger.error('Firestore気象データ取得エラー', error: e, tag: 'WeatherDataService');

      // エラー時は空のデータで初期化
      _lastWeatherData = {};
      _lastUpdateTime = null;
      _lastLocation = currentLocation;
      notifyListeners();
    }

    AppLogger.info('Firestoreから気象データ取得終了', tag: 'WeatherDataService');
  }

  /// Firestoreからユーザーの最新位置情報を取得
  Future<LatLng?> _getUserLocationFromFirestore() async {
    try {
      AppLogger.info('Firestoreからユーザー位置情報を取得中...', tag: 'WeatherDataService');

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
            AppLogger.success('Firestoreからユーザー位置取得成功: 緯度 ${latitude.toStringAsFixed(2)}, 経度 ${longitude.toStringAsFixed(2)}', tag: 'WeatherDataService');
            return LatLng(latitude, longitude);
          }
        }
      }

      AppLogger.warning('Firestoreにユーザー位置情報が見つかりません', tag: 'WeatherDataService');
      return null;

    } catch (e) {
      AppLogger.error('Firestoreからのユーザー位置取得エラー', error: e, tag: 'WeatherDataService');
      return null;
    }
  }

  /// Firestoreの気象データをリアルタイム監視
  void startRealtimeWeatherDataListener(LatLng currentLocation) {
    AppLogger.info('気象データのリアルタイム監視を開始', tag: 'WeatherDataService');

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

            AppLogger.info('リアルタイム更新: ${weatherData.length}方向のデータを受信', tag: 'WeatherDataService');

            // リスナーに変更を通知
            notifyListeners();
          }
        }
      },
      onError: (error) {
        AppLogger.error('リアルタイム監視エラー', error: error, tag: 'WeatherDataService');
      }
    );
  }

  /// キャッシュキーを生成
  String _generateCacheKey(LatLng location) {
    return AppConstants.generateCacheKey(location.latitude, location.longitude);
  }

  /// 気象データをログ出力
  void _logWeatherData(Map<String, dynamic> weatherData, String direction) {
    final logData = {
      '方向': direction,
      'CAPE': '${weatherData['cape']?.toStringAsFixed(1) ?? 'N/A'} J/kg',
      'Lifted Index': weatherData['lifted_index']?.toStringAsFixed(1) ?? 'N/A',
      'CIN': '${weatherData['convective_inhibition']?.toStringAsFixed(1) ?? 'N/A'} J/kg',
      '温度': '${weatherData['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C',
      '全雲量': '${weatherData['cloud_cover']?.toStringAsFixed(1) ?? 'N/A'}%',
      '中層雲': '${weatherData['cloud_cover_mid']?.toStringAsFixed(1) ?? 'N/A'}%',
      '高層雲': '${weatherData['cloud_cover_high']?.toStringAsFixed(1) ?? 'N/A'}%',
    };

    AppLogger.debug('受信した気象データ: $logData', tag: 'WeatherDataService');
  }

  /// 分析結果をログ出力
  void _logAnalysisResults(Map<String, dynamic> analysis, String direction) {
    final analysisData = {
      '方向': direction,
      '判定': analysis['isLikely'] == true ? '入道雲の可能性あり' : '入道雲なし',
      '総合スコア': '${((analysis['totalScore'] ?? 0) * 100).toStringAsFixed(1)}%',
      'リスクレベル': analysis['riskLevel'] ?? 'N/A',
      'CAPEスコア': '${((analysis['capeScore'] ?? 0) * 100).toStringAsFixed(1)}%',
      'LIスコア': '${((analysis['liScore'] ?? 0) * 100).toStringAsFixed(1)}%',
      'CINスコア': '${((analysis['cinScore'] ?? 0) * 100).toStringAsFixed(1)}%',
      '温度スコア': '${((analysis['tempScore'] ?? 0) * 100).toStringAsFixed(1)}%',
      '雲量スコア': '${((analysis['cloudScore'] ?? 0) * 100).toStringAsFixed(1)}%',
    };

    AppLogger.debug('入道雲分析結果: $analysisData', tag: 'WeatherDataService');
  }

  /// データをクリア
  void clearData() {
    _lastWeatherData.clear();
    _lastUpdateTime = null;
    _lastLocation = null;
    notifyListeners();
  }

  /// リアルタイム監視を停止
  void stopRealtimeWeatherDataListener() {
    AppLogger.info('リアルタイム監視を停止', tag: 'WeatherDataService');
    // 実際の監視停止処理は呼び出し元で管理
  }
}