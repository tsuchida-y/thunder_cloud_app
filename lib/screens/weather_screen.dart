import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
class WeatherScreenState extends State<WeatherScreen>{
  List<String> matchingCities = [];
  bool isLoading = true;
  LatLng? _currentLocation;
  Timer? _weatherTimer;
  List<String> _previousMatchingCities = []; // 前回の結果を保存

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _getLocation();
    _startWeatherUpdates();
  }

  //現在地を取得する関数
  Future<void> _getLocation() async {
    try {
      final location = await LocationService.getCurrentLocationAsLatLng();
      if (mounted) {
        setState(() {
          _currentLocation = location;
        });
      }
    } catch (e) {
      print("位置情報取得エラー: $e");
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

      // 新しい入道雲が出現した場合のみ通知
      final newClouds = result
          .where((direction) => !_previousMatchingCities.contains(direction))
          .toList();

      if (newClouds.isNotEmpty) {
        print("新しい入道雲を検出: $newClouds");
        await NotificationService.showThunderCloudNotification(newClouds);
      }

      if (mounted) {
        setState(() {
          matchingCities = result;
          _previousMatchingCities = List.from(result);
          isLoading = false;
        });
      }
    } catch (e) {
      print("天気チェックエラー: $e");
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
          WeatherMapView(currentLocation: _currentLocation),
          WeatherOverlay(matchingCities: matchingCities),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [

          if (Platform.isIOS) ...[
            FloatingActionButton(
              heroTag: "ios_permission",
              onPressed: () async {
                await NotificationService.requestiOSPermissionsAgain();
                await NotificationService.checkPermissionStatus();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('iOS権限を再確認しました')),
                );
              },
              backgroundColor: Colors.purple,
              child: const Icon(Icons.settings),
            ),
            const SizedBox(height: 10),
          ],
          
          // 即座テスト通知ボタン
          FloatingActionButton(
            heroTag: "immediate_test",
            onPressed: () async {
              await NotificationService.showImmediateTestNotification();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('即座テスト通知を送信しました')),
              );
            },
            backgroundColor: Colors.orange,
            child: const Icon(Icons.notifications_active),
          ),
          const SizedBox(height: 10),
          // 入道雲テスト通知ボタン
          FloatingActionButton(
            heroTag: "thunder_test",
            onPressed: () async {
              await NotificationService.showTestNotification();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('入道雲テスト通知を送信しました')),
              );
            },
            backgroundColor: Colors.blue,
            child: const Icon(Icons.cloud),
          ),
          const SizedBox(height: 10),
          // 手動天気チェックボタン
          FloatingActionButton(
            heroTag: "manual_check",
            onPressed: () async {
              if (_currentLocation != null) {
                await _checkWeatherInDirections();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('手動で天気をチェックしました')),
                );
              }
            },
            backgroundColor: Colors.green,
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
