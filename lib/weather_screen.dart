import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../geolocator.dart';
import '../weather_api.dart';
import '../cloud_avatar.dart';
import '../direction_image.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherApi weatherApi = WeatherApi(); // WeatherApiクラスのインスタンスを生成
  final List<String> cityNames = ["Miyako", "Senboku", "Hanamaki", "Ninohe"];
  List<String> matchingCities = [];
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
        fetchWeatherForCities();
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

  Future<void> fetchWeatherForCities() async {
    List<String> tempMatchingCities = [];
    try {
      for (String cityName in cityNames) {
        final weatherData = await weatherApi.fetchWeather(cityName);
        if (weatherData["humidity"] >= 10 &&
            weatherData["weather"] == "Clouds" &&
            weatherData["detailed_weather"] == "broken clouds" &&
            weatherData["clouds"] >= 10 &&
            weatherData["atmospheric_pressure"] >= 1000) {
          tempMatchingCities.add(cityName);
          log(cityName);
        }
      }
      setState(() {
        matchingCities = tempMatchingCities;
        isLoading = false;
      });
    } catch (e) {
      log("Error: $e");
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
          CloudAvatar(name: "Ninohe", top: 100.0, left: 150.0),
          CloudAvatar(name: "Hanamaki", top: 500.0, left: 150.0),
          CloudAvatar(name: "Miyako", top: 300.0, left: 280.0),
          CloudAvatar(name: "Senboku", top: 300.0, left: 10.0),
        ],
      ),
    );
  }
}