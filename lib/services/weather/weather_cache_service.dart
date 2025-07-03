import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// キャッシュデータの検証結果を保持するクラス
/// データの有効性と理由、タイムスタンプを管理
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
/// シングルトンパターンで実装され、アプリ全体で1つのインスタンスを共有
class WeatherCacheService {
  /*
  ================================================================================
                                    シングルトン
                          アプリ全体で共有する単一インスタンス
  ================================================================================
  */
  static final WeatherCacheService _instance = WeatherCacheService._internal();
  factory WeatherCacheService() => _instance;
  WeatherCacheService._internal();

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

  /// 現在地の気象データを取得（Firestoreキャッシュから）
  /// キャッシュキー生成、データ検証、エラーハンドリングを統合
  ///
  /// [latitude] 緯度（例：35.6762）
  /// [longitude] 経度（例：139.6503）
  ///
  /// Returns: 気象データのMap、見つからない場合はnull
  Future<Map<String, dynamic>?> getWeatherDataWithCache(
    double latitude,
    double longitude,
  ) async {
    // ステップ1: キャッシュキーの生成
    final cacheKey = _generateCacheKey(latitude, longitude);
    // 例：東京（35.6762, 139.6503）→ "weather_35.68_139.65"

    AppLogger.info('Firestore気象データ取得開始', tag: 'WeatherCacheService');
    AppLogger.info('位置情報: 緯度 ${latitude.toStringAsFixed(2)}, 経度 ${longitude.toStringAsFixed(2)}', tag: 'WeatherCacheService');
    AppLogger.info('キャッシュキー: $cacheKey', tag: 'WeatherCacheService');

    try {
      // ステップ2: Firestoreからドキュメントを取得
      // weather_cacheコレクションから指定されたキーのドキュメントを取得
      final doc = await _firestore
          .collection('weather_cache')
          .doc(cacheKey)
          .get()
          .timeout(AppConstants.weatherDataTimeout);//10秒でタイムアウト

      // ステップ3: ドキュメントの存在確認
      if (!doc.exists) {
        AppLogger.warning('ドキュメントが存在しません', tag: 'WeatherCacheService');
        return null;
      }

      // ステップ4: データの抽出とnullチェック
      final data = doc.data();
      if (data == null) {
        AppLogger.warning('ドキュメントデータがnull', tag: 'WeatherCacheService');
        return null;
      }

      // ステップ5: キャッシュデータの有効性検証
      final cacheValidation = _validateCacheData(data);
      if (!cacheValidation.isValid) {
        AppLogger.warning('キャッシュデータが無効: ${cacheValidation.reason}', tag: 'WeatherCacheService');
        return null;
      }

      // ステップ6: 気象データの抽出と返却
      final weatherData = data['data'] as Map<String, dynamic>;
      AppLogger.success('有効な気象データを取得', tag: 'WeatherCacheService');

      return weatherData;
    } catch (e) {
      // エラーハンドリング: ネットワークエラーやタイムアウトの対処
      AppLogger.error('気象データ取得エラー', error: e, tag: 'WeatherCacheService');
      return null;
    }
  }

  /// リアルタイム気象データの監視ストリームを開始
  /// Firestoreのリアルタイムリスナーを使用してデータ変更を監視
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
    AppLogger.info('監視位置: 緯度 ${latitude.toStringAsFixed(2)}, 経度 ${longitude.toStringAsFixed(2)}', tag: 'WeatherCacheService');
    AppLogger.info('監視キー: $cacheKey', tag: 'WeatherCacheService');

    // Firestoreのリアルタイムリスナーを設定
    // データ変更時に自動的に新しいデータを取得
    return _firestore
        .collection('weather_cache')
        .doc(cacheKey)
        .snapshots()
        .map(_processRealtimeSnapshot)
        .handleError(_handleRealtimeError);
  }

  /*
  ================================================================================
                                キャッシュ管理機能
                       キャッシュの統計・分析・クリア処理
  ================================================================================
  */

  /// キャッシュの統計情報を取得
  /// 全キャッシュエントリの有効性と健全性を分析
  ///
  /// Returns: キャッシュ統計のMap（総数、有効数、有効率など）
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      AppLogger.info('キャッシュ統計情報取得開始', tag: 'WeatherCacheService');

      // 全キャッシュドキュメントを取得
      final querySnapshot = await _firestore
          .collection('weather_cache')
          .get()
          .timeout(AppConstants.weatherDataTimeout);

      // 統計情報の分析とログ出力
      final stats = _analyzeCacheStats(querySnapshot);
      _logCacheStats(stats);

      return stats;
    } catch (e) {
      // エラー時は空の統計情報を返す
      AppLogger.error('キャッシュ統計取得エラー', error: e, tag: 'WeatherCacheService');
      return _createEmptyStats();
    }
  }

  /// 特定位置のキャッシュをクリア
  /// 古いデータや無効なデータを削除してストレージを最適化
  ///
  /// [latitude] 緯度
  /// [longitude] 経度
  ///
  /// Returns: クリアが成功したかどうか
  Future<bool> clearCacheForLocation(double latitude, double longitude) async {
    try {
      final cacheKey = _generateCacheKey(latitude, longitude);
      AppLogger.info('キャッシュクリア開始: $cacheKey', tag: 'WeatherCacheService');

      // Firestoreから指定されたドキュメントを削除
      await _firestore
          .collection('weather_cache')
          .doc(cacheKey)
          .delete()
          .timeout(AppConstants.weatherDataTimeout);

      AppLogger.success('キャッシュクリア完了: $cacheKey', tag: 'WeatherCacheService');
      return true;
    } catch (e) {
      // 削除失敗時はfalseを返す
      AppLogger.error('キャッシュクリアエラー', error: e, tag: 'WeatherCacheService');
      return false;
    }
  }

  /*
  ================================================================================
                                ユーティリティメソッド
                        補助的な処理・データ検証・キー生成
  ================================================================================
  */

  /// キャッシュキーを生成
  /// 精度を下げて、より広い範囲で同じキャッシュを使用（約1km範囲）
  /// これにより、近い位置での重複キャッシュを防ぎ、ストレージを効率化
  String _generateCacheKey(double latitude, double longitude) {
    return AppConstants.generateCacheKey(latitude, longitude);
  }

  /// キャッシュデータの有効性を検証
  /// データの完全性、タイムスタンプ、有効期限を段階的にチェック
  _CacheValidation _validateCacheData(Map<String, dynamic> data) {
    // ステップ1: データフィールドの存在確認
    if (!data.containsKey('data')) {
      return _CacheValidation(
        isValid: false,
        reason: 'dataフィールドが存在しない',
      );
    }

    // ステップ2: タイムスタンプの確認
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    if (timestamp == null) {
      return _CacheValidation(
        isValid: false,
        reason: 'タイムスタンプが存在しない',
      );
    }

    // ステップ3: 有効期限の確認
    final now = DateTime.now();
    final timeDiff = now.difference(timestamp);

    if (timeDiff >= AppConstants.cacheValidityDuration) {
      return _CacheValidation(
        isValid: false,
        reason: 'データが期限切れ (${timeDiff.inMinutes}分経過)',
        timestamp: timestamp,
      );
    }

    // ステップ4: 気象データの存在確認
    final weatherData = data['data'];
    if (weatherData == null || weatherData is! Map) {
      return _CacheValidation(
        isValid: false,
        reason: '気象データが無効',
        timestamp: timestamp,
      );
    }

    // ステップ5: 有効なデータとして返却
    return _CacheValidation(
      isValid: true,
      reason: '有効 (${timeDiff.inMinutes}分前のデータ)',
      timestamp: timestamp,
    );
  }

  /*
  ================================================================================
                                リアルタイム処理
                        Firestoreリアルタイムリスナーの処理
  ================================================================================
  */

  /// リアルタイムスナップショットを処理
  /// Firestoreからのリアルタイム更新を検証して気象データを抽出
  Map<String, dynamic>? _processRealtimeSnapshot(DocumentSnapshot snapshot) {
    AppLogger.info('リアルタイム更新受信: ${snapshot.exists ? 'データあり' : 'データなし'}', tag: 'WeatherCacheService');

    // ステップ1: ドキュメントの存在確認
    if (!snapshot.exists) {
      AppLogger.warning('リアルタイム: ドキュメントが存在しません', tag: 'WeatherCacheService');
      return null;
    }

    // ステップ2: データの抽出とnullチェック
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) {
      AppLogger.warning('リアルタイム: ドキュメントデータがnull', tag: 'WeatherCacheService');
      return null;
    }

    // ステップ3: キャッシュデータの有効性検証
    final cacheValidation = _validateCacheData(data);
    if (!cacheValidation.isValid) {
      AppLogger.warning('リアルタイム: ${cacheValidation.reason}', tag: 'WeatherCacheService');
      return null;
    }

    // ステップ4: 気象データの抽出と返却
    final weatherData = data['data'] as Map<String, dynamic>;
    AppLogger.success('リアルタイム: 有効な気象データを受信', tag: 'WeatherCacheService');

    return weatherData;
  }

  /// リアルタイム監視のエラーハンドリング
  /// Streamのエラーを適切に処理してログ出力
  void _handleRealtimeError(Object error) {
    AppLogger.error('リアルタイム監視エラー', error: error, tag: 'WeatherCacheService');
    AppLogger.error('エラータイプ: ${error.runtimeType}', tag: 'WeatherCacheService');
  }

  /*
  ================================================================================
                                統計分析機能
                       キャッシュデータの分析とレポート生成
  ================================================================================
  */

  /// キャッシュ統計を分析
  /// QuerySnapshotから統計情報を抽出して構造化データを生成
  Map<String, dynamic> _analyzeCacheStats(QuerySnapshot querySnapshot) {
    final now = DateTime.now();
    final documents = querySnapshot.docs;

    // 統計変数の初期化
    int validEntries = 0;
    final List<String> allCacheKeys = [];
    final List<String> validCacheKeys = [];

    // ステップ1: 各ドキュメントの分析
    for (final doc in documents) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

      allCacheKeys.add(doc.id);

      // 有効期限チェック
      if (timestamp != null &&
          now.difference(timestamp) < AppConstants.cacheValidityDuration) {
        validEntries++;
        validCacheKeys.add(doc.id);
      }
    }

    // ステップ2: 統計情報の構造化
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
  /// 分析結果を見やすい形式でログに出力
  void _logCacheStats(Map<String, dynamic> stats) {
    // 統計データの抽出
    final total = stats['totalEntries'] as int;
    final valid = stats['validEntries'] as int;
    final expired = stats['expiredEntries'] as int;
    final validityRate = stats['validityRate'] as String;
    final validityMinutes = stats['cacheValidityMinutes'] as int;

    // ステップ1: 基本統計の出力
    AppLogger.info('=== キャッシュ統計情報 ===', tag: 'WeatherCacheService');
    AppLogger.info('全キャッシュ数: $total', tag: 'WeatherCacheService');
    AppLogger.info('有効キャッシュ数: $valid', tag: 'WeatherCacheService');
    AppLogger.info('期限切れキャッシュ数: $expired', tag: 'WeatherCacheService');
    AppLogger.info('有効率: $validityRate%', tag: 'WeatherCacheService');
    AppLogger.info('キャッシュ有効期限: $validityMinutes分', tag: 'WeatherCacheService');

    // ステップ2: 詳細情報の出力（データが存在する場合のみ）
    if (total > 0) {
      final allKeys = stats['allCacheKeys'] as List<String>;
      final validKeys = stats['validCacheKeys'] as List<String>;

      AppLogger.info('全キャッシュキー: ${allKeys.take(3).join(', ')}${allKeys.length > 3 ? '...' : ''}', tag: 'WeatherCacheService');
      AppLogger.info('有効キーの例: ${validKeys.take(3).join(', ')}${validKeys.length > 3 ? '...' : ''}', tag: 'WeatherCacheService');
    }
  }

  /// 空の統計情報を作成
  /// エラー時やデータが存在しない場合のフォールバック用
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
