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
      home: WeatherScreen(),//ホーム画面として設定
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherApi weatherApi = WeatherApi();
  String cityName = "Sendai"; // 取得したい都市名
  String weatherDescription = ""; // 天気の説明をするための変数
  double temperature = 0.0; // 温度を格納するための変数

  double humidity = 0.0; // 湿度を格納するための変数
  String weather = ""; // 天気を格納するための変数
  String detailedWeather = ""; // 詳しい天気を格納するための変数
  double clouds = 0.0; // 雲の量を格納するための変数
  double atmosphericPressure = 0.0; // 大気圧を格納するための変数

  bool isLoading = true; // ローディング状態を示す変数

  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  Future<void> fetchWeather() async {
    try {
      final weatherData = await weatherApi.fetchWeather(cityName);
      setState(() {
        weatherDescription = weatherData["description"];//天気の説明を取得
        temperature = weatherData["temperature"];//温度を取得

        humidity=weatherData["humidity"];//湿度を取得
        weather=weatherData["weather"];//天気を取得
        detailedWeather=weatherData["detailed_weather"];//詳しい天気を取得
        clouds=weatherData["clouds"];//雲の量を取得
        atmosphericPressure-weatherData["atmospheric_pressure"];//大気圧を取得

        isLoading = false; // ローディング完了
      });
    } catch (e) {
      print(e);
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
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator() // ローディング中はインジケーターを表示
            : Column(
                mainAxisAlignment: MainAxisAlignment.center, // 中央に配置
                children: [
                  Text(
                    "$cityName の天気", // 都市名を表示
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "説明: $weatherDescription", // 天気の説明を表示
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    "温度: $temperature°C", // 温度を表示
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    "湿度: $humidity%", // 湿度を表示
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    "天気: $weather", // 天気を表示
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    "詳しい天気: $detailedWeather", // 詳しい天気を表示
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    "雲の量: $clouds%", // 雲の量を表示
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    "大気圧: $atmosphericPressure%", // 大気圧を表示
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
      ),
    );
  }
}