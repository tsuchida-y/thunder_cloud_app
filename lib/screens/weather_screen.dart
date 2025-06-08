// lib/screens/weather_screen.dart - リファクタリング版
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

class WeatherScreenState extends State<WeatherScreen> with WidgetsBindingObserver {
  LatLng? _currentLocation;
  final List<String> _matchingCities = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupResources();
    super.dispose();
  }

  /// アプリのライフサイクル変更時の処理
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      default:
        break;
    }
  }

  /// スクリーンの初期化
  Future<void> _initializeScreen() async {
    try {
      print("🚀 WeatherScreen初期化開始");

      // 並列で初期化処理を実行
      final futures = [
        _initializeLocation(),
        _initializeNotifications(),
      ];

      await Future.wait(futures);

      // コールバック設定
      _setupCallbacks();

      print("✅ WeatherScreen初期化完了");

    } catch (e) {
      print("❌ WeatherScreen初期化エラー: $e");
    }
  }

  /// 位置情報の初期化
  Future<void> _initializeLocation() async {
    try {
      _currentLocation = await LocationService.getCurrentLocationAsLatLng();

      if (_currentLocation != null) {
        print("📍 初期位置情報取得成功: $_currentLocation");

        // 位置情報監視開始
        LocationService.startLocationMonitoring();

        // 位置情報保存（非同期）
        _saveLocationAsync();

        setState(() {});
      }
    } catch (e) {
      print("❌ 位置情報初期化エラー: $e");
    }
  }

  /// 通知の初期化
  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.requestPermissions();
      print("✅ 通知権限確認完了");
    } catch (e) {
      print("❌ 通知初期化エラー: $e");
    }
  }

  /// コールバックの設定
  void _setupCallbacks() {
    // 入道雲検出コールバック
    PushNotificationService.onThunderCloudDetected = _handleThunderCloudDetection;

    // 位置情報更新コールバック
    LocationService.onLocationChanged = _handleLocationUpdate;
  }

  /// 位置情報の非同期保存
  void _saveLocationAsync() async {
    if (_currentLocation == null) return;

    try {
      await PushNotificationService.saveUserLocation(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );
      print("✅ 位置情報保存完了");
    } catch (e) {
      print("❌ 位置情報保存エラー: $e");
    }
  }

  /// 入道雲検出時の処理
  void _handleThunderCloudDetection(List<String> directions) {
    print("🌩️ 入道雲検出: $directions");

    setState(() {
      for (String direction in directions) {
        if (!_matchingCities.contains(direction)) {
          _matchingCities.add(direction);
        }
      }
    });

    // ローカル通知を表示
    NotificationService.showThunderCloudNotification(directions);
  }

  /// 位置情報更新時の処理
  void _handleLocationUpdate(LatLng newLocation) {
    print("📍 位置情報更新: $newLocation");

    setState(() {
      _currentLocation = newLocation;
    });

    // 位置情報保存（非同期）
    _saveLocationAsync();
  }

  /// アプリが前面に戻った時の処理
  void _handleAppResumed() {
    print("📱 アプリがアクティブになりました");
    PushNotificationService.updateUserActiveStatus(true);
  }

  /// アプリがバックグラウンドに移った時の処理
  void _handleAppPaused() {
    print("📱 アプリがバックグラウンドに移りました");
    PushNotificationService.updateUserActiveStatus(false);
  }

  /// 気象データのデバッグ実行
  Future<void> _debugWeatherData() async {
    if (_currentLocation == null) {
      print("❌ 位置情報が取得できていません");
      return;
    }

    try {
      await WeatherDebugService.debugWeatherData(_currentLocation!);
    } catch (e) {
      print("❌ 気象データデバッグエラー: $e");
    }
  }

  /// リソースのクリーンアップ
  void _cleanupResources() {
    // コールバック解除
    PushNotificationService.onThunderCloudDetected = null;
    LocationService.onLocationChanged = null;

    // サービスのクリーンアップ
    LocationService.dispose();
    PushNotificationService.dispose();

    print("🧹 WeatherScreen リソースクリーンアップ完了");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WeatherAppBar(),
      body: Stack(
        children: [
          // 背景地図
          BackgroundMapWidget(currentLocation: _currentLocation),

          // 入道雲方向表示オーバーレイ
          CloudStatusOverlay(matchingCities: _matchingCities),

          // デバッグ用気象データ表示ボタン
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _debugWeatherData,
              icon: const Icon(Icons.analytics),
              label: const Text("気象データ"),
              backgroundColor: Colors.blue.withOpacity(0.9),
            ),
          ),

          // サービス状態表示（デバッグ用）
          if (const bool.fromEnvironment('SHOW_DEBUG_INFO', defaultValue: false))
            _buildDebugInfoOverlay(),
        ],
      ),
    );
  }

  /// デバッグ情報オーバーレイ
  Widget _buildDebugInfoOverlay() {
    return Positioned(
      top: 120,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Debug Info",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Location: ${_currentLocation?.toString() ?? 'Unknown'}",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              "Cities: ${_matchingCities.join(', ')}",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}