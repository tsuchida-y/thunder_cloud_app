import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'constants/app_constants.dart';
import 'firebase_options.dart';
import 'screens/community_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/weather_screen.dart';
import 'services/core/app_initialization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 画面の向きを縦向きに固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // .envファイルを読み込み
  await dotenv.load(fileName: ".env");

  // Firebaseを初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primarySkyBlue,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = AppConstants.navigationIndexWeather;

  // 各画面のキーを管理
  GlobalKey<WeatherScreenState> weatherScreenKey = GlobalKey<WeatherScreenState>();
  GlobalKey galleryScreenKey = GlobalKey();
  GlobalKey communityScreenKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await AppInitializationService.initializeApp();

      // 少し待ってから位置情報の自動保存を実行
      await Future.delayed(AppConstants.mainScreenDelay);
      // 位置情報保存処理は既にinitializeApp内で実行される
    } catch (e) {
      print("❌ アプリ初期化エラー: $e");
    }
  }

  /// 全画面を更新（プロフィール変更時に呼び出される）
  void _refreshAllScreens() {
    print("🔄 全画面更新開始");

    setState(() {
      // ギャラリーとコミュニティのキーを再生成して強制再構築
      galleryScreenKey = GlobalKey();
      communityScreenKey = GlobalKey();
    });

    // 地図画面は軽量更新
    weatherScreenKey.currentState?.refreshData();

    print("✅ 全画面更新完了");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppConstants.primarySkyBlue,
              Colors.white,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(AppConstants.opacityMinimal),
              blurRadius: AppConstants.elevationHigh,
              offset: AppConstants.shadowOffsetMedium,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppConstants.paddingLarge,
              vertical: AppConstants.paddingSmall
            ),
            child: Column(
              children: [
                _buildTabBar(),
                Expanded(child: _buildCurrentScreen()),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _currentIndex == AppConstants.navigationIndexCommunity // コミュニティ画面の時のみ表示
          ? FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/camera');
              },
              backgroundColor: AppConstants.primarySkyBlue,
              child: const Icon(Icons.camera_alt, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
      ),
      child: Row(
        children: [
          _buildTabButton(
            "地図",
            Icons.map,
            index: AppConstants.navigationIndexWeather,
          ),
          _buildTabButton(
            "ギャラリー",
            Icons.photo_library,
            index: AppConstants.navigationIndexGallery,
          ),
          _buildTabButton(
            "コミュニティ",
            Icons.people,
            index: AppConstants.navigationIndexCommunity,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, {required int index}) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
            vertical: AppConstants.paddingSmall
          ),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(AppConstants.opacityVeryLow)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: AppConstants.iconSizeLarge,
              ),
              SizedBox(height: AppConstants.paddingXSmall),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppConstants.fontSizeSmall,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0: // AppConstants.navigationIndexWeather
        return WeatherScreen(key: weatherScreenKey, onProfileUpdated: _refreshAllScreens);
      case 1: // AppConstants.navigationIndexGallery
        return GalleryScreen(key: galleryScreenKey);
      case 2: // AppConstants.navigationIndexCommunity
        return CommunityScreen(key: communityScreenKey);
      default:
        return WeatherScreen(key: weatherScreenKey, onProfileUpdated: _refreshAllScreens);
    }
  }
}