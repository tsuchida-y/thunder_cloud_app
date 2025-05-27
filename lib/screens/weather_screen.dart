import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
class WeatherScreenState extends State<WeatherScreen> {
  List<String> matchingCities = [];
  bool isLoading = true;
  LatLng? _currentLocation;
  Timer? _weatherTimer;

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
          WeatherMapView(currentLocation: _currentLocation),//背景
          WeatherOverlay(matchingCities: matchingCities),//天気オーバーレイ
        ],
      ),
    );
  }
}