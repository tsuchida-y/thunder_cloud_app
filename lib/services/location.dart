// lib/services/location_service.dart
import 'dart:async';
import 'dart:developer' as dev;

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/weather.dart';

/// 位置情報の取得と管理を行う統合サービス
class LocationService {
  static LatLng? _cachedLocation;
  static DateTime? _lastLocationUpdate;
  static StreamSubscription<Position>? _positionStream;

  /// 位置情報の有効期限（10分）
  static const Duration _locationValidityDuration = Duration(minutes: 10);

  /// 位置情報更新のコールバック
  static Function(LatLng)? onLocationChanged;

  /// 現在の位置情報を取得（キャッシュ機能付き）
  static Future<LatLng?> getCurrentLocationAsLatLng({bool forceRefresh = false}) async {
    // 有効なキャッシュがある場合はそれを返す
    if (!forceRefresh && _isLocationValid()) {
      dev.log("✅ キャッシュされた位置情報を使用: $_cachedLocation");
      return _cachedLocation;
    }

    try {
      dev.log("📍 位置情報を新規取得中...");
      final position = await _getCurrentPositionWithRetry();
      final location = LatLng(position.latitude, position.longitude);

      _cacheLocation(location);
      dev.log("✅ 位置情報取得成功: $location");

      return location;

    } catch (e) {
      dev.log("❌ 位置情報取得エラー: $e");
      return _cachedLocation; // キャッシュがあればそれを返す
    }
  }

  /// 位置情報の継続監視を開始
  static void startLocationMonitoring() {
    if (_positionStream != null) {
      dev.log("⚠️ 位置監視は既に開始されています");
      return;
    }

    dev.log("🔄 位置情報監視開始");

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: WeatherConstants.locationAccuracy,
        distanceFilter: WeatherConstants.locationUpdateDistanceFilter.toInt(),
        timeLimit: const Duration(minutes: 10),
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
    dev.log("⏹️ 位置情報監視停止");
  }

  /// 現在の位置情報を取得（リトライ付き）
  static Future<Position> _getCurrentPositionWithRetry({int maxRetries = 3}) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _ensureLocationPermissions();

        dev.log("📍 位置情報取得試行 $attempt/$maxRetries");

        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20 + (attempt * 10)),
        );

      } catch (e) {
        lastException = e as Exception;
        dev.log("❌ 位置情報取得エラー (試行 $attempt/$maxRetries): $e");

        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }

    throw lastException ?? Exception('位置情報取得に失敗しました');
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
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationPermissionException('位置情報の権限が拒否されました');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionException('位置情報の権限が永続的に拒否されました');
    }
  }

  /// 位置情報更新ハンドラー
  static void _handleLocationUpdate(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);

    // 意味のある移動かチェック
    if (_shouldUpdateLocation(newLocation)) {
      _cacheLocation(newLocation);
      dev.log("📍 位置情報更新: $newLocation");

      // コールバック実行
      onLocationChanged?.call(newLocation);
    }
  }

  /// 位置情報エラーハンドラー
  static void _handleLocationError(Object error) {
    dev.log("❌ 位置監視エラー: $error");
  }

  /// 位置更新が必要かチェック
  static bool _shouldUpdateLocation(LatLng newLocation) {
    if (_cachedLocation == null) return true;

    final distance = calculateDistance(_cachedLocation!, newLocation);
    return distance >= WeatherConstants.locationUpdateDistanceFilter;
  }

  /// 位置情報をキャッシュ
  static void _cacheLocation(LatLng location) {
    _cachedLocation = location;
    _lastLocationUpdate = DateTime.now();
  }

  /// キャッシュされた位置情報が有効かチェック
  static bool _isLocationValid() {
    if (_cachedLocation == null || _lastLocationUpdate == null) return false;

    final now = DateTime.now();
    return now.difference(_lastLocationUpdate!) < _locationValidityDuration;
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

  /// 位置情報サービスの状態
  static Map<String, dynamic> getLocationStatus() {
    return {
      'hasLocation': _cachedLocation != null,
      'isValid': _isLocationValid(),
      'lastUpdate': _lastLocationUpdate?.toIso8601String(),
      'isMonitoring': _positionStream != null,
      'location': _cachedLocation != null
        ? {
            'latitude': _cachedLocation!.latitude,
            'longitude': _cachedLocation!.longitude,
          }
        : null,
    };
  }

  /// リソースのクリーンアップ
  static void dispose() {
    stopLocationMonitoring();
    _cachedLocation = null;
    _lastLocationUpdate = null;
    onLocationChanged = null;
    dev.log("🧹 LocationService リソースクリーンアップ完了");
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