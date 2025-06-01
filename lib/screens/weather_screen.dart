import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunder_cloud_app/constants/weather_constants.dart';
import 'package:thunder_cloud_app/services/notification_service.dart';
import 'package:thunder_cloud_app/services/weather/advanced_weather_api.dart';
import 'package:thunder_cloud_app/services/weather/thunder_cloud_analyzer.dart';
import 'package:thunder_cloud_app/services/weather/weather_logic.dart';
import 'package:thunder_cloud_app/widgets/weather_detail_dialog.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../widgets/weather_app_bar.dart';
import '../widgets/weather_map_view.dart';
import '../widgets/weather_overlay.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

///入道雲サーチアプリのメイン画面を管理するStateクラス
class WeatherScreenState extends State<WeatherScreen> {
  List<String> matchingCities = [];
  bool isLoading = true;
  LatLng? _currentLocation;
  Timer? _weatherTimer;
  List<String> _previousMatchingCities = []; // 前回の結果を保存

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _getLocation();
    _startWeatherUpdates();
  }

  //現在地を取得する関数
  Future<void> _getLocation() async {
    try {
      final location = await LocationService.getCurrentLocationAsLatLng();
      if (mounted) {
        setState(() {
          _currentLocation = location;
        });
      }
    } catch (e) {
      print("位置情報取得エラー: $e");
    }
  }

  //天気情報を定期的に取得する関数（最適化版）
  void _startWeatherUpdates() {
    // ✅ WeatherConstantsから推奨間隔を計算
    final configInfo = WeatherConstants.getConfigInfo();
    final estimatedRequests = configInfo['estimatedDailyRequests'] as int;

    // Open-Meteoの制限（10,000/日）を考慮した間隔調整
    int intervalSeconds = 180; // デフォルト
    if (estimatedRequests > 9000) {
      intervalSeconds = 240; // 4分間隔
    } else if (estimatedRequests > 7000) {
      intervalSeconds = 200; // 3分20秒間隔
    }

    print("API使用量予測: ${estimatedRequests}リクエスト/日, 間隔: ${intervalSeconds}秒");

    _weatherTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (Timer timer) {
        if (_currentLocation != null) {
          _checkWeatherInDirections();
        }
      },
    );
  }

  //各方向の天気をチェックして、入道雲がある方向を特定する関数
  Future<void> _checkWeatherInDirections() async {
    if (_currentLocation == null) return;

    try {
      final result = await WeatherService.getAdvancedThunderCloudDirections(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      // 新しい入道雲が出現した場合のみ通知
      final newClouds = result
          .where((direction) => !_previousMatchingCities.contains(direction))
          .toList();

      if (newClouds.isNotEmpty) {
        print("新しい入道雲を検出: $newClouds");
        await NotificationService.showThunderCloudNotification(newClouds);
      }

      if (mounted) {
        setState(() {
          matchingCities = result;
          _previousMatchingCities = List.from(result);
          isLoading = false;
        });
      }
    } catch (e) {
      print("Open-Meteo分析エラー: $e");
      // フォールバック処理を削除、エラー時は空の結果を設定
      if (mounted) {
        setState(() {
          matchingCities = [];
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WeatherAppBar(),
      body: Stack(
        children: [
          BackgroundMapWidget(currentLocation: _currentLocation),
          CloudStatusOverlay(matchingCities: matchingCities),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "detailed_analysis",
            onPressed: () async {
              if (_currentLocation == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('位置情報が取得できていません')),
                );
                return;
              }

              // ローディング表示
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                // ✅ 実際の詳細結果を取得
                final detailedResults = await fetchDetailedWeatherInDirections(
                  _currentLocation!.latitude,
                  _currentLocation!.longitude,
                );

                // ✅ 現在地の実際の気象データを取得
                final realWeatherData =
                    await AdvancedWeatherApi.fetchAdvancedWeatherData(
                  _currentLocation!.latitude,
                  _currentLocation!.longitude,
                );

                // ✅ 実際のデータで分析を実行
                final realAssessment =
                    ThunderCloudAnalyzer.analyzeWithMeteoDataOnly(
                  realWeatherData,
                );

                // ローディングダイアログを閉じる
                Navigator.of(context).pop();

                // ✅ 詳細ダイアログを表示（実データ使用）
                showDialog(
                  context: context,
                  builder: (context) => WeatherDetailDialog(
                    assessment: realAssessment,
                    detailedResults: detailedResults,
                  ),
                );

                print("📱 詳細分析ダイアログ表示:");
                print("  実際のCAPE: ${realWeatherData['cape']}");
                print("  実際のLI: ${realWeatherData['lifted_index']}");
                print(
                    "  実際のスコア: ${(realAssessment.totalScore * 100).toStringAsFixed(1)}%");
              } catch (e) {
                // ローディングダイアログを閉じる
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('詳細分析の取得に失敗しました: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
                print("❌ 詳細分析エラー: $e");
              }
            },
            backgroundColor: Colors.blue,
            child: const Icon(Icons.analytics),
          ),
        ],
      ),
    );
  }
}
