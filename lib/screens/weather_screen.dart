import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunder_cloud_app/constants/weather_constants.dart';
import 'package:thunder_cloud_app/services/notification_service.dart';
import 'package:thunder_cloud_app/services/weather/weather_logic.dart';
import '../services/location_service.dart';
import '../widgets/weather_app_bar.dart';
import '../widgets/back_ground_map.dart';
import '../widgets/cloud_status_overlay.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

///入道雲サーチアプリのメイン画面を管理するStateクラス
class WeatherScreenState extends State<WeatherScreen> {
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


  ///ウィジェットが破棄されるときに呼び出される
  ///タイマーをキャンセルして、リソースを解放する
  @override
  void dispose() {
    _weatherTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _getLocation();

    // ✅ 修正: 位置情報取得後、即座に天気チェックを実行
    if (_currentLocation != null) {
      await _checkWeatherInDirections();
    }

    _startWeatherUpdates();
  }



  //現在地を取得する関数
  Future<void> _getLocation() async {
    try {
      final location = await LocationService.getCurrentLocationAsLatLng();

      //ウィジェットの生存確認
      if (mounted) {
        setState(() {
          _currentLocation = location;
        });
      }
    } catch (e) {
      print("位置情報取得エラー: $e");
    }
  }



  //天気情報を定期的に取得する関数
  void _startWeatherUpdates() {
    _weatherTimer = Timer.periodic(
      const Duration(seconds: WeatherConstants.weatherCheckInterval),
      (Timer timer) {
        if (_currentLocation != null) {
          _checkWeatherInDirections();
        }
      },
    );
  }



  //各方向の入道雲を検出し、新しい積乱雲が発見された場合に通知を送信する関数
  Future<void> _checkWeatherInDirections() async {
    if (_currentLocation == null) return;

    try {
      //入道雲判定ロジック
      final result = await fetchAdvancedWeatherInDirections(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      // 新しい入道雲が出現した入道雲だけを格納
      final newClouds = result
          .where((direction) => !_previousMatchingCities.contains(direction))
          .toList();

      // 新しい入道雲が検出された場合に通知を送信
      if (newClouds.isNotEmpty) {
        print("新しい入道雲を検出: $newClouds");
        await NotificationService.showThunderCloudNotification(newClouds);
      }

      //ウィジェットの生存確認
      if (mounted) {
        setState(() {
          matchingCities = result;
          _previousMatchingCities = List.from(result);
          isLoading = false;
        });
      }
    } catch (e) {
      print("Open-Meteo分析エラー: $e");
      // フォールバック処理を削除、エラー時は空の結果を設定
      if (mounted) {
        setState(() {
          matchingCities = [];
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
          BackgroundMapWidget(currentLocation: _currentLocation),
          CloudStatusOverlay(matchingCities: matchingCities),
        ],
      ),
    );
  }
}
