import 'dart:convert'; // JSONデータの解析に使用
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  String apiKey = "YOUR_API_KEY"; // OpenWeatherMapで取得したAPIキーを設定
  String cityName = "Tokyo"; // 取得したい都市名
  String weatherDescription = "";
  double temperature = 0.0;

  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  Future<void> fetchWeather() async {
    try {
      // APIエンドポイント
      final url =
          "https://api.openweathermap.org/data/2.5/weather?q=$cityName&appid=$apiKey&units=metric";

      // HTTP GETリクエストを送信
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // レスポンスを解析
        final data = jsonDecode(response.body);
        setState(() {
          weatherDescription = data["weather"][0]["description"];
          temperature = data["main"]["temp"];
        });
      } else {
        print("Failed to load weather data");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Weather App"),
      ),
      body: Center(
        child: weatherDescription.isEmpty
            ? CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Weather in $cityName",
                    style: TextStyle(fontSize: 24),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Description: $weatherDescription",
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    "Temperature: $temperature°C",
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
      ),
    );
  }
}
