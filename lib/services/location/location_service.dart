// lib/services/location_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// 位置情報サービス
/// GPS位置情報の取得、監視、キャッシュ管理を行う
class LocationService {
  // ===== 静的変数 =====
  static LatLng? _cachedLocation;
  static DateTime? _lastLocationUpdate;
  static StreamSubscription<Position>? _positionStream;
  static Function(LatLng)? onLocationChanged;

  // ===== 設定値 =====
  static const Duration _locationValidityDuration = Duration(minutes: 10);

  // ===== 公開メソッド =====

  /// 高速な位置情報取得（並列処理）
  ///
  /// FirestoreとGPSの取得を並列で実行し、最初に取得できた結果を返す
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

      // キャッシュされた位置が有効で、強制更新でない場合はキャッシュを返す
      if (!forceRefresh && _isLocationValid()) {
        AppLogger.info('キャッシュされた位置情報を使用: $_cachedLocation', tag: 'LocationService');
        return _cachedLocation;
      }

      // FirestoreとGPSを並列で実行
      final results = await Future.wait([
        _getLocationFromFirestore(userId),
        _getCurrentPositionWithRetry(),
      ], eagerError: false);

      LatLng? firestoreLocation;
      LatLng? gpsLocation;

      // Firestoreの結果
      if (results[0] != null) {
        firestoreLocation = results[0] as LatLng;
        AppLogger.info('Firestoreから位置情報取得成功: $firestoreLocation', tag: 'LocationService');
      }

      // GPSの結果
      if (results[1] != null) {
        final position = results[1] as Position;
        gpsLocation = LatLng(position.latitude, position.longitude);
        AppLogger.info('GPSから位置情報取得成功: $gpsLocation', tag: 'LocationService');
      }

      // より正確なGPS位置情報を優先、なければFirestore位置情報を使用
      final selectedLocation = gpsLocation ?? firestoreLocation;

      if (selectedLocation != null) {
        _cacheLocation(selectedLocation);
        AppLogger.success('高速位置情報取得完了: $selectedLocation', tag: 'LocationService');

        // GPS位置情報が取得できた場合、Firestoreにも保存
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
  ///
  /// [forceRefresh] 強制的に新しい位置情報を取得するかどうか
  ///
  /// Returns: 現在位置のLatLng、取得失敗時はnull
  static Future<LatLng?> getCurrentLocationAsLatLng({bool forceRefresh = false}) async {
    try {
      AppLogger.info('位置情報取得開始 (forceRefresh: $forceRefresh)', tag: 'LocationService');

      // キャッシュされた位置が有効で、強制更新でない場合はキャッシュを返す
      if (!forceRefresh && _isLocationValid()) {
        AppLogger.info('キャッシュされた位置情報を使用: $_cachedLocation', tag: 'LocationService');
        return _cachedLocation;
      }

      final position = await _getCurrentPositionWithRetry();
      final newLocation = LatLng(position.latitude, position.longitude);

      _cacheLocation(newLocation);
      AppLogger.success('新しい位置情報を取得: $newLocation', tag: 'LocationService');

      return newLocation;
    } catch (e) {
      AppLogger.error('位置情報取得エラー', error: e, tag: 'LocationService');
      return _cachedLocation; // エラー時はキャッシュされた位置を返す
    }
  }

  /// 位置情報の監視を開始
  static void startLocationMonitoring() {
    if (_positionStream != null) {
      AppLogger.warning('位置監視は既に開始されています', tag: 'LocationService');
      return;
    }

    AppLogger.info('位置情報監視開始', tag: 'LocationService');

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: AppConstants.locationAccuracy,
        distanceFilter: AppConstants.locationUpdateDistanceFilter.toInt(),
      ),
    ).listen(
      _handleLocationUpdate,
      onError: _handleLocationError,
    );
  }

  /// 位置情報監視を停止
  static void stopLocationMonitoring() {
    _positionStream?.cancel();
    _positionStream = null;
    AppLogger.info('位置情報監視停止', tag: 'LocationService');
  }

  /// 2つの位置間の距離を計算（メートル単位）
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

  /// 画面遷移用の高速位置情報取得
  ///
  /// 画面遷移時に使用する軽量版。キャッシュを優先し、
  /// 必要時のみバックグラウンドで更新
  static LatLng? getLocationForScreenTransition() {
    AppLogger.info('画面遷移用位置情報取得', tag: 'LocationService');

    // キャッシュが存在する場合は即座に返す
    if (_cachedLocation != null) {
      AppLogger.info('キャッシュされた位置情報を即座に返却: $_cachedLocation', tag: 'LocationService');

      // バックグラウンドで位置情報を更新（UIをブロックしない）
      _updateLocationInBackground();

      return _cachedLocation;
    }

    AppLogger.warning('キャッシュされた位置情報がありません', tag: 'LocationService');
    return null;
  }

  /// バックグラウンドで位置情報を更新
  static void _updateLocationInBackground() {
    // 前回更新から5分以上経過している場合のみ更新
    if (_lastLocationUpdate != null) {
      final timeSinceUpdate = DateTime.now().difference(_lastLocationUpdate!);
      if (timeSinceUpdate < const Duration(minutes: 5)) {
        AppLogger.debug('位置情報は最新のためバックグラウンド更新をスキップ', tag: 'LocationService');
        return;
      }
    }

    Future.microtask(() async {
      try {
        AppLogger.info('バックグラウンドで位置情報を更新中', tag: 'LocationService');
        final newLocation = await getLocationFast(forceRefresh: true);

        if (newLocation != null) {
          AppLogger.success('バックグラウンド位置情報更新完了: $newLocation', tag: 'LocationService');

          // 位置変更コールバックがあれば実行
          onLocationChanged?.call(newLocation);
        }
      } catch (e) {
        AppLogger.error('バックグラウンド位置情報更新エラー', error: e, tag: 'LocationService');
      }
    });
  }

  /// 位置情報サービスの状態を取得
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
  static void dispose() {
    stopLocationMonitoring();
    _cachedLocation = null;
    _lastLocationUpdate = null;
    onLocationChanged = null;
    AppLogger.info('LocationService リソースクリーンアップ完了', tag: 'LocationService');
  }

  // ===== プライベートメソッド =====

  /// Firestoreから位置情報を取得
  static Future<LatLng?> _getLocationFromFirestore(String? userId) async {
    try {
      AppLogger.info('Firestoreから位置情報取得開始', tag: 'LocationService');

      final actualUserId = userId ?? await AppConstants.getCurrentUserId();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(actualUserId)
          .get()
          .timeout(const Duration(seconds: 5)); // 短いタイムアウト

      if (userDoc.exists) {
        final userData = userDoc.data();

        if (userData != null &&
            userData.containsKey('latitude') &&
            userData.containsKey('longitude')) {

          final latitude = userData['latitude']?.toDouble();
          final longitude = userData['longitude']?.toDouble();

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
  static void _saveLocationToFirestoreAsync(LatLng location, String? userId) {
    // 非同期で実行し、エラーが発生してもメイン処理をブロックしない
    Future.microtask(() async {
      try {
        final actualUserId = userId ?? await AppConstants.getCurrentUserId();

        // 緯度・経度を小数点第2位までに丸めて保存
        final roundedLatitude = double.parse(location.latitude.toStringAsFixed(2));
        final roundedLongitude = double.parse(location.longitude.toStringAsFixed(2));

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

  /// 現在の位置情報を取得（リトライ付き）
  static Future<Position> _getCurrentPositionWithRetry({
    int maxRetries = AppConstants.maxLocationRetries,
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _ensureLocationPermissions();

        AppLogger.info('位置情報取得試行 $attempt/$maxRetries', tag: 'LocationService');

        final timeoutSeconds = AppConstants.baseLocationTimeoutSeconds +
                              (attempt * AppConstants.locationTimeoutIncrementSeconds);

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

        if (attempt < maxRetries) {
          final delaySeconds = attempt * AppConstants.retryDelayMultiplier;
          AppLogger.info('$delaySeconds秒後にリトライします', tag: 'LocationService');
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      }
    }

    throw lastException ?? LocationServiceException('位置情報取得に失敗しました');
  }

  /// 位置情報権限の確保
  static Future<void> _ensureLocationPermissions() async {
    // サービス有効性チェック
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationServiceException('位置情報サービスが無効です');
    }

    // 権限チェックと要求
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

  /// 位置情報更新ハンドラー
  static void _handleLocationUpdate(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);

    // 意味のある移動かチェック
    if (_shouldUpdateLocation(newLocation)) {
      _cacheLocation(newLocation);
      AppLogger.info('位置情報更新: $newLocation', tag: 'LocationService');

      // コールバック実行
      onLocationChanged?.call(newLocation);
    }
  }

  /// 位置情報エラーハンドラー
  static void _handleLocationError(Object error) {
    AppLogger.error('位置監視エラー', error: error, tag: 'LocationService');
  }

  /// 位置更新が必要かチェック
  static bool _shouldUpdateLocation(LatLng newLocation) {
    if (_cachedLocation == null) return true;

    final distance = calculateDistance(_cachedLocation!, newLocation);
    final shouldUpdate = distance >= AppConstants.locationUpdateDistanceFilter;

    if (!shouldUpdate) {
      AppLogger.debug('位置更新スキップ (移動距離: ${distance.toStringAsFixed(1)}m)',
                     tag: 'LocationService');
    }

    return shouldUpdate;
  }

  /// 位置情報をキャッシュ
  static void _cacheLocation(LatLng location) {
    _cachedLocation = location;
    _lastLocationUpdate = DateTime.now();
    AppLogger.debug('位置情報をキャッシュ: $location', tag: 'LocationService');
  }

  /// キャッシュされた位置情報が有効かチェック
  static bool _isLocationValid() {
    if (_cachedLocation == null || _lastLocationUpdate == null) {
      return false;
    }

    final now = DateTime.now();
    final isValid = now.difference(_lastLocationUpdate!) < _locationValidityDuration;

    if (!isValid) {
      AppLogger.debug('キャッシュされた位置情報が期限切れ', tag: 'LocationService');
    }

    return isValid;
  }
}

/// 位置情報サービスの状態を表すクラス
class LocationServiceStatus {
  final bool hasLocation;
  final bool isValid;
  final DateTime? lastUpdate;
  final bool isMonitoring;
  final LatLng? location;

  LocationServiceStatus({
    required this.hasLocation,
    required this.isValid,
    this.lastUpdate,
    required this.isMonitoring,
    this.location,
  });

  /// 状態をMap形式で取得（デバッグ用）
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

/// 位置情報サービス関連の例外
class LocationServiceException implements Exception {
  final String message;
  LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}

/// 位置情報権限関連の例外
class LocationPermissionException implements Exception {
  final String message;
  LocationPermissionException(this.message);

  @override
  String toString() => 'LocationPermissionException: $message';
}