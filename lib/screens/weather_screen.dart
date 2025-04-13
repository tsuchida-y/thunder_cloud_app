import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/geolocator.dart';
import '../services/weather_api.dart';
import '../widgets/cloud_avatar.dart';
import '../widgets/direction_image.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherApi weatherApi = WeatherApi(); // WeatherApiクラスのインスタンスを生成
  //final List<String> cityNames = ["Miyako", "Senboku", "Hanamaki", "Ninohe"];
  List<String> matchingCities = [];// 条件に一致する方向を格納するリスト (例: "north", "south")
  bool isLoading = true;
  LatLng? _currentLocation;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _getLocation();
    Timer.periodic(
      const Duration(seconds: 5),
      (Timer timer) {
        if (_currentLocation != null) {
          _checkWeatherInDirections(_currentLocation!.latitude, _currentLocation!.longitude);
        }
      },
    );
  }

  Future<void> _getLocation() async {
    final locationData = await getCurrentLocation();
    if (locationData != null) {
      setState(() {
        _currentLocation = LatLng(locationData.latitude, locationData.longitude);
      });
    }
  }

  Future<void> _checkWeatherInDirections(double currentLatitude, double currentLongitude) async {
    List<String> tempMatchingCities = [];
    bool isCloudyConditionMet(Map<String, dynamic> weatherData) {
      return 
        (weatherData["weather"] == "Thunderstorm" ||
          (weatherData["weather"] == "Clouds" &&
            (weatherData["detailed_weather"].contains("thunderstorm") ||
              weatherData["detailed_weather"].contains("heavy rain") ||
              weatherData["detailed_weather"].contains("squalls") ||
              weatherData["detailed_weather"].contains("hail")
            ) 
          ) ||
        //(weatherData.containsKey("rain") && weatherData["rain"] > 1.0) || // 例：1mm以上の雨
        //(weatherData.containsKey("snow") && weatherData["snow"] > 0.5)|| // 例：0.5mm以上の雪
        (weatherData["temperature"] > 25.0) // 例：気温が25度以上
      ); 
    }
    try {
    // 北方向の天候チェック
    final northWeather = await weatherApi.fetchNorthWeather(currentLatitude, currentLongitude);
    if (isCloudyConditionMet(northWeather)) {
      tempMatchingCities.add("north");
      log("北に入道雲の可能性");
    }

    // 南方向の天候チェック
    final southWeather = await weatherApi.fetchSouthWeather(currentLatitude, currentLongitude);
    if (isCloudyConditionMet(southWeather)) {
      tempMatchingCities.add("south");
      log("南に入道雲の可能性");
    }

    // 東方向の天候チェック
    final eastWeather = await weatherApi.fetchEastWeather(currentLatitude, currentLongitude);
    if (isCloudyConditionMet(eastWeather)) {
      tempMatchingCities.add("east");
      log("東に入道雲の可能性");
    }

    // 西方向の天候チェック
    final westWeather = await weatherApi.fetchWestWeather(currentLatitude, currentLongitude);
    if (isCloudyConditionMet(westWeather)) {
      tempMatchingCities.add("west");
      log("西に入道雲の可能性");
    }

      setState(() {
        matchingCities = tempMatchingCities;
        isLoading = false;
      });
    } catch (e) {
      log("Error checking weather in directions: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("入道雲サーチ画面"),
        backgroundColor: const Color.fromARGB(255, 196, 248, 199),
      ),
      body: Stack(
        children: <Widget>[
          if (_currentLocation != null)
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _currentLocation!,
                zoom: 12.0,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              scrollGesturesEnabled: false,
              zoomControlsEnabled: false,
              zoomGesturesEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
            ),
          const DirectionImage(),
          CloudAvatar(name: "north", top: 100.0, left: 150.0, isCloudy: matchingCities.contains("north")),
          CloudAvatar(name: "south", top: 500.0, left: 150.0, isCloudy: matchingCities.contains("south")),
          CloudAvatar(name: "east", top: 300.0, left: 280.0, isCloudy: matchingCities.contains("east")),
          CloudAvatar(name: "west", top: 300.0, left: 10.0, isCloudy: matchingCities.contains("west")),
        ],
      ),
    );
  }
}