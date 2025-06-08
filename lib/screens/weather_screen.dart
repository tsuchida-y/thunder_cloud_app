// lib/screens/weather_screen.dart - 高速起動版
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunder_cloud_app/constants/weather_constants.dart';
import 'package:thunder_cloud_app/services/notification_service.dart';
import 'package:thunder_cloud_app/services/push_notification_service.dart';
import 'package:thunder_cloud_app/services/weather_debug_service.dart';
import 'package:thunder_cloud_app/widgets/cloud/cloud_status_overlay.dart';

import '../services/location_service.dart';
import '../widgets/common/weather_app_bar.dart';
import '../widgets/map/background_map.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen> {
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;

  // UI表示用の入道雲検出結果
  List<String> matchingCities = [];

  @override
  void initState() {
    super.initState();
    _initializeLocationAndNotification();
    _startLocationMonitoring();

    // 入道雲検出のコールバックを登録
    PushNotificationService.onThunderCloudDetected = _onThunderCloudDetected;
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    // コールバックを解除
    PushNotificationService.onThunderCloudDetected = null;
    super.dispose();
  }

  /// 入道雲検出時のコールバック処理
  void _onThunderCloudDetected(List<String> directions) {
    print("🌩️ 入道雲検出コールバック受信: $directions");

    for (String direction in directions) {
      _handleThunderCloudDetection(direction);
    }
  }

  /// 入道雲検出処理
  void _handleThunderCloudDetection(String direction) {
    print("🌩️ 入道雲検出処理開始: $direction");
    _updateMatchingCities(direction);
    NotificationService.showThunderCloudNotification([direction]);
    print("🌩️ 現在のmatchingCities: $matchingCities");
  }

  /// matchingCitiesリストを更新
  void _updateMatchingCities(String direction) {
    setState(() {
      if (!matchingCities.contains(direction)) {
        matchingCities.add(direction);
      }
    });
  }

  /// デバッグ用: 気象データ分析を実行
  Future<void> _debugWeatherData() async {
    if (_currentLocation == null) {
      print("❌ 位置情報が取得できていません");
      return;
    }

    await WeatherDebugService.debugWeatherData(_currentLocation!);
  }

  /// 位置変更の監視開始
  void _startLocationMonitoring() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: WeatherConstants.locationAccuracy,
        distanceFilter: WeatherConstants.locationUpdateDistanceFilter.toInt(),
        timeLimit: const Duration(minutes: 10),
      ),
    ).listen(
      (Position position) {
        _onLocationChanged(position);
      },
      onError: (error) {
        print("❌ 位置監視エラー: $error");
        setState(() {});
      },
    );
  }

  /// 位置変更時の処理
  void _onLocationChanged(Position position) async {
    final newLocation = LatLng(position.latitude, position.longitude);

    print("✅ 位置情報更新: $newLocation");

    if (_currentLocation == null ||
        _shouldUpdateLocation(_currentLocation!, newLocation)) {
      setState(() {
        _currentLocation = newLocation;
      });

      // Firestoreの位置情報を更新
      await PushNotificationService.saveUserLocation(
        position.latitude,
        position.longitude,
      );
    }
  }

  /// 位置更新が必要かチェック
  bool _shouldUpdateLocation(LatLng current, LatLng newLocation) {
    final distance = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      newLocation.latitude,
      newLocation.longitude,
    );
    return distance >= WeatherConstants.locationUpdateDistanceFilter;
  }

  /// 位置情報と通知の初期化（非同期・並列処理）
  Future<void> _initializeLocationAndNotification() async {
    try {
      // 並列で初期化処理を実行
      final futures = [
        _initializeLocation(),
        _initializeNotification(),
      ];

      await Future.wait(futures);
      print("✅ 全ての初期化処理完了");

    } catch (e) {
      print("❌ 初期化エラー: $e");
      setState(() {});
    }
  }

  /// 位置情報の初期化
  Future<void> _initializeLocation() async {
    try {
      _currentLocation = await LocationService.getCurrentLocationAsLatLng();
      print("📍 位置情報取得結果: $_currentLocation");

      if (_currentLocation != null) {
        setState(() {});

        // 位置情報保存は非同期で実行（UI表示をブロックしない）
        _saveLocationAsync();
      }
    } catch (e) {
      print("❌ 位置情報初期化エラー: $e");
    }
  }

  /// 通知の初期化
  Future<void> _initializeNotification() async {
    try {
      print("🔔 通知権限確認中...");
      await NotificationService.requestPermissions();
      print("✅ 通知権限確認完了");
    } catch (e) {
      print("❌ 通知初期化エラー: $e");
    }
  }

  /// 位置情報の非同期保存
  void _saveLocationAsync() async {
    if (_currentLocation == null) return;

    try {
      print("📍 位置情報保存を非同期で開始...");

      // FCMトークンを短時間待機（UI表示をブロックしない）
      final fcmToken = await _getFCMTokenQuickly();

      if (fcmToken != null) {
        await PushNotificationService.saveUserLocation(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );
        print("✅ 位置情報保存完了");
      } else {
        print("⚠️ FCMトークン未取得のため、位置情報保存を後で再試行");
        // 5秒後に再試行
        Timer(const Duration(seconds: 5), () => _saveLocationAsync());
      }
    } catch (e) {
      print("❌ 位置情報保存エラー: $e");
    }
  }

  /// FCMトークンを短時間で取得
  Future<String?> _getFCMTokenQuickly() async {
    // 既に取得済みの場合は即座に返す
    if (PushNotificationService.fcmToken != null) {
      return PushNotificationService.fcmToken;
    }

    // 最大2秒だけ待機
    for (int i = 0; i < 2; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (PushNotificationService.fcmToken != null) {
        print("✅ FCMトークン取得確認完了 (${i + 1}秒後)");
        return PushNotificationService.fcmToken;
      }
    }

    print("⏳ FCMトークン取得は継続中（位置情報保存を後で再試行）");
    return null;
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WeatherAppBar(),
      body: Stack(
        children: [
          BackgroundMapWidget(currentLocation: _currentLocation),

          // 入道雲方向表示オーバーレイ
          CloudStatusOverlay(matchingCities: matchingCities),

          // デバッグ用気象データ表示ボタン
          Positioned(
            bottom: 100,
            right: 20,
            child: FloatingActionButton(
              onPressed: _debugWeatherData,
              backgroundColor: Colors.orange,
              child: const Icon(Icons.cloud_circle, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}