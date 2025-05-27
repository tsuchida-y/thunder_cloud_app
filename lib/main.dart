import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:thunder_cloud_app/services/background_service.dart';
import 'package:thunder_cloud_app/services/notification_service.dart';
import 'screens/weather_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

    // 通知サービスの初期化
  await NotificationService.initialize();
  await NotificationService.requestPermissions();
  
  // バックグラウンドサービスの初期化
  await BackgroundService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thunder Cloud App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const WeatherScreen(),
      // 将来的なルーティング用
      // routes: {
      //   '/weather': (context) => const WeatherScreen(),
      //   '/settings': (context) => const SettingsScreen(),
      // },
    );
  }
}