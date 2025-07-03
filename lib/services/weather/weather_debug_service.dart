import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// 気象データのデバッグ用サービスクラス
/// 開発・テスト用途でFirestoreの気象データを確認・分析するためのサービス
/// シングルトンパターンで実装され、アプリ全体で1つのインスタンスを共有
class WeatherDebugService {
  /*
  ================================================================================
                                    シングルトン
                          アプリ全体で共有する単一インスタンス
  ================================================================================
  */
  static final WeatherDebugService _instance = WeatherDebugService._internal();
  factory WeatherDebugService() => _instance;
  WeatherDebugService._internal();

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
                                データ取得機能
                        Firestoreからの気象データ取得処理
  ================================================================================
  */

  /// 指定座標の気象データを取得してデバッグ情報を表示
  /// 単一座標の気象データを詳細に分析してログ出力
  ///
  /// [latitude] 緯度
  /// [longitude] 経度
  ///
  /// Returns: 気象データのMap、見つからない場合はnull
  Future<Map<String, dynamic>?> debugWeatherData(
    double latitude,
    double longitude,
  ) async {
    AppLogger.info('気象データデバッグ開始', tag: 'WeatherDebugService');
    AppLogger.info('座標: 緯度 ${latitude.toStringAsFixed(2)}, 経度 ${longitude.toStringAsFixed(2)}', tag: 'WeatherDebugService');

    try {
      // ステップ1: キャッシュキーの生成
      final cacheKey = _generateCacheKey(latitude, longitude);

      // ステップ2: Firestoreからドキュメントを取得
      final doc = await _firestore
          .collection('weather_cache')
          .doc(cacheKey)
          .get()
          .timeout(AppConstants.weatherDataTimeout);

      // ステップ3: ドキュメントの存在確認
      if (!doc.exists) {
        AppLogger.warning('Firestoreにデータが見つかりません', tag: 'WeatherDebugService');
        return null;
      }

      // ステップ4: データの抽出とnullチェック
      final data = doc.data();
      if (data == null || !data.containsKey('data')) {
        AppLogger.warning('ドキュメントにデータフィールドがありません', tag: 'WeatherDebugService');
        return null;
      }

      // ステップ5: 気象データの抽出とタイムスタンプ取得
      final weatherData = data['data'] as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

      AppLogger.success('Firestoreからデータを取得', tag: 'WeatherDebugService');
      AppLogger.info('データ取得時刻: ${timestamp?.toString() ?? 'N/A'}', tag: 'WeatherDebugService');

      // ステップ6: 詳細ログの出力
      _logWeatherDetails(weatherData);

      // ステップ7: 分析結果の出力（存在する場合）
      if (weatherData.containsKey('analysis')) {
        _logAnalysisDetails(weatherData['analysis']);
      }

      return weatherData;
    } catch (e) {
      AppLogger.error('気象データデバッグエラー', error: e, tag: 'WeatherDebugService');
      return null;
    }
  }

  /// 複数方向の気象データを取得してデバッグ
  /// 4方向（北・南・東・西）の気象データを一括で分析
  ///
  /// [currentLocation] 現在位置
  ///
  /// Returns: 方向別気象データのMap、見つからない場合はnull
  Future<Map<String, Map<String, dynamic>>?> debugDirectionalWeatherData(
    LatLng currentLocation,
  ) async {
    AppLogger.info('複数方向気象データデバッグ開始', tag: 'WeatherDebugService');
    AppLogger.info('現在地: 緯度 ${currentLocation.latitude.toStringAsFixed(2)}, 経度 ${currentLocation.longitude.toStringAsFixed(2)}', tag: 'WeatherDebugService');

    try {
      // ステップ1: 複数方向用キャッシュキーの生成
      final cacheKey = _generateDirectionalCacheKey(currentLocation);

      // ステップ2: Firestoreからドキュメントを取得
      final doc = await _firestore
          .collection('weather_cache')
          .doc(cacheKey)
          .get()
          .timeout(AppConstants.weatherDataTimeout);

      // ステップ3: ドキュメントの存在確認
      if (!doc.exists) {
        AppLogger.warning('Firestoreに複数方向データが見つかりません', tag: 'WeatherDebugService');
        return null;
      }

      // ステップ4: データの抽出とnullチェック
      final data = doc.data();
      if (data == null || !data.containsKey('data')) {
        AppLogger.warning('ドキュメントにデータフィールドがありません', tag: 'WeatherDebugService');
        return null;
      }

      // ステップ5: 方向別データの変換
      final directionalData = Map<String, Map<String, dynamic>>.from(
        data['data'].cast<String, Map<String, dynamic>>()
      );
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

      AppLogger.success('Firestoreから複数方向データを取得', tag: 'WeatherDebugService');
      AppLogger.info('データ取得時刻: ${timestamp?.toString() ?? 'N/A'}', tag: 'WeatherDebugService');
      AppLogger.info('取得方向数: ${directionalData.length}', tag: 'WeatherDebugService');

      // ステップ6: 方向別データの詳細ログ出力
      _logDirectionalData(directionalData);

      return directionalData;
    } catch (e) {
      AppLogger.error('複数方向気象データデバッグエラー', error: e, tag: 'WeatherDebugService');
      return null;
    }
  }

  /*
  ================================================================================
                                統計分析機能
                        Firestore全体の状況確認と分析
  ================================================================================
  */

  /// Firestoreの気象データ状況を確認
  /// 全体的なキャッシュ状況とデータの健全性をチェック
  ///
  /// Returns: Firestore状況の統計情報
  Future<Map<String, dynamic>> debugFirestoreStatus() async {
    AppLogger.info('Firestore気象データ状況確認開始', tag: 'WeatherDebugService');

    try {
      // ステップ1: 全キャッシュドキュメントを取得
      final querySnapshot = await _firestore
          .collection('weather_cache')
          .get()
          .timeout(AppConstants.weatherDataTimeout);

      // ステップ2: 統計情報の分析
      final statusInfo = _analyzeFirestoreStatus(querySnapshot);

      // ステップ3: 統計情報のログ出力
      _logFirestoreStatus(statusInfo);

      return statusInfo;
    } catch (e) {
      AppLogger.error('Firestore状況確認エラー', error: e, tag: 'WeatherDebugService');
      return _createEmptyStatusInfo();
    }
  }

  /*
  ================================================================================
                                ユーティリティメソッド
                        補助的な処理・データ検証・キー生成
  ================================================================================
  */

  /// キャッシュキーを生成（単一座標用）
  /// 精度を下げて、より広い範囲で同じキャッシュを使用
  String _generateCacheKey(double latitude, double longitude) {
    return AppConstants.generateCacheKey(latitude, longitude);
  }

  /// 複数方向用のキャッシュキーを生成
  /// 高精度の座標を使用して方向別データを特定
  String _generateDirectionalCacheKey(LatLng location) {
    return 'weather_${location.latitude.toStringAsFixed(4)}_${location.longitude.toStringAsFixed(4)}';
  }

  /*
  ================================================================================
                                ログ出力機能
                        データの可視化とデバッグ支援
  ================================================================================
  */

  /// 気象データの詳細をログ出力
  /// 受信した気象データを見やすい形式でログに出力
  ///
  /// [weatherData] 気象データのマップ
  void _logWeatherDetails(Map<String, dynamic> weatherData) {
    AppLogger.info('=== 気象データ詳細 ===', tag: 'WeatherDebugService');

    // ステップ1: 詳細情報の抽出
    final details = _extractWeatherDetails(weatherData);

    // ステップ2: 各詳細情報をログ出力
    for (final detail in details) {
      AppLogger.info(detail, tag: 'WeatherDebugService');
    }
  }

  /// 気象データの詳細情報を抽出
  /// 主要な気象要素を日本語で分かりやすく表示
  ///
  /// [weatherData] 気象データのマップ
  /// Returns: 詳細情報のリスト
  List<String> _extractWeatherDetails(Map<String, dynamic> weatherData) {
    return [
      'CAPE: ${_formatValue(weatherData['cape'])} J/kg',
      'Lifted Index: ${_formatValue(weatherData['lifted_index'])}',
      'CIN: ${_formatValue(weatherData['convective_inhibition'])} J/kg',
      '気温: ${_formatValue(weatherData['temperature'])}°C',
      '風速: ${_formatValue(weatherData['wind_speed'])} m/s',
      '風向: ${_formatValue(weatherData['wind_direction'], decimals: 0)}°',
      '全雲量: ${_formatValue(weatherData['cloud_cover'])}%',
      '中層雲: ${_formatValue(weatherData['cloud_cover_mid'])}%',
      '高層雲: ${_formatValue(weatherData['cloud_cover_high'])}%',
      '湿度: ${_formatValue(weatherData['relative_humidity'])}%',
      '気圧: ${_formatValue(weatherData['surface_pressure'])} hPa',
    ];
  }

  /// 値をフォーマット（null安全）
  /// null値や数値の適切な表示形式を提供
  ///
  /// [value] フォーマットする値
  /// [decimals] 小数点以下の桁数（デフォルト: 1）
  /// Returns: フォーマットされた文字列
  String _formatValue(dynamic value, {int decimals = 1}) {
    if (value == null) return 'N/A';
    if (value is num) {
      return value.toStringAsFixed(decimals);
    }
    return value.toString();
  }

  /// 分析結果の詳細をログ出力
  /// 入道雲分析結果を見やすい形式でログに出力
  ///
  /// [analysis] 分析結果のマップ
  void _logAnalysisDetails(Map<String, dynamic> analysis) {
    AppLogger.info('=== 入道雲分析結果 ===', tag: 'WeatherDebugService');

    // ステップ1: 基本情報の抽出
    final isLikely = analysis['isLikely'] == true;
    final totalScore = (analysis['totalScore'] ?? 0) * 100;

    // ステップ2: 基本情報の出力
    AppLogger.info('判定: ${isLikely ? '入道雲の可能性あり' : '入道雲なし'}', tag: 'WeatherDebugService');
    AppLogger.info('総合スコア: ${totalScore.toStringAsFixed(1)}%', tag: 'WeatherDebugService');
    AppLogger.info('リスクレベル: ${analysis['riskLevel'] ?? 'N/A'}', tag: 'WeatherDebugService');

    // ステップ3: 詳細スコアの出力
    _logDetailedScores(analysis);
  }

  /// 詳細スコアをログ出力
  /// 各気象要素の個別スコアを表示
  ///
  /// [analysis] 分析結果のマップ
  void _logDetailedScores(Map<String, dynamic> analysis) {
    final scores = [
      ('CAPEスコア', analysis['capeScore']),
      ('LIスコア', analysis['liScore']),
      ('CINスコア', analysis['cinScore']),
      ('温度スコア', analysis['tempScore']),
      ('雲量スコア', analysis['cloudScore']),
    ];

    AppLogger.info('--- 詳細スコア ---', tag: 'WeatherDebugService');
    for (final (name, score) in scores) {
      final percentage = ((score ?? 0) * 100).toStringAsFixed(1);
      AppLogger.info('$name: $percentage%', tag: 'WeatherDebugService');
    }
  }

  /// 方向別データをログ出力
  /// 4方向の気象データを一覧表示
  ///
  /// [directionalData] 方向別気象データのマップ
  void _logDirectionalData(Map<String, Map<String, dynamic>> directionalData) {
    AppLogger.info('=== 方向別気象データ ===', tag: 'WeatherDebugService');

    // ステップ1: 各方向のデータを処理
    for (final entry in directionalData.entries) {
      final direction = entry.key;
      final data = entry.value;

      AppLogger.info('--- $direction方向 ---', tag: 'WeatherDebugService');

      // ステップ2: 基本気象データの出力
      final details = _extractWeatherDetails(data);
      for (final detail in details) {
        AppLogger.info(detail, tag: 'WeatherDebugService');
      }

      // ステップ3: 分析結果の出力（存在する場合）
      if (data.containsKey('analysis')) {
        _logAnalysisDetails(data['analysis']);
      }
    }
  }

  /*
  ================================================================================
                                統計分析機能
                        Firestoreデータの分析とレポート生成
  ================================================================================
  */

  /// Firestore状況を分析
  /// QuerySnapshotから統計情報を抽出して構造化データを生成
  ///
  /// [querySnapshot] Firestoreのクエリ結果
  /// Returns: 統計情報のマップ
  Map<String, dynamic> _analyzeFirestoreStatus(QuerySnapshot querySnapshot) {
    final now = DateTime.now();
    final documents = querySnapshot.docs;

    // ステップ1: 統計変数の初期化
    int validDocuments = 0;
    int expiredDocuments = 0;
    final List<Map<String, dynamic>> documentDetails = [];

    // ステップ2: 各ドキュメントの分析
    for (final doc in documents) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      final dataAge = timestamp != null ? now.difference(timestamp) : null;
      final isValid = dataAge != null && dataAge < AppConstants.cacheValidityDuration;

      if (isValid) {
        validDocuments++;
      } else {
        expiredDocuments++;
      }

      // ステップ3: ドキュメント詳細情報の収集
      documentDetails.add({
        'id': doc.id,
        'timestamp': timestamp,
        'ageMinutes': dataAge?.inMinutes,
        'isValid': isValid,
        'hasData': data.containsKey('data'),
        'dataKeys': data.containsKey('data') && data['data'] is Map
            ? (data['data'] as Map).keys.toList()
            : [],
      });
    }

    // ステップ4: 統計情報の構造化
    return {
      'totalDocuments': documents.length,
      'validDocuments': validDocuments,
      'expiredDocuments': expiredDocuments,
      'cacheValidityMinutes': AppConstants.cacheValidityDuration.inMinutes,
      'documentDetails': documentDetails,
    };
  }

  /// Firestoreの状況をログ出力
  /// 分析結果を見やすい形式でログに出力
  ///
  /// [statusInfo] 統計情報のマップ
  void _logFirestoreStatus(Map<String, dynamic> statusInfo) {
    final total = statusInfo['totalDocuments'] as int;
    final valid = statusInfo['validDocuments'] as int;
    final expired = statusInfo['expiredDocuments'] as int;
    final validityMinutes = statusInfo['cacheValidityMinutes'] as int;

    // ステップ1: 基本統計の出力
    AppLogger.info('=== Firestore状況 ===', tag: 'WeatherDebugService');
    AppLogger.info('総ドキュメント数: $total', tag: 'WeatherDebugService');
    AppLogger.info('有効ドキュメント数: $valid', tag: 'WeatherDebugService');
    AppLogger.info('期限切れドキュメント数: $expired', tag: 'WeatherDebugService');
    AppLogger.info('キャッシュ有効期限: $validityMinutes分', tag: 'WeatherDebugService');

    // ステップ2: 有効率の計算と出力
    if (total > 0) {
      final validityRate = (valid / total * 100).toStringAsFixed(1);
      AppLogger.info('有効率: $validityRate%', tag: 'WeatherDebugService');
    }

    // ステップ3: 詳細情報の出力（最初の3件のみ）
    final documentDetails = statusInfo['documentDetails'] as List<Map<String, dynamic>>;
    if (documentDetails.isNotEmpty) {
      AppLogger.info('--- ドキュメント詳細（最初の3件）---', tag: 'WeatherDebugService');
      for (int i = 0; i < math.min(3, documentDetails.length); i++) {
        final detail = documentDetails[i];
        AppLogger.info('ID: ${detail['id']}, 有効: ${detail['isValid']}, 年齢: ${detail['ageMinutes']}分', tag: 'WeatherDebugService');
      }
    }
  }

  /// 空の統計情報を作成
  /// エラー時やデータが存在しない場合のフォールバック用
  ///
  /// Returns: 空の統計情報マップ
  Map<String, dynamic> _createEmptyStatusInfo() {
    return {
      'totalDocuments': 0,
      'validDocuments': 0,
      'expiredDocuments': 0,
      'cacheValidityMinutes': AppConstants.cacheValidityDuration.inMinutes,
      'documentDetails': <Map<String, dynamic>>[],
    };
  }
}