import 'dart:convert'; // JSONデータの解析に使用
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
//StatefulWidget：状態をもつウィジェットを作成するための基底クラス
  @override
  //WeatherScreenウィジェットの状態を作成するためのメソッドを定義
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  String apiKey = "4647b7a69711570dbc2b475779b61ded"; // OpenWeatherMapで取得したAPIキーを設定
  String cityName = "Tokyo"; // 取得したい都市名
  String weatherDescription = "";//天気の説明をするための変数
  double temperature = 0.0;//温度を格納するための変数
  bool isLoading = true; // ローディング状態を示す変数

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

      // HTTP GETリクエストを非同期に送信し、そのレスポンスを取得する
      //await：非同期処理が完了するまで待機.この場合、HTTP GETリクエストが完了するまで待機
      //http.get：httpパッケージのGETリクエストメソッド
      //Uri.parse(url)：文字列のURLをUriオブジェクトに変換
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {//HTTPステータスコードが200(成功)の場合
        // HTTPレスポンスのボディをJSON形式からDartのオブジェクトにデコード
        final data = jsonDecode(response.body);
        setState(() {
          weatherDescription = data["weather"][0]["description"];//転機の説明を取得
          temperature = data["main"]["temp"];//温度を取得
        });
      } else {//失敗したら
        print("気象データの読み込みに失敗しました");

        setState(() {
          isLoading = false; // ローディング完了
        });

      }
    } catch (e) {//例外処理
      print("Error: $e");//例外の内容を出力
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
        child: weatherDescription.isEmpty//天気の説明が空の場合true,そうでない場合false
            ? const CircularProgressIndicator()//からの時にはローディングアイコンを表示
            : Column(//そうでない場合は天気情報を表示
                mainAxisAlignment: MainAxisAlignment.center, //中央に配置
                children: [
                  Text(
                    "Weather in $cityName",//都市名を表示
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Description: $weatherDescription",//天気の説明を表示
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    "Temperature: $temperature°C",//温度を表示
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
      ),
    );
  }
}
