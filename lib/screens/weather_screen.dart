// lib/screens/weather_screen.dart - クリーンアップ版
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

  /// 位置情報と通知の初期化
  Future<void> _initializeLocationAndNotification() async {
    try {
      _currentLocation = await LocationService.getCurrentLocationAsLatLng();
      print("📍 位置情報取得結果: $_currentLocation");

      if (_currentLocation != null) {
        print("Firestore への位置情報保存開始...");

        // FCMトークンが取得されるまで待機
        await _waitForFCMToken();

        final fcmToken = PushNotificationService.fcmToken;
        print("現在のFCMトークン: ${fcmToken?.substring(0, 20) ?? 'null'}...");

        if (fcmToken != null) {
          await PushNotificationService.saveUserLocation(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
          );
          print("PushNotificationService.saveUserLocation 呼び出し完了");
        } else {
          print("⚠️ FCMトークンが取得できないため、位置情報保存をスキップします");
        }

        print("通知権限確認中...");
        await NotificationService.requestPermissions();
        print("通知権限確認完了");

        setState(() {});
      } else {
        setState(() {});
      }
    } catch (e) {
      print("❌ 初期化エラー: $e");
      setState(() {});
    }
  }

  /// FCMトークンが取得されるまで待機
  Future<void> _waitForFCMToken({int maxWaitSeconds = 10}) async {
    for (int i = 0; i < maxWaitSeconds; i++) {
      if (PushNotificationService.fcmToken != null) {
        print("✅ FCMトークン取得確認完了");
        return;
      }
      print("⏳ FCMトークン取得待機中... (${i + 1}秒)");
      await Future.delayed(const Duration(seconds: 1));
    }
    print("⚠️ FCMトークン取得がタイムアウトしました");
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