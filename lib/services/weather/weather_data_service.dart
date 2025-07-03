import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/app_constants.dart';
import '../../utils/logger.dart';
import '../notification/fcm_token_manager.dart';

/// 気象データの管理と共有を行うサービスクラス
/// Firestoreからの気象データ取得とリアルタイム監視を提供
/// ChangeNotifierを継承して、データ変更時にUIに通知
class WeatherDataService extends ChangeNotifier {
  /*
  ================================================================================
                                    シングルトン
                          アプリ全体で共有する単一インスタンス
  ================================================================================
  */
  static WeatherDataService? _instance;
  static WeatherDataService get instance => _instance ??= WeatherDataService._();

  WeatherDataService._();

  /*
  ================================================================================
                                    依存関係
                         外部サービスとの接続とインスタンス
  ================================================================================
  */
  /// Firestoreデータベースインスタンス
  /// 気象データのキャッシュ保存・取得に使用
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /*
  ================================================================================
                                    状態管理
                          データの保持と状態の管理
  ================================================================================
  */
  /// 最後に取得した気象データ（4方向のデータを保持）
  Map<String, Map<String, dynamic>> _lastWeatherData = {};

  /// 最終更新時刻（データの鮮度管理用）
  DateTime? _lastUpdateTime;

  /// 最終更新位置（データの位置情報管理用）
  LatLng? _lastLocation;

  /*
  ================================================================================
                                    ゲッター
                          外部からの安全なデータアクセス
  ================================================================================
  */
  /// 最後に取得した気象データを取得（不変コピーを返す）
  Map<String, Map<String, dynamic>> get lastWeatherData => Map.from(_lastWeatherData);

  /// 最終更新時刻を取得
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// 最終更新位置を取得
  LatLng? get lastLocation => _lastLocation;

  /// 気象データが利用可能かどうか
  bool get hasData => _lastWeatherData.isNotEmpty;

  /*
  ================================================================================
                                データ取得機能
                        Firestoreからの気象データ取得処理
  ================================================================================
  */

  /// Firestoreから気象データを取得・保存
  /// 位置情報の取得、キャッシュデータの検証、状態更新を統合
  ///
  /// [providedLocation] 提供された位置情報（nullの場合はFirestoreから取得）
  Future<void> fetchAndStoreWeatherData(LatLng? providedLocation) async {
    AppLogger.info('Firestoreから気象データ取得開始', tag: 'WeatherDataService');

    // ステップ1: 位置情報の決定
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
      // ステップ2: Firestoreからキャッシュデータを取得
      final cacheKey = _generateCacheKey(currentLocation);
      final cacheDoc = await _firestore.collection('weather_cache').doc(cacheKey).get();

      // ステップ3: キャッシュデータの存在確認と処理
      if (cacheDoc.exists) {
        final cachedData = cacheDoc.data();
        if (cachedData != null && cachedData.containsKey('data')) {
          final weatherData = Map<String, Map<String, dynamic>>.from(
            cachedData['data'].cast<String, Map<String, dynamic>>()
          );

          // ステップ4: データの保存と状態更新
          _lastWeatherData = weatherData;
          _lastUpdateTime = (cachedData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          _lastLocation = currentLocation;

          // ステップ5: 詳細ログの出力
          for (String direction in AppConstants.checkDirections) {
            if (weatherData.containsKey(direction)) {
              _logWeatherData(weatherData[direction]!, direction);
              if (weatherData[direction]!.containsKey('analysis')) {
                _logAnalysisResults(weatherData[direction]!['analysis'], direction);
              }
            }
          }

          // ステップ6: UIへの変更通知
          notifyListeners();

          AppLogger.success('Firestoreから気象データ取得完了: ${weatherData.length}方向', tag: 'WeatherDataService');
          return;
        }
      }

      // ステップ7: キャッシュがない場合の処理
      AppLogger.warning('Firestoreにキャッシュデータが見つかりません。Firebase Functionsによる自動更新を待機中...', tag: 'WeatherDataService');

      // キャッシュがない場合は空のデータで初期化
      _lastWeatherData = {};
      _lastUpdateTime = null;
      _lastLocation = currentLocation;
      notifyListeners();

    } catch (e) {
      // ステップ8: エラーハンドリング
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
  /// FCMトークンベースの統合構造からユーザー位置情報を取得
  Future<LatLng?> _getUserLocationFromFirestore() async {
    try {
      AppLogger.info('Firestoreからユーザー位置情報を取得中...', tag: 'WeatherDataService');

      // ステップ1: FCMトークンを取得
      final fcmToken = FCMTokenManager.currentToken;
      if (fcmToken == null) {
        AppLogger.warning('FCMトークンが取得できません', tag: 'WeatherDataService');
        return null;
      }

      // ステップ2: FCMトークンベースでユーザードキュメントを取得
      final userDoc = await _firestore.collection('users').doc(fcmToken).get();

      // ステップ3: ドキュメントの存在確認とデータ抽出
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null &&
            userData.containsKey('latitude') &&
            userData.containsKey('longitude')) {

          final latitude = userData['latitude']?.toDouble();
          final longitude = userData['longitude']?.toDouble();

          // ステップ4: 座標の妥当性チェック
          if (latitude != null && longitude != null) {
            AppLogger.success('Firestoreからユーザー位置取得成功: 緯度 ${latitude.toStringAsFixed(2)}, 経度 ${longitude.toStringAsFixed(2)}', tag: 'WeatherDataService');
            return LatLng(latitude, longitude);
          }
        }
      }

      AppLogger.warning('Firestoreにユーザー位置情報が見つかりません', tag: 'WeatherDataService');
      return null;

    } catch (e) {
      // エラーハンドリング
      AppLogger.error('Firestoreからのユーザー位置取得エラー', error: e, tag: 'WeatherDataService');
      return null;
    }
  }

  /*
  ================================================================================
                                リアルタイム監視機能
                        Firestoreリアルタイムリスナーの管理
  ================================================================================
  */

  /// Firestoreの気象データをリアルタイム監視
  /// データ変更時に自動的に状態を更新してUIに通知
  ///
  /// [currentLocation] 監視対象の位置情報
  void startRealtimeWeatherDataListener(LatLng currentLocation) {
    AppLogger.info('気象データのリアルタイム監視を開始', tag: 'WeatherDataService');

    final cacheKey = _generateCacheKey(currentLocation);

    // Firestoreのリアルタイムリスナーを設定
    // データ変更時に自動的に新しいデータを取得
    _firestore.collection('weather_cache').doc(cacheKey).snapshots().listen(
      (snapshot) {
        // ステップ1: スナップショットの存在確認
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null && data.containsKey('data')) {
            // ステップ2: データの変換と更新
            final weatherData = Map<String, Map<String, dynamic>>.from(
              data['data'].cast<String, Map<String, dynamic>>()
            );

            // ステップ3: 状態の更新
            _lastWeatherData = weatherData;
            _lastUpdateTime = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            _lastLocation = currentLocation;

            AppLogger.info('リアルタイム更新: ${weatherData.length}方向のデータを受信', tag: 'WeatherDataService');

            // ステップ4: UIへの変更通知
            notifyListeners();
          }
        }
      },
      onError: (error) {
        // エラーハンドリング
        AppLogger.error('リアルタイム監視エラー', error: error, tag: 'WeatherDataService');
      }
    );
  }

  /*
  ================================================================================
                                ユーティリティメソッド
                        補助的な処理・データ検証・キー生成
  ================================================================================
  */

  /// キャッシュキーを生成
  /// 位置情報から一意のキャッシュキーを生成
  String _generateCacheKey(LatLng location) {
    return AppConstants.generateCacheKey(location.latitude, location.longitude);
  }

  /*
  ================================================================================
                                ログ出力機能
                        データの可視化とデバッグ支援
  ================================================================================
  */

  /// 気象データをログ出力
  /// 受信した気象データを見やすい形式でログに出力
  ///
  /// [weatherData] 気象データのマップ
  /// [direction] 方向（north, south, east, west）
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
  /// 入道雲分析結果を見やすい形式でログに出力
  ///
  /// [analysis] 分析結果のマップ
  /// [direction] 方向（north, south, east, west）
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

  /*
  ================================================================================
                                リソース管理
                        データのクリアと監視の停止
  ================================================================================
  */

  /// データをクリア
  /// 保持している気象データと状態をリセット
  void clearData() {
    _lastWeatherData.clear();
    _lastUpdateTime = null;
    _lastLocation = null;
    notifyListeners();
  }

  /// リアルタイム監視を停止
  /// 監視の停止処理（実際の監視停止処理は呼び出し元で管理）
  void stopRealtimeWeatherDataListener() {
    AppLogger.info('リアルタイム監視を停止', tag: 'WeatherDataService');
    // 実際の監視停止処理は呼び出し元で管理
  }
}