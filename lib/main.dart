import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';
import 'screens/community_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/weather_screen.dart';
import 'services/core/app_initialization.dart';
import 'widgets/common/app_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // アプリケーション全体の初期化（バックグラウンドで実行）
  AppInitializationService.initializeApp();

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
      home: const MainScreen(),
      routes: {
        '/camera': (context) => const CameraScreen(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 画面の再構築用のキー（地図画面は固定、他は再構築）
  final GlobalKey<WeatherScreenContentState> _weatherKey = GlobalKey<WeatherScreenContentState>();
  Key _galleryKey = UniqueKey();
  Key _communityKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WeatherAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          WeatherScreenContent(key: _weatherKey),
          GalleryScreenContent(key: _galleryKey),
          CommunityScreenContent(key: _communityKey),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(135, 206, 250, 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavButton(
                  icon: Icons.map,
                  label: '地図',
                  index: 0,
                ),
                _buildNavButton(
                  icon: Icons.photo_library,
                  label: 'ギャラリー',
                  index: 1,
                ),
                _buildNavButton(
                  icon: Icons.people,
                  label: 'コミュニティ',
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 2 // コミュニティ画面の時のみ表示
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.pushNamed(context, '/camera');
                // カメラから戻ってきた時にデータを再読み込み
                if (result == true) {
                  _refreshCurrentScreen();
                }
              },
              backgroundColor: const Color.fromRGBO(135, 206, 250, 1.0),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
              ),
            )
          : null,
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        // 画面遷移後の処理
        if (index == 0) {
          // 地図画面への遷移時は軽量更新
          _weatherKey.currentState?.lightweightUpdate();
        } else {
          // 他の画面への遷移時はデータ再読み込み
          _refreshCurrentScreen();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 現在の画面のデータを再読み込み（画面を再構築）
  void _refreshCurrentScreen() {
    setState(() {
      switch (_currentIndex) {
        case 0:
          // 地図画面は再構築しない（固定キー使用）
          break;
        case 1:
          _galleryKey = UniqueKey();
          break;
        case 2:
          _communityKey = UniqueKey();
          break;
      }
    });
  }
}