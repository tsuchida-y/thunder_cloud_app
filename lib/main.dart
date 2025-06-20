import 'package:flutter/material.dart';

import 'screens/weather_screen.dart';
import 'services/app_initialization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // アプリケーション全体の初期化
  await AppInitializationService.initializeApp();

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thunder Cloud App',
      debugShowCheckedModeBanner: false,
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