// lib/services/location_service.dart
import 'dart:async';

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