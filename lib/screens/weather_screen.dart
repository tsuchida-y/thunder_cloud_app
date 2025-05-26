import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunder_cloud_app/constants/avatar_positions.dart';
import 'package:thunder_cloud_app/services/weather/weather_logic.dart';
import '../services/geolocator.dart';
import '../widgets/cloud_avatar.dart';
import '../widgets/direction_image.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen> {
  List<String> matchingCities = []; // 条件に一致する方向を格納
  bool isLoading = true;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _getLocation();
    Timer.periodic(
      const Duration(seconds: 5),
      (Timer timer) {
        if (_currentLocation != null) {
          _checkWeatherInDirections(
              _currentLocation!.latitude, _currentLocation!.longitude);
        }
      },
    );
  }

  //現在地を取得するに格納する関数
  Future<void> _getLocation() async {
    final locationData = await getCurrentLocation();
    setState(() {
      _currentLocation = LatLng(locationData.latitude, locationData.longitude);
    });
  }

  Future<void> _checkWeatherInDirections(
      double currentLatitude, double currentLongitude) async {
    final result =
        await fetchWeatherInDirections(currentLatitude, currentLongitude);
    setState(() {
      matchingCities = result;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("入道雲サーチ画面"),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 196, 248, 199),
        elevation: 3,
        shadowColor: Colors.black54,
        
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          if (_currentLocation != null)
            GoogleMap(
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
          ...avatarPositions.entries.map((entry) {
            final direction = entry.key;
            final position = entry.value;
            return CloudAvatar(
              name: direction,
              top: position.dy,
              left: position.dx,
              isCloudy: matchingCities.contains(direction),
            );
          })
        ],
      ),
    );
  }
}
