import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';
import 'screens/community_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/weather_screen.dart';
import 'services/core/app_initialization.dart';

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
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(135, 206, 250, 1.0),
        ),
      ),
      home: const WeatherScreen(),
      routes: {
        '/weather': (context) => const WeatherScreen(),
        '/camera': (context) => const CameraScreen(),
        '/gallery': (context) => const GalleryScreen(),
        '/community': (context) => const CommunityScreen(),
      },
    );
  }
}