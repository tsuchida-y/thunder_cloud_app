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
                    "Weather in $cityName", // 都市名を表示
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Description: $weatherDescription", // 天気の説明を表示
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    "Temperature: $temperature°C", // 温度を表示
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
      ),
    );
  }
}