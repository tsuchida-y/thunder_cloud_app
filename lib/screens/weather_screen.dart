import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunder_cloud_app/services/background_service.dart';
import 'package:thunder_cloud_app/services/notification_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../widgets/weather_app_bar.dart';
import '../widgets/weather_map_view.dart';
import '../widgets/weather_overlay.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

///入道雲サーチアプリのメイン画面を管理するStateクラス
class WeatherScreenState extends State<WeatherScreen>
    with WidgetsBindingObserver {
  List<String> matchingCities = [];
  bool isLoading = true;
  LatLng? _currentLocation;
  Timer? _weatherTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// アプリのライフサイクル変更時の処理
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // アプリがバックグラウンドに移行またはクローズ
        _startBackgroundMonitoring();
        break;
      case AppLifecycleState.resumed:
        // アプリがフォアグラウンドに復帰
        _stopBackgroundMonitoring();
        break;
      default:
        break;
    }
  }

  /// バックグラウンド監視の開始
  Future<void> _startBackgroundMonitoring() async {
    await BackgroundService.startPeriodicCheck();
  }

  /// バックグラウンド監視の停止
  Future<void> _stopBackgroundMonitoring() async {
    await BackgroundService.stopPeriodicCheck();
  }

  Future<void> _initializeApp() async {
    await _getLocation();
    _startWeatherUpdates();

    // 初回バックグラウンド監視開始
    await _startBackgroundMonitoring();
  }

  //現在地を取得する関数
  Future<void> _getLocation() async {
    final location = await LocationService.getCurrentLocationAsLatLng();
    if (mounted) {
      setState(() {
        _currentLocation = location;
      });
    }
  }

  //天気情報を定期的(5秒)に取得する関数
  void _startWeatherUpdates() {
    _weatherTimer = Timer.periodic(
      const Duration(seconds: 5),
      (Timer timer) {
        if (_currentLocation != null) {
          _checkWeatherInDirections();
        }
      },
    );
  }

  //各方向の天気をチェックして、入道雲がある方向を特定する関数
  Future<void> _checkWeatherInDirections() async {
    if (_currentLocation == null) return;

    try {
      final result = await WeatherService.getThunderCloudDirections(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      if (mounted) {
        setState(() {
          matchingCities = result;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WeatherAppBar(),
      body: Stack(
        children: [
          WeatherMapView(currentLocation: _currentLocation), //背景
          WeatherOverlay(matchingCities: matchingCities), //天気オーバーレイ

          // デバッグ用のテスト機能をWeatherScreenに追加
          FloatingActionButton(
            onPressed: () async {
              await NotificationService.showTestNotification();
            },
            child: const Icon(Icons.notifications),
          )
        ],
      ),
    );
  }
}
