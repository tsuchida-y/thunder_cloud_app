import 'package:flutter/material.dart';
import 'weather_api.dart';

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

  final List<String> cityNames = ["Miyako", "Kazuno", "Hanamaki", "Ninohe"]; // 取得したい都市名のリスト
  List<Map<String, dynamic>> weatherDataList = []; // 各都市の気象情報を格納するリスト
  List<String> matchingCities = []; // 条件に一致する都市名を格納するリスト


  bool isLoading = true; // ローディング状態を示す変数

  @override
  void initState() {
    super.initState();
    fetchWeatherForCities();
  }
List<String> tempMatchingCities = [];
  Future<void> fetchWeatherForCities() async {
    try {
      List<Map<String, dynamic>> tempList = [];
      List<String> tempMatchingCities = [];
      for (String cityName in cityNames) {
        final weatherData = await weatherApi.fetchWeather(cityName);
        tempList.add({// 各都市の気象情報をリストに追加
          "cityName": cityName,
          "humidity": weatherData["humidity"],
          "weather": weatherData["weather"],
          "detailedWeather": weatherData["detailed_weather"],
          "clouds": weatherData["clouds"],
          "atmosphericPressure": weatherData["atmospheric_pressure"]
        });
        //湿度が10%以上、天気が晴れ、詳しい天気が快晴、雲の量が10%以上、大気圧が1000hPa以上の都市をリストに追加
    if(weatherData["humidity"] >= 10 &&
       weatherData["weather"] == "Rain" &&
       weatherData["detailed_weather"] == "light rain" &&
       weatherData["clouds"] >= 10 &&
      weatherData["atmospheric_pressure"] >= 1000){
      tempMatchingCities.add(cityName);
    }
      }
      setState(() {
        weatherDataList = tempList;
        matchingCities = tempMatchingCities;
        isLoading = false; // ローディング完了
      });
    } catch (e) {
      print("Error: $e");
      setState(() {
        isLoading = false; // ローディング完了
      });
    }


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Weather App"),
      ),
      body: Container(
          decoration: const BoxDecoration(
          image: DecorationImage(
          image: AssetImage('image/入道雲写真.png'),
          fit: BoxFit.cover,// 画像を全体に表示
          )
          ),
      )
    );
  }
}
