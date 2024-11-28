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
      // weatherData["weather"] == "Clear" &&
      // weatherData["detailed_weather"] == "clear sky" &&
      // weatherData["clouds"] >= 10 &&
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
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator() // ローディング中はインジケーターを表示
            : ListView.builder(
                itemCount: weatherDataList.length,//リストビューに表示するアイテムの数を指定
                itemBuilder: (context, index) {//リストビューの各アイテムをビルドするための関数。contextとindexを引数に取る
                  final weatherData = weatherDataList[index];
                  return Card(
                    margin: const EdgeInsets.all(10),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(
                              "${weatherData['cityName']} の天気", // 都市名を表示
                              style: const TextStyle(fontSize: 24),
                            ),

                          const SizedBox(height: 10),
                            Text(
                              "湿度: ${weatherData['humidity']} %", // 湿度を表示
                              style: const TextStyle(fontSize: 18),
                            ),
                          Text(
                              "天気: ${weatherData['weather']}", // 天気を表示
                              style: const TextStyle(fontSize: 18),
                          ),
                          Text(
                              "詳しい天気: ${weatherData['detailedWeather']}", // 詳しい天気を表示
                              style: const TextStyle(fontSize: 18),
                          ),
                          Text(
                              "雲の量: ${weatherData['clouds']} %", // 雲の量を表示
                              style: const TextStyle(fontSize: 18),
                          ),
                          Text(
                              "大気圧: ${weatherData['atmosphericPressure']} hPa", // 大気圧を表示
                              style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}