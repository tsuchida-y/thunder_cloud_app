import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// キャッシュデータの検証結果を保持するクラス
class _CacheValidation {
  final bool isValid;
  final String reason;
  final DateTime? timestamp;

  _CacheValidation({
    required this.isValid,
    required this.reason,
    this.timestamp,
  });
}

/// 気象データのFirestore取得サービスクラス
/// キャッシュされた気象データの取得と管理を行う
class WeatherCacheService {
  static final WeatherCacheService _instance = WeatherCacheService._internal();
  factory WeatherCacheService() => _instance;
  WeatherCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== 公開メソッド =====

  /// 現在地の気象データを取得（Firestoreキャッシュから）
  ///
  /// [latitude] 緯度
  /// [longitude] 経度
  ///
  /// Returns: 気象データのMap、見つからない場合はnull
  Future<Map<String, dynamic>?> getWeatherDataWithCache(
    double latitude,
    double longitude,
  ) async {
    final cacheKey = _generateCacheKey(latitude, longitude);

    AppLogger.info('Firestore気象データ取得開始', tag: 'WeatherCacheService');
    AppLogger.info('位置情報: 緯度 $latitude, 経度 $longitude', tag: 'WeatherCacheService');
    AppLogger.info('キャッシュキー: $cacheKey', tag: 'WeatherCacheService');

    try {
      final doc = await _firestore
          .collection('weather_cache')
          .doc(cacheKey)
          .get()
          .timeout(AppConstants.weatherDataTimeout);

      if (!doc.exists) {
        AppLogger.warning('ドキュメントが存在しません', tag: 'WeatherCacheService');
        return null;
      }

      final data = doc.data();
      if (data == null) {
        AppLogger.warning('ドキュメントデータがnull', tag: 'WeatherCacheService');
        return null;
      }

      final cacheValidation = _validateCacheData(data);
      if (!cacheValidation.isValid) {
        AppLogger.warning('キャッシュデータが無効: ${cacheValidation.reason}', tag: 'WeatherCacheService');
        return null;
      }

      final weatherData = data['data'] as Map<String, dynamic>;
      AppLogger.success('有効な気象データを取得', tag: 'WeatherCacheService');
      _logWeatherDataSummary(weatherData);

      return weatherData;
    } catch (e) {
      AppLogger.error('気象データ取得エラー', error: e, tag: 'WeatherCacheService');
      return null;
    }
  }

  /// リアルタイム気象データの監視ストリームを開始
  ///
  /// [latitude] 緯度
  /// [longitude] 経度
  ///
  /// Returns: 気象データの変更を監視するStream
  Stream<Map<String, dynamic>?> startRealtimeWeatherDataListener(
    double latitude,
    double longitude,
  ) {
    final cacheKey = _generateCacheKey(latitude, longitude);

    AppLogger.info('リアルタイム監視開始', tag: 'WeatherCacheService');
    AppLogger.info('監視位置: 緯度 $latitude, 経度 $longitude', tag: 'WeatherCacheService');
    AppLogger.info('監視キー: $cacheKey', tag: 'WeatherCacheService');

    return _firestore
        .collection('weather_cache')
        .doc(cacheKey)
        .snapshots()
        .map(_processRealtimeSnapshot)
        .handleError(_handleRealtimeError);
  }

  /// キャッシュの統計情報を取得
  ///
  /// Returns: キャッシュ統計のMap
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      AppLogger.info('キャッシュ統計情報取得開始', tag: 'WeatherCacheService');

      final querySnapshot = await _firestore
          .collection('weather_cache')
          .get()
          .timeout(AppConstants.weatherDataTimeout);

      final stats = _analyzeCacheStats(querySnapshot);
      _logCacheStats(stats);

      return stats;
    } catch (e) {
      AppLogger.error('キャッシュ統計取得エラー', error: e, tag: 'WeatherCacheService');
      return _createEmptyStats();
    }
  }

  // ===== プライベートメソッド =====

  /// キャッシュキーを生成
  /// 精度を下げて、より広い範囲で同じキャッシュを使用（約1km範囲）
  String _generateCacheKey(double latitude, double longitude) {
    return AppConstants.generateCacheKey(latitude, longitude);
  }

  /// キャッシュデータの有効性を検証
  _CacheValidation _validateCacheData(Map<String, dynamic> data) {
    // データフィールドの存在確認
    if (!data.containsKey('data')) {
      return _CacheValidation(
        isValid: false,
        reason: 'dataフィールドが存在しない',
      );
    }

    // タイムスタンプの確認
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    if (timestamp == null) {
      return _CacheValidation(
        isValid: false,
        reason: 'タイムスタンプが存在しない',
      );
    }

    // 有効期限の確認
    final now = DateTime.now();
    final timeDiff = now.difference(timestamp);

    if (timeDiff >= AppConstants.cacheValidityDuration) {
      return _CacheValidation(
        isValid: false,
        reason: 'データが期限切れ (${timeDiff.inMinutes}分経過)',
        timestamp: timestamp,
      );
    }

    // 気象データの存在確認
    final weatherData = data['data'];
    if (weatherData == null || weatherData is! Map) {
      return _CacheValidation(
        isValid: false,
        reason: '気象データが無効',
        timestamp: timestamp,
      );
    }

    return _CacheValidation(
      isValid: true,
      reason: '有効 (${timeDiff.inMinutes}分前のデータ)',
      timestamp: timestamp,
    );
  }

  /// 気象データのサマリーをログ出力
  void _logWeatherDataSummary(Map<String, dynamic> weatherData) {
    final keys = weatherData.keys.toList();
    AppLogger.info('気象データキー: ${keys.join(', ')}', tag: 'WeatherCacheService');

    // 主要な気象パラメータがあれば表示
    if (weatherData.containsKey('cape')) {
      AppLogger.info('CAPE: ${weatherData['cape']} J/kg', tag: 'WeatherCacheService');
    }
    if (weatherData.containsKey('temperature')) {
      AppLogger.info('気温: ${weatherData['temperature']}°C', tag: 'WeatherCacheService');
    }
  }

  /// リアルタイムスナップショットを処理
  Map<String, dynamic>? _processRealtimeSnapshot(DocumentSnapshot snapshot) {
    AppLogger.info('リアルタイム更新受信: ${snapshot.exists ? 'データあり' : 'データなし'}', tag: 'WeatherCacheService');

    if (!snapshot.exists) {
      AppLogger.warning('リアルタイム: ドキュメントが存在しません', tag: 'WeatherCacheService');
      return null;
    }

    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) {
      AppLogger.warning('リアルタイム: ドキュメントデータがnull', tag: 'WeatherCacheService');
      return null;
    }

    final cacheValidation = _validateCacheData(data);
    if (!cacheValidation.isValid) {
      AppLogger.warning('リアルタイム: ${cacheValidation.reason}', tag: 'WeatherCacheService');
      return null;
    }

    final weatherData = data['data'] as Map<String, dynamic>;
    AppLogger.success('リアルタイム: 有効な気象データを受信', tag: 'WeatherCacheService');
    _logWeatherDataSummary(weatherData);

    return weatherData;
  }

  /// リアルタイム監視のエラーハンドリング
  void _handleRealtimeError(Object error) {
    AppLogger.error('リアルタイム監視エラー', error: error, tag: 'WeatherCacheService');
    AppLogger.error('エラータイプ: ${error.runtimeType}', tag: 'WeatherCacheService');
  }

  /// キャッシュ統計を分析
  Map<String, dynamic> _analyzeCacheStats(QuerySnapshot querySnapshot) {
    final now = DateTime.now();
    final documents = querySnapshot.docs;

    int validEntries = 0;
    final List<String> allCacheKeys = [];
    final List<String> validCacheKeys = [];

    for (final doc in documents) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

      allCacheKeys.add(doc.id);

      if (timestamp != null &&
          now.difference(timestamp) < AppConstants.cacheValidityDuration) {
        validEntries++;
        validCacheKeys.add(doc.id);
      }
    }

    return {
      'totalEntries': documents.length,
      'validEntries': validEntries,
      'expiredEntries': documents.length - validEntries,
      'cacheValidityMinutes': AppConstants.cacheValidityDuration.inMinutes,
      'allCacheKeys': allCacheKeys,
      'validCacheKeys': validCacheKeys,
      'validityRate': documents.isNotEmpty
          ? (validEntries / documents.length * 100).toStringAsFixed(1)
          : '0.0',
    };
  }

  /// キャッシュ統計をログ出力
  void _logCacheStats(Map<String, dynamic> stats) {
    final total = stats['totalEntries'] as int;
    final valid = stats['validEntries'] as int;
    final expired = stats['expiredEntries'] as int;
    final validityRate = stats['validityRate'] as String;
    final validityMinutes = stats['cacheValidityMinutes'] as int;

    AppLogger.info('=== キャッシュ統計情報 ===', tag: 'WeatherCacheService');
    AppLogger.info('全キャッシュ数: $total', tag: 'WeatherCacheService');
    AppLogger.info('有効キャッシュ数: $valid', tag: 'WeatherCacheService');
    AppLogger.info('期限切れキャッシュ数: $expired', tag: 'WeatherCacheService');
    AppLogger.info('有効率: $validityRate%', tag: 'WeatherCacheService');
    AppLogger.info('キャッシュ有効期限: $validityMinutes分', tag: 'WeatherCacheService');

    if (total > 0) {
      final allKeys = stats['allCacheKeys'] as List<String>;
      final validKeys = stats['validCacheKeys'] as List<String>;

      AppLogger.info('全キャッシュキー: ${allKeys.take(3).join(', ')}${allKeys.length > 3 ? '...' : ''}', tag: 'WeatherCacheService');
      AppLogger.info('有効キーの例: ${validKeys.take(3).join(', ')}${validKeys.length > 3 ? '...' : ''}', tag: 'WeatherCacheService');
    }
  }

  /// 空の統計情報を作成
  Map<String, dynamic> _createEmptyStats() {
    return {
      'totalEntries': 0,
      'validEntries': 0,
      'expiredEntries': 0,
      'cacheValidityMinutes': AppConstants.cacheValidityDuration.inMinutes,
      'allCacheKeys': <String>[],
      'validCacheKeys': <String>[],
      'validityRate': '0.0',
    };
  }
}
