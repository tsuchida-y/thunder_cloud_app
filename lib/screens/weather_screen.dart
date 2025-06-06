// lib/screens/weather_screen.dart - 大幅シンプル化
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunder_cloud_app/constants/weather_constants.dart';
import 'package:thunder_cloud_app/services/notification_service.dart';
import 'package:thunder_cloud_app/services/push_notification_service.dart';

import '../services/location_service.dart';
import '../widgets/common/weather_app_bar.dart';
import '../widgets/map/background_map.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen> {
  bool _isLoading = true;
  LatLng? _currentLocation;
  String _statusMessage = "位置情報取得中...";
  StreamSubscription<Position>? _positionStream; // ← 追加

  // ❌ 削除: Timer? _weatherTimer;
  // ❌ 削除: List<String> matchingCities = [];
  // ❌ 削除: List<String> _previousMatchingCities = [];

  @override
  void initState() {
    super.initState();
    _initializeLocationAndNotification(); // ← 名前変更
    _startLocationMonitoring();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

/// 位置変更の監視開始 - 統合版
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
      setState(() {
        _statusMessage = "位置監視エラー。手動更新をご利用ください。";
      });
    },
  );
}

  /// 位置変更時の処理
  Future<void> _onLocationChanged(Position position) async {
    final newLocation = LatLng(position.latitude, position.longitude);

    // 前回位置との距離計算
    if (_currentLocation != null) {
      final distance = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        newLocation.latitude,
        newLocation.longitude,
      );

      // 設定した距離以上移動した場合のみ更新
      if (distance >= WeatherConstants.locationUpdateDistanceFilter) {
        await _updateLocationToServer(newLocation);
      }
    } else {
      // 初回は必ず更新
      await _updateLocationToServer(newLocation);
    }
  }

  /// サーバーへの位置情報更新
  Future<void> _updateLocationToServer(LatLng newLocation) async {
    try {
      await PushNotificationService.saveUserLocation(
        newLocation.latitude,
        newLocation.longitude,
      );

      setState(() {
        _currentLocation = newLocation;
        _statusMessage = "📍 位置更新: ${newLocation.latitude.toStringAsFixed(4)}, ${newLocation.longitude.toStringAsFixed(4)}\n（サーバーが新しい位置で監視中）";
      });

      print("✅ 位置情報更新: $newLocation");
    } catch (e) {
      print("❌ 位置情報更新エラー: $e");
      setState(() {
        _statusMessage = "位置情報の更新に失敗しました";
      });
    }
  }


  /// 初期化: 位置情報取得とFirestore保存のみ
  Future<void> _initializeLocationAndNotification() async {
    try {
      setState(() => _isLoading = true);

      print("🚀 初期化開始");

      // 位置情報取得
      print("📍 位置情報取得中...");
      _currentLocation = await LocationService.getCurrentLocationAsLatLng();
      print("📍 位置情報取得結果: $_currentLocation");

      if (_currentLocation != null) {
        print("💾 Firestore への位置情報保存開始...");

        // FCMトークン確認
        final fcmToken = PushNotificationService.fcmToken;
        print("🔑 現在のFCMトークン: ${fcmToken?.substring(0, 20) ?? 'null'}...");

        // ユーザー情報をFirestoreに保存（サーバー監視対象に追加）
        await PushNotificationService.saveUserLocation(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );
        print("✅ PushNotificationService.saveUserLocation 呼び出し完了");

        // 通知権限確認
        print("🔔 通知権限確認中...");
        await NotificationService.requestPermissions();
        print("✅ 通知権限確認完了");

        setState(() {
          _isLoading = false;
          _statusMessage = "🌩️ 入道雲監視システム開始\n（5分間隔でサーバーが自動監視中）";
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = "位置情報の取得に失敗しました";
        });
      }
    } catch (e) {
      print("❌ 初期化エラー: $e");
      setState(() {
        _isLoading = false;
        _statusMessage = "エラー: 位置情報の取得に失敗しました";
      });
    }
  }

  /// 手動での位置更新（オプション）
  Future<void> _updateLocation() async {
    setState(() => _isLoading = true);

    try {
      _currentLocation = await LocationService.getCurrentLocationAsLatLng();

      if (_currentLocation != null) {
        await PushNotificationService.saveUserLocation(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );

        setState(() {
          _isLoading = false;
          _statusMessage = "📍 位置情報を更新しました\n（サーバーが監視中）";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "位置情報の更新に失敗しました";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WeatherAppBar(),
      body: Stack(
        children: [
          BackgroundMapWidget(currentLocation: _currentLocation),

          // シンプルな状態表示
          Center(
            child: Card(
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      const Icon(Icons.cloud, size: 50, color: Colors.blue),

                    const SizedBox(height: 16),

                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 16),

                    if (!_isLoading)
                      ElevatedButton.icon(
                        onPressed: _updateLocation,
                        icon: const Icon(Icons.refresh),
                        label: const Text("位置を更新"),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}