import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:thunder_cloud_app/geolocator.dart';
import 'weather_api.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: WeatherScreen(), // ホーム画面として設定
    );
  }
}



class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}



class _WeatherScreenState extends State<WeatherScreen> {
  
  final WeatherApi weatherApi = WeatherApi(); // WeatherApiクラスのインスタンスを生成

  final List<String> cityNames = ["Miyako", "Senboku", "Hanamaki", "Ninohe"]; // 取得したい都市名のリスト
  //List<Map<String, dynamic>> weatherDataList = []; // 各都市の気象情報を格納するリスト
  List<String> matchingCities = []; // 条件に一致する都市名を格納するリスト
  bool isLoading = true; // ローディング状態を示す変数
  LatLng? _currentLocation;
  GoogleMapController? _mapController;

  //定期処理
  @override
  void initState() {
    super.initState();
    _getLocation(); // 現在地を取得
    Timer.periodic(
      const Duration(seconds: 5),
      (Timer timer){
      fetchWeatherForCities();
      },
    );
  }

  Future<void> _getLocation() async {
    final locationData = await getCurrentLocation(); // geolocator.dart のメソッドを呼び出す
    if (locationData != null && locationData.latitude != null && locationData.longitude != null) {
      setState(() {
        _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
      });
    }
  }


List<String> tempMatchingCities = [];
  Future<void> fetchWeatherForCities() async {
    
    try {
      //List<Map<String, dynamic>> tempList = [];
      for (String cityName in cityNames) {
        final weatherData = await weatherApi.fetchWeather(cityName); 
        // tempList.add({// 各都市の気象情報をリストに追加
        //   "cityName": cityName,
        //   "humidity": weatherData["humidity"],
        //   "weather": weatherData["weather"],
        //   "detailedWeather": weatherData["detailed_weather"],
        //   "clouds": weatherData["clouds"],
        //   "atmosphericPressure": weatherData["atmospheric_pressure"]
        // });
        //湿度が10%以上、天気が晴れ、詳しい天気が快晴、雲の量が10%以上、大気圧が1000hPa以上の都市をリストに追加
        if(weatherData["humidity"] >= 10 &&
          weatherData["weather"] == "Clouds" &&
          weatherData["detailed_weather"] == "broken clouds" &&
          weatherData["clouds"] >= 10 &&
          weatherData["atmospheric_pressure"] >= 1000){
          tempMatchingCities.add(cityName);
          log(cityName);
        }
        
      }
      setState(() {
        //weatherDataList = tempList;
        matchingCities = tempMatchingCities;
        isLoading = false; // ローディング完了
      });
    } catch (e) {
      log("Error: $e");
      setState(() {
        isLoading = false; // ローディング完了
      });
    }

  
  }


AssetImage hyouzi(String name) { 
  for (int i = 0; i < matchingCities.length; i++) {
    if (matchingCities[i] == name) {
      return const AssetImage("image/cloud2.jpg");
    }
  }
  return const AssetImage("image/bluesky.jpg");
}

  double cradius = 50;//入道雲の幅
  @override
  Widget build(BuildContext context) {
    log("再描画");
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
              myLocationEnabled: true, // 背景なので現在地表示はオフにする
              myLocationButtonEnabled: false,
              scrollGesturesEnabled: false, // スクロール操作を無効にする
              zoomControlsEnabled: false, // ズームコントロールを無効にする
              zoomGesturesEnabled: false, // ズーム操作を無効にする
              tiltGesturesEnabled: false, // チルト操作を無効にする
              rotateGesturesEnabled: false, // 回転操作を無効にする
            ),
          Positioned(//方角の画像
            top: 10.0,
            left: 300.0,
            width: 80.0,
            height: 80.0,
            child: Image.asset("image/direction.png"),
          ),
          Positioned(//北の入道雲
            top: 100.0,
            left: 150.0,
            child: CircleAvatar(
            radius: cradius,
            backgroundColor: Colors.white,
            backgroundImage: hyouzi("Ninohe"),
            ),    
          ),
          Positioned(//南の入道雲
            top: 500.0,
            left: 150.0,
            child: CircleAvatar(
            radius: cradius,
            backgroundColor: Colors.white,
            backgroundImage: hyouzi("Hanamaki"),
            ),    
          ),
          Positioned(//東の入道雲
            top: 300.0,
            left: 280.0,
            child: CircleAvatar(
            radius: cradius,
            backgroundColor: Colors.white,
            backgroundImage: hyouzi("Miyako"),
            ),    
          ),
          Positioned(//西の入道雲
            top: 300.0,
            left: 10.0,
            child: CircleAvatar(
            radius: cradius,
            backgroundColor: Colors.white,
            backgroundImage: hyouzi("Senboku"),
            ),    
          ),
        ]
    ),
    );
  }
}
