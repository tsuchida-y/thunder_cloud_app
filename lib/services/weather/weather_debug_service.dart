import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// 気象データのデバッグ用サービスクラス
/// 開発・テスト用途でFirestoreの気象データを確認・分析するためのサービス
class WeatherDebugService {
  static final WeatherDebugService _instance = WeatherDebugService._internal();
  factory WeatherDebugService() => _instance;
  WeatherDebugService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== 公開メソッド =====

  /// 指定座標の気象データを取得してデバッグ情報を表示
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
      final cacheKey = _generateCacheKey(latitude, longitude);
      final doc = await _firestore
          .collection('weather_cache')
          .doc(cacheKey)
          .get()
          .timeout(AppConstants.weatherDataTimeout);

      if (!doc.exists) {
        AppLogger.warning('Firestoreにデータが見つかりません', tag: 'WeatherDebugService');
        return null;
      }

      final data = doc.data();
      if (data == null || !data.containsKey('data')) {
        AppLogger.warning('ドキュメントにデータフィールドがありません', tag: 'WeatherDebugService');
        return null;
      }

      final weatherData = data['data'] as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

      AppLogger.success('Firestoreからデータを取得', tag: 'WeatherDebugService');
      AppLogger.info('データ取得時刻: ${timestamp?.toString() ?? 'N/A'}', tag: 'WeatherDebugService');

      _logWeatherDetails(weatherData);

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
      final cacheKey = _generateDirectionalCacheKey(currentLocation);
      final doc = await _firestore
          .collection('weather_cache')
          .doc(cacheKey)
          .get()
          .timeout(AppConstants.weatherDataTimeout);

      if (!doc.exists) {
        AppLogger.warning('Firestoreに複数方向データが見つかりません', tag: 'WeatherDebugService');
        return null;
      }

      final data = doc.data();
      if (data == null || !data.containsKey('data')) {
        AppLogger.warning('ドキュメントにデータフィールドがありません', tag: 'WeatherDebugService');
        return null;
      }

      final directionalData = Map<String, Map<String, dynamic>>.from(
        data['data'].cast<String, Map<String, dynamic>>()
      );
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

      AppLogger.success('Firestoreから複数方向データを取得', tag: 'WeatherDebugService');
      AppLogger.info('データ取得時刻: ${timestamp?.toString() ?? 'N/A'}', tag: 'WeatherDebugService');
      AppLogger.info('取得方向数: ${directionalData.length}', tag: 'WeatherDebugService');

      _logDirectionalData(directionalData);

      return directionalData;
    } catch (e) {
      AppLogger.error('複数方向気象データデバッグエラー', error: e, tag: 'WeatherDebugService');
      return null;
    }
  }

  /// Firestoreの気象データ状況を確認
  ///
  /// 全体的なキャッシュ状況とデータの健全性をチェック
  Future<Map<String, dynamic>> debugFirestoreStatus() async {
    AppLogger.info('Firestore気象データ状況確認開始', tag: 'WeatherDebugService');

    try {
      final querySnapshot = await _firestore
          .collection('weather_cache')
          .get()
          .timeout(AppConstants.weatherDataTimeout);

      final statusInfo = _analyzeFirestoreStatus(querySnapshot);
      _logFirestoreStatus(statusInfo);

      return statusInfo;
    } catch (e) {
      AppLogger.error('Firestore状況確認エラー', error: e, tag: 'WeatherDebugService');
      return _createEmptyStatusInfo();
    }
  }

  // ===== プライベートメソッド =====

  /// キャッシュキーを生成（単一座標用）
  String _generateCacheKey(double latitude, double longitude) {
    return AppConstants.generateCacheKey(latitude, longitude);
  }

  /// 複数方向用のキャッシュキーを生成
  String _generateDirectionalCacheKey(LatLng location) {
    return 'weather_${location.latitude.toStringAsFixed(4)}_${location.longitude.toStringAsFixed(4)}';
  }

  /// 気象データの詳細をログ出力
  void _logWeatherDetails(Map<String, dynamic> weatherData) {
    AppLogger.info('=== 気象データ詳細 ===', tag: 'WeatherDebugService');

    final details = _extractWeatherDetails(weatherData);
    for (final detail in details) {
      AppLogger.info(detail, tag: 'WeatherDebugService');
    }
  }

  /// 気象データの詳細情報を抽出
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
  String _formatValue(dynamic value, {int decimals = 1}) {
    if (value == null) return 'N/A';
    if (value is num) {
      return value.toStringAsFixed(decimals);
    }
    return value.toString();
  }

  /// 分析結果の詳細をログ出力
  void _logAnalysisDetails(Map<String, dynamic> analysis) {
    AppLogger.info('=== 入道雲分析結果 ===', tag: 'WeatherDebugService');

    final isLikely = analysis['isLikely'] == true;
    final totalScore = (analysis['totalScore'] ?? 0) * 100;

    AppLogger.info('判定: ${isLikely ? '入道雲の可能性あり' : '入道雲なし'}', tag: 'WeatherDebugService');
    AppLogger.info('総合スコア: ${totalScore.toStringAsFixed(1)}%', tag: 'WeatherDebugService');
    AppLogger.info('リスクレベル: ${analysis['riskLevel'] ?? 'N/A'}', tag: 'WeatherDebugService');

    _logDetailedScores(analysis);
    _logAnalysisFactors(analysis);
  }

  /// 詳細スコアをログ出力
  void _logDetailedScores(Map<String, dynamic> analysis) {
    AppLogger.info('詳細スコア:', tag: 'WeatherDebugService');

    final scores = [
      ('CAPE', analysis['capeScore']),
      ('Lifted Index', analysis['liScore']),
      ('CIN', analysis['cinScore']),
      ('温度', analysis['tempScore']),
    ];

    for (final (name, score) in scores) {
      final percentage = ((score ?? 0) * 100).toStringAsFixed(1);
      AppLogger.info('  - $name: $percentage%', tag: 'WeatherDebugService');
    }
  }

  /// 分析要因をログ出力
  void _logAnalysisFactors(Map<String, dynamic> analysis) {
    if (!analysis.containsKey('factors')) return;

    final factors = analysis['factors'] as Map<String, dynamic>? ?? {};
    if (factors.isEmpty) return;

    AppLogger.info('判定要因:', tag: 'WeatherDebugService');
    factors.forEach((key, value) {
      AppLogger.info('  - $key: $value', tag: 'WeatherDebugService');
    });
  }

  /// 方向別データをログ出力
  void _logDirectionalData(Map<String, Map<String, dynamic>> directionalData) {
    for (final direction in AppConstants.checkDirections) {
      if (directionalData.containsKey(direction)) {
        AppLogger.info('=== [$direction方向] デバッグ情報 ===', tag: 'WeatherDebugService');
        _logWeatherDetails(directionalData[direction]!);

        if (directionalData[direction]!.containsKey('analysis')) {
          _logAnalysisDetails(directionalData[direction]!['analysis']);
        }
      } else {
        AppLogger.warning('[$direction方向] データなし', tag: 'WeatherDebugService');
      }
    }
  }

  /// Firestoreの状況を分析
  Map<String, dynamic> _analyzeFirestoreStatus(QuerySnapshot querySnapshot) {
    final now = DateTime.now();
    final documents = querySnapshot.docs;

    int validDocuments = 0;
    int expiredDocuments = 0;
    final List<Map<String, dynamic>> documentDetails = [];

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

    return {
      'totalDocuments': documents.length,
      'validDocuments': validDocuments,
      'expiredDocuments': expiredDocuments,
      'cacheValidityMinutes': AppConstants.cacheValidityDuration.inMinutes,
      'documentDetails': documentDetails,
    };
  }

  /// Firestoreの状況をログ出力
  void _logFirestoreStatus(Map<String, dynamic> statusInfo) {
    final total = statusInfo['totalDocuments'] as int;
    final valid = statusInfo['validDocuments'] as int;
    final expired = statusInfo['expiredDocuments'] as int;
    final validityMinutes = statusInfo['cacheValidityMinutes'] as int;

    AppLogger.info('総ドキュメント数: $total', tag: 'WeatherDebugService');
    AppLogger.info('有効ドキュメント数: $valid', tag: 'WeatherDebugService');
    AppLogger.info('期限切れドキュメント数: $expired', tag: 'WeatherDebugService');
    AppLogger.info('キャッシュ有効期限: $validityMinutes分', tag: 'WeatherDebugService');

    if (total == 0) {
      AppLogger.warning('Firestoreに気象データが存在しません', tag: 'WeatherDebugService');
      AppLogger.info('Firebase Functionsによる自動データ取得を確認してください', tag: 'WeatherDebugService');
      return;
    }

    _logDocumentDetails(statusInfo['documentDetails'] as List<Map<String, dynamic>>);
  }

  /// ドキュメントの詳細をログ出力
  void _logDocumentDetails(List<Map<String, dynamic>> documentDetails) {
    for (final detail in documentDetails.take(5)) { // 最初の5件のみ表示
      final id = detail['id'] as String;
      final timestamp = detail['timestamp'] as DateTime?;
      final ageMinutes = detail['ageMinutes'] as int?;
      final isValid = detail['isValid'] as bool;
      final hasData = detail['hasData'] as bool;
      final dataKeys = detail['dataKeys'] as List;

      AppLogger.info('--- ドキュメント: $id ---', tag: 'WeatherDebugService');
      AppLogger.info('データ時刻: ${timestamp?.toString() ?? 'N/A'}', tag: 'WeatherDebugService');
      AppLogger.info('経過時間: ${ageMinutes != null ? '$ageMinutes分前' : 'N/A'}', tag: 'WeatherDebugService');
      AppLogger.info('有効性: ${isValid ? '有効' : '期限切れ'}', tag: 'WeatherDebugService');
      AppLogger.info('データ存在: ${hasData ? 'あり' : 'なし'}', tag: 'WeatherDebugService');

      if (dataKeys.isNotEmpty) {
        AppLogger.info('データキー: ${dataKeys.join(', ')}', tag: 'WeatherDebugService');
      }
    }

    if (documentDetails.length > 5) {
      AppLogger.info('... 他${documentDetails.length - 5}件のドキュメント', tag: 'WeatherDebugService');
    }
  }

  /// 空の状況情報を作成
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