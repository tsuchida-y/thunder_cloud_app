// lib/services/location_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// 位置情報サービス
/// GPS位置情報の取得、監視、キャッシュ管理を行う
/// 静的メソッドで実装され、アプリ全体で共有される
class LocationService {
  /*
  ================================================================================
                                    状態管理
                          位置情報のキャッシュと状態管理
  ================================================================================
  */
  /// キャッシュされた位置情報（メモリ効率化のため）
  static LatLng? _cachedLocation;

  /// 最終位置情報更新時刻（キャッシュの有効性管理用）
  static DateTime? _lastLocationUpdate;

  /// 位置情報監視のストリームサブスクリプション
  static StreamSubscription<Position>? _positionStream;

  /// 位置変更時のコールバック関数
  static Function(LatLng)? onLocationChanged;

  /*
  ================================================================================
                                    設定値
                          サービスの動作を制御する定数
  ================================================================================
  */
  /// 位置情報の有効期限（10分から1時間に延長）
  static const Duration _locationValidityDuration = Duration(hours: 1);

  /*
  ================================================================================
                                データ取得機能
                        GPS・Firestoreからの位置情報取得
  ================================================================================
  */

  /// 高速な位置情報取得（並列処理）
  /// FirestoreとGPSの取得を並列で実行し、最初に取得できた結果を返す
  /// パフォーマンス最適化により、ユーザー体験を向上
  ///
  /// [forceRefresh] 強制的に新しい位置情報を取得するかどうか
  /// [userId] ユーザーID（Firestore検索用、未指定時はAppConstantsから取得）
  ///
  /// Returns: 現在位置のLatLng、取得失敗時はnull
  static Future<LatLng?> getLocationFast({
    bool forceRefresh = false,
    String? userId,
  }) async {
    try {
      AppLogger.info('高速位置情報取得開始 (forceRefresh: $forceRefresh)', tag: 'LocationService');

      // ステップ1: キャッシュの有効性チェック
      if (!forceRefresh && _isLocationValid()) {
        AppLogger.info('キャッシュされた位置情報を使用: $_cachedLocation', tag: 'LocationService');
        return _cachedLocation;
      }

      // ステップ2: FirestoreとGPSを並列で実行
      final results = await Future.wait([
        _getLocationFromFirestore(userId),
        _getCurrentPositionWithRetry(),
      ], eagerError: false);

      LatLng? firestoreLocation;
      LatLng? gpsLocation;

      // ステップ3: Firestoreの結果を処理
      if (results[0] != null) {
        firestoreLocation = results[0] as LatLng;
        AppLogger.info('Firestoreから位置情報取得成功: $firestoreLocation', tag: 'LocationService');
      }

      // ステップ4: GPSの結果を処理
      if (results[1] != null) {
        final position = results[1] as Position;
        gpsLocation = LatLng(position.latitude, position.longitude);
        AppLogger.info('GPSから位置情報取得成功: $gpsLocation', tag: 'LocationService');
      }

      // ステップ5: より正確なGPS位置情報を優先、なければFirestore位置情報を使用
      final selectedLocation = gpsLocation ?? firestoreLocation;

      if (selectedLocation != null) {
        _cacheLocation(selectedLocation);
        AppLogger.success('高速位置情報取得完了: $selectedLocation', tag: 'LocationService');

        // ステップ6: GPS位置情報が取得できた場合、Firestoreにも保存
        if (gpsLocation != null) {
          _saveLocationToFirestoreAsync(gpsLocation, userId);
        }

        return selectedLocation;
      }

      AppLogger.warning('並列位置情報取得失敗', tag: 'LocationService');
      return _cachedLocation; // 全て失敗した場合はキャッシュされた位置を返す

    } catch (e) {
      AppLogger.error('高速位置情報取得エラー', error: e, tag: 'LocationService');
      return _cachedLocation;
    }
  }

  /// 現在位置をLatLng形式で取得
  /// 単純なGPS取得処理（高速取得の代替手段）
  ///
  /// [forceRefresh] 強制的に新しい位置情報を取得するかどうか
  ///
  /// Returns: 現在位置のLatLng、取得失敗時はnull
  static Future<LatLng?> getCurrentLocationAsLatLng({bool forceRefresh = false}) async {
    try {
      AppLogger.info('位置情報取得開始 (forceRefresh: $forceRefresh)', tag: 'LocationService');

      // ステップ1: キャッシュの有効性チェック
      if (!forceRefresh && _isLocationValid()) {
        AppLogger.info('キャッシュされた位置情報を使用: $_cachedLocation', tag: 'LocationService');
        return _cachedLocation;
      }

      // ステップ2: GPSから位置情報を取得
      final position = await _getCurrentPositionWithRetry();
      final newLocation = LatLng(position.latitude, position.longitude);

      // ステップ3: 位置情報をキャッシュ
      _cacheLocation(newLocation);
      AppLogger.success('新しい位置情報を取得: $newLocation', tag: 'LocationService');

      return newLocation;
    } catch (e) {
      AppLogger.error('位置情報取得エラー', error: e, tag: 'LocationService');
      return _cachedLocation; // エラー時はキャッシュされた位置を返す
    }
  }

  /*
  ================================================================================
                                監視機能
                       位置情報の継続的な監視と更新
  ================================================================================
  */

  /// 位置情報の監視を開始
  /// 継続的な位置情報更新により、リアルタイムな位置変化を検知
  static void startLocationMonitoring() {
    if (_positionStream != null) {
      AppLogger.warning('位置監視は既に開始されています', tag: 'LocationService');
      return;
    }

    AppLogger.info('位置情報監視開始', tag: 'LocationService');

    // ステップ1: Geolocatorの位置ストリームを設定
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: AppConstants.locationAccuracy,
        distanceFilter: AppConstants.locationUpdateDistanceFilter.toInt(),
      ),
    ).listen(
      _handleLocationUpdate,  // 位置更新時の処理
      onError: _handleLocationError,  // エラー時の処理
    );
  }

  /// 位置情報監視を停止
  /// リソースの解放とメモリリークの防止
  static void stopLocationMonitoring() {
    _positionStream?.cancel();
    _positionStream = null;
    AppLogger.info('位置情報監視停止', tag: 'LocationService');
  }

  /*
  ================================================================================
                                ユーティリティメソッド
                        補助的な処理・計算・状態取得
  ================================================================================
  */

  /// 2つの位置間の距離を計算（メートル単位）
  /// 直線距離を計算して、意味のある移動かどうかを判定
  static double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// 現在のキャッシュされた位置情報
  static LatLng? get cachedLocation => _cachedLocation;

  /*
  ================================================================================
                                画面遷移対応
                        UIの応答性を保つための軽量処理
  ================================================================================
  */

  /// 画面遷移用の高速位置情報取得
  /// 画面遷移時に使用する軽量版。キャッシュを優先し、
  /// 必要時のみバックグラウンドで更新
  static LatLng? getLocationForScreenTransition() {
    AppLogger.info('画面遷移用位置情報取得', tag: 'LocationService');

    // ステップ1: デバッグ情報を出力
    _logLocationServiceStatus();

    // ステップ2: キャッシュが存在する場合は即座に返す
    if (_cachedLocation != null) {
      AppLogger.info('キャッシュされた位置情報を即座に返却: $_cachedLocation', tag: 'LocationService');

      // ステップ3: バックグラウンドで位置情報を更新（UIをブロックしない）
      _updateLocationInBackground();

      return _cachedLocation;
    }

    AppLogger.warning('キャッシュされた位置情報がありません', tag: 'LocationService');
    return null;
  }

  /*
  ================================================================================
                                デバッグ・ログ機能
                        開発・トラブルシューティング支援
  ================================================================================
  */

  /// LocationServiceの状態をログ出力（デバッグ用）
  /// サービスの健全性とパフォーマンスを監視
  static void _logLocationServiceStatus() {
    final status = getLocationStatus();
    AppLogger.info('LocationService状態: '
        'hasLocation=${status.hasLocation}, '
        'isValid=${status.isValid}, '
        'lastUpdate=${status.lastUpdate}, '
        'isMonitoring=${status.isMonitoring}',
        tag: 'LocationService');

    if (_cachedLocation != null) {
      AppLogger.info('キャッシュされた位置: $_cachedLocation', tag: 'LocationService');
    } else {
      AppLogger.warning('位置情報キャッシュが存在しません', tag: 'LocationService');
    }

    if (_lastLocationUpdate != null) {
      final timeSinceUpdate = DateTime.now().difference(_lastLocationUpdate!);
      AppLogger.info('最終更新からの経過時間: ${timeSinceUpdate.inMinutes}分${timeSinceUpdate.inSeconds % 60}秒',
          tag: 'LocationService');
    }
  }

  /*
  ================================================================================
                                バックグラウンド処理
                        UIをブロックしない非同期更新
  ================================================================================
  */

  /// バックグラウンドで位置情報を更新
  /// UIの応答性を保ちながら、最新の位置情報を取得
  static void _updateLocationInBackground() {
    // ステップ1: 更新頻度の制御（前回更新から30分以上経過している場合のみ更新）
    if (_lastLocationUpdate != null) {
      final timeSinceUpdate = DateTime.now().difference(_lastLocationUpdate!);
      if (timeSinceUpdate < const Duration(minutes: 30)) {
        AppLogger.debug('位置情報は最新のためバックグラウンド更新をスキップ (経過時間: ${timeSinceUpdate.inMinutes}分)', tag: 'LocationService');
        return;
      }
    }

    // ステップ2: マイクロタスクで非同期実行（UIをブロックしない）
    Future.microtask(() async {
      try {
        AppLogger.info('バックグラウンドで位置情報を更新中', tag: 'LocationService');
        final newLocation = await getLocationFast(forceRefresh: true);

        if (newLocation != null) {
          AppLogger.success('バックグラウンド位置情報更新完了: $newLocation', tag: 'LocationService');

          // ステップ3: 位置変更コールバックがあれば実行
          onLocationChanged?.call(newLocation);
        }
      } catch (e) {
        AppLogger.error('バックグラウンド位置情報更新エラー', error: e, tag: 'LocationService');
      }
    });
  }

  /*
  ================================================================================
                                状態管理機能
                        サービスの状態取得とリソース管理
  ================================================================================
  */

  /// 位置情報サービスの状態を取得
  /// サービスの健全性と動作状況を監視
  static LocationServiceStatus getLocationStatus() {
    return LocationServiceStatus(
      hasLocation: _cachedLocation != null,
      isValid: _isLocationValid(),
      lastUpdate: _lastLocationUpdate,
      isMonitoring: _positionStream != null,
      location: _cachedLocation,
    );
  }

  /// リソースのクリーンアップ
  /// メモリリークの防止とリソースの適切な解放
  static void dispose() {
    stopLocationMonitoring();
    _cachedLocation = null;
    _lastLocationUpdate = null;
    onLocationChanged = null;
    AppLogger.info('LocationService リソースクリーンアップ完了', tag: 'LocationService');
  }

  /*
  ================================================================================
                                プライベートメソッド
                        内部処理・データ取得・検証機能
  ================================================================================
  */

  /// Firestoreから位置情報を取得
  /// ユーザーIDに基づいて保存された位置情報を取得
  ///
  /// [userId] ユーザーID（nullの場合はAppConstantsから取得）
  /// Returns: 位置情報のLatLng、見つからない場合はnull
  static Future<LatLng?> _getLocationFromFirestore(String? userId) async {
    try {
      AppLogger.info('Firestoreから位置情報取得開始', tag: 'LocationService');

      // ステップ1: ユーザーIDの決定
      final actualUserId = userId ?? await AppConstants.getCurrentUserId();

      // ステップ2: Firestoreからユーザードキュメントを取得
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(actualUserId)
          .get()
          .timeout(const Duration(seconds: 5)); // 短いタイムアウト

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
            final location = LatLng(latitude, longitude);
            AppLogger.info('Firestoreから位置情報取得成功: $location', tag: 'LocationService');
            return location;
          }
        }
      }

      AppLogger.info('Firestoreに位置情報が保存されていません', tag: 'LocationService');
      return null;
    } catch (e) {
      AppLogger.warning('Firestoreからの位置情報取得エラー: $e', tag: 'LocationService');
      return null;
    }
  }

  /// Firestoreに位置情報を非同期で保存
  /// メイン処理をブロックしない非同期保存処理
  ///
  /// [location] 保存する位置情報
  /// [userId] ユーザーID（nullの場合はAppConstantsから取得）
  static void _saveLocationToFirestoreAsync(LatLng location, String? userId) {
    // ステップ1: 非同期で実行し、エラーが発生してもメイン処理をブロックしない
    Future.microtask(() async {
      try {
        final actualUserId = userId ?? await AppConstants.getCurrentUserId();

        // ステップ2: 緯度・経度を小数点第2位までに丸めて保存（精度の最適化）
        final roundedLatitude = double.parse(location.latitude.toStringAsFixed(2));
        final roundedLongitude = double.parse(location.longitude.toStringAsFixed(2));

        // ステップ3: Firestoreにデータを保存
        await FirebaseFirestore.instance
            .collection('users')
            .doc(actualUserId)
            .set({
          'latitude': roundedLatitude,
          'longitude': roundedLongitude,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        AppLogger.info('位置情報をFirestoreに非同期保存完了', tag: 'LocationService');
      } catch (e) {
        AppLogger.error('Firestore非同期保存エラー', error: e, tag: 'LocationService');
      }
    });
  }

  /*
  ================================================================================
                                GPS取得機能
                        GPS位置情報の取得とリトライ処理
  ================================================================================
  */

  /// 現在の位置情報を取得（リトライ付き）
  /// ネットワーク状況に応じた適応的なリトライ処理
  ///
  /// [maxRetries] 最大リトライ回数（デフォルトはAppConstantsから取得）
  /// Returns: 位置情報のPositionオブジェクト
  static Future<Position> _getCurrentPositionWithRetry({
    int maxRetries = AppConstants.maxLocationRetries,
  }) async {
    Exception? lastException;

    // ステップ1: 指定回数までリトライ
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // ステップ2: 位置情報権限の確保
        await _ensureLocationPermissions();

        AppLogger.info('位置情報取得試行 $attempt/$maxRetries', tag: 'LocationService');

        // ステップ3: 試行回数に応じたタイムアウト設定
        final timeoutSeconds = AppConstants.baseLocationTimeoutSeconds +
                              (attempt * AppConstants.locationTimeoutIncrementSeconds);

        // ステップ4: GPS位置情報の取得
        return await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: timeoutSeconds),
          ),
        );
      } catch (e) {
        lastException = e as Exception;
        AppLogger.warning('位置情報取得エラー (試行 $attempt/$maxRetries): $e',
                         tag: 'LocationService');

        // ステップ5: リトライ間隔の設定
        if (attempt < maxRetries) {
          final delaySeconds = attempt * AppConstants.retryDelayMultiplier;
          AppLogger.info('$delaySeconds秒後にリトライします', tag: 'LocationService');
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      }
    }

    throw lastException ?? LocationServiceException('位置情報取得に失敗しました');
  }

  /*
  ================================================================================
                                権限管理機能
                       位置情報権限の確認と要求処理
  ================================================================================
  */

  /// 位置情報権限の確保
  /// サービス有効性と権限の段階的な確認
  static Future<void> _ensureLocationPermissions() async {
    // ステップ1: サービス有効性チェック
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationServiceException('位置情報サービスが無効です');
    }

    // ステップ2: 権限チェックと要求
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      AppLogger.info('位置情報権限を要求中', tag: 'LocationService');
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw LocationPermissionException('位置情報の権限が拒否されました');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionException('位置情報の権限が永続的に拒否されました');
    }

    AppLogger.info('位置情報権限確認完了', tag: 'LocationService');
  }

  /*
  ================================================================================
                                イベントハンドラー
                       位置情報更新とエラー処理
  ================================================================================
  */

  /// 位置情報更新ハンドラー
  /// 継続監視中の位置情報変更を処理
  ///
  /// [position] 新しい位置情報
  static void _handleLocationUpdate(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);

    // ステップ1: 意味のある移動かチェック
    if (_shouldUpdateLocation(newLocation)) {
      // ステップ2: 位置情報をキャッシュ
      _cacheLocation(newLocation);
      AppLogger.info('位置情報更新: $newLocation', tag: 'LocationService');

      // ステップ3: コールバック実行
      onLocationChanged?.call(newLocation);
    }
  }

  /// 位置情報エラーハンドラー
  /// 監視中のエラーを適切に処理
  ///
  /// [error] 発生したエラー
  static void _handleLocationError(Object error) {
    AppLogger.error('位置監視エラー', error: error, tag: 'LocationService');
  }

  /*
  ================================================================================
                                検証・判定機能
                       データの妥当性と更新必要性の判定
  ================================================================================
  */

  /// 位置更新が必要かチェック
  /// 移動距離に基づいて意味のある更新かどうかを判定
  ///
  /// [newLocation] 新しい位置情報
  /// Returns: 更新が必要かどうか
  static bool _shouldUpdateLocation(LatLng newLocation) {
    if (_cachedLocation == null) return true;

    // ステップ1: 移動距離の計算
    final distance = calculateDistance(_cachedLocation!, newLocation);
    final shouldUpdate = distance >= AppConstants.locationUpdateDistanceFilter;

    // ステップ2: 更新スキップ時のログ出力
    if (!shouldUpdate) {
      AppLogger.debug('位置更新スキップ (移動距離: ${distance.toStringAsFixed(1)}m)',
                     tag: 'LocationService');
    }

    return shouldUpdate;
  }

  /// 位置情報をキャッシュ
  /// メモリ内での位置情報管理
  ///
  /// [location] キャッシュする位置情報
  static void _cacheLocation(LatLng location) {
    _cachedLocation = location;
    _lastLocationUpdate = DateTime.now();
    AppLogger.debug('位置情報をキャッシュ: $location', tag: 'LocationService');
  }

  /// キャッシュされた位置情報が有効かチェック
  /// 有効期限に基づくキャッシュの妥当性判定
  /// Returns: キャッシュが有効かどうか
  static bool _isLocationValid() {
    if (_cachedLocation == null || _lastLocationUpdate == null) {
      return false;
    }

    // ステップ1: 現在時刻との比較
    final now = DateTime.now();
    final isValid = now.difference(_lastLocationUpdate!) < _locationValidityDuration;

    // ステップ2: 期限切れ時のログ出力
    if (!isValid) {
      AppLogger.debug('キャッシュされた位置情報が期限切れ', tag: 'LocationService');
    }

    return isValid;
  }
}

/*
===============================================================================
                                状態管理クラス
                        LocationServiceの状態を表現
===============================================================================
*/

/// 位置情報サービスの状態を表すクラス
/// サービスの健全性と動作状況を監視するためのデータ構造
class LocationServiceStatus {
  /// 位置情報が存在するかどうか
  final bool hasLocation;

  /// 位置情報が有効かどうか
  final bool isValid;

  /// 最終更新時刻
  final DateTime? lastUpdate;

  /// 監視が実行中かどうか
  final bool isMonitoring;

  /// 現在の位置情報
  final LatLng? location;

  LocationServiceStatus({
    required this.hasLocation,
    required this.isValid,
    this.lastUpdate,
    required this.isMonitoring,
    this.location,
  });

  /// 状態をMap形式で取得（デバッグ用）
  /// ログ出力やJSON変換に使用
  Map<String, dynamic> toMap() {
    return {
      'hasLocation': hasLocation,
      'isValid': isValid,
      'lastUpdate': lastUpdate?.toIso8601String(),
      'isMonitoring': isMonitoring,
      'location': location != null
          ? {
              'latitude': location!.latitude,
              'longitude': location!.longitude,
            }
          : null,
    };
  }

  @override
  String toString() {
    return 'LocationServiceStatus(hasLocation: $hasLocation, isValid: $isValid, '
           'lastUpdate: $lastUpdate, isMonitoring: $isMonitoring, location: $location)';
  }
}

/*
===============================================================================
                                例外クラス
                        LocationService固有の例外定義
===============================================================================
*/

/// 位置情報サービス関連の例外
/// 位置情報取得時の一般的なエラーを表現
class LocationServiceException implements Exception {
  final String message;
  LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}

/// 位置情報権限関連の例外
/// 権限拒否や権限不足のエラーを表現
class LocationPermissionException implements Exception {
  final String message;
  LocationPermissionException(this.message);

  @override
  String toString() => 'LocationPermissionException: $message';
}