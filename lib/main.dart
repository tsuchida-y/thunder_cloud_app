import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'constants/app_constants.dart';
import 'firebase_options.dart';
import 'screens/camera_screen.dart';
import 'screens/community_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/weather_screen.dart';
import 'services/core/app_initialization.dart';
import 'services/location/location_service.dart';
import 'utils/logger.dart';
import 'widgets/common/app_bar.dart';

/// バックグラウンドメッセージハンドラー
/// アプリがバックグラウンドまたは終了状態の時にFCM通知を処理
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase初期化（バックグラウンド用）
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  AppLogger.info('📨 バックグラウンドメッセージ受信: ${message.messageId}', tag: 'BackgroundHandler');
  AppLogger.info('📨 タイトル: ${message.notification?.title}', tag: 'BackgroundHandler');
  AppLogger.info('📨 本文: ${message.notification?.body}', tag: 'BackgroundHandler');
  AppLogger.info('📨 データ: ${message.data}', tag: 'BackgroundHandler');
}

void main() async {
  //ネイティブコードとのやりとりのために必要
  //asyncのmain()関数を使う場合、この初期化は必須
  WidgetsFlutterBinding.ensureInitialized();

  // 画面の向きを縦向きに固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebaseを初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // バックグラウンドメッセージハンドラーを登録
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

/// アプリケーションのルートウィジェット
/// テーマとナビゲーションの基本設定を管理
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "入道雲サーチ",
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

/// メイン画面 - タブナビゲーションと各画面の管理
/// 天気画面、ギャラリー画面、コミュニティ画面を切り替え
class MainScreen extends StatefulWidget {
  final int initialTab;

  const MainScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  // ウィジェットを一意に識別するための各画面のキーを管理
  GlobalKey<WeatherScreenState> weatherScreenKey = GlobalKey<WeatherScreenState>();
  GlobalKey galleryScreenKey = GlobalKey();
  GlobalKey communityScreenKey = GlobalKey();

  // 画面インスタンスを保持（再構築を防ぐことで状態を保持や処理コストの向上につながる）
  late final Widget weatherScreen;
  late final Widget galleryScreen;
  late final Widget communityScreen;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;

    // 画面インスタンスを一度だけ作成
    weatherScreen = WeatherScreen(
      key: weatherScreenKey,
      onProfileUpdated: _refreshAllScreens,//プロフィール更新時に呼び出されるコールバック
    );
    galleryScreen = GalleryScreen(key: galleryScreenKey);
    communityScreen = CommunityScreen(
      key: communityScreenKey,
      onPhotoDownloaded: _refreshGallery,//コミュニティから写真がダウンロードされた後に呼び出されるコールバック
    );

    _initializeApp();
  }

  /// アプリケーション初期化処理メソッド
  /// アプリ全体の初期化（Firebase、位置情報、通知、必要なサービスのセットアップなど）を実行
  Future<void> _initializeApp() async {
    try {
      AppLogger.info('アプリケーション初期化開始', tag: 'MainScreen');
      await AppInitializationService.initializeApp();

      // 少し待ってから位置情報の自動保存を実行
      // 位置情報保存処理は既にinitializeApp内で実行される
      await Future.delayed(const Duration(seconds: 2));

      AppLogger.success('アプリケーション初期化完了', tag: 'MainScreen');
    } catch (e) {
      AppLogger.error('アプリケーション初期化エラー', error: e, tag: 'MainScreen');
    }
  }

  /// ギャラリーを更新（ダウンロード後に呼び出される）
  void _refreshGallery() {
    AppLogger.info('ギャラリー更新要求: コミュニティからのダウンロード後', tag: 'MainScreen');

    try {
      // ギャラリー画面のrefreshDataメソッドを呼び出し
      GalleryScreen.refreshGallery(galleryScreenKey);
      AppLogger.success('ギャラリー更新完了', tag: 'MainScreen');
    } catch (e) {
      AppLogger.error('ギャラリー更新エラー', error: e, tag: 'MainScreen');
      // エラーの場合は従来の方法（キー再生成）を使用
      setState(() {
        galleryScreenKey = GlobalKey();
      });
    }
  }

  /// 全画面を更新（プロフィール変更時に呼び出される）
  /// ギャラリーとコミュニティ画面を強制再構築し、天気画面は軽量更新
  void _refreshAllScreens() {
    // コミュニティ画面のデータを更新（キー再生成ではなく、既存インスタンスの更新メソッドを使用）
    try {
      final communityScreenState = communityScreenKey.currentState;
      if (communityScreenState != null) {
        // CommunityScreenのrefreshDataメソッドを呼び出し
        (communityScreenState as dynamic).refreshData();
        AppLogger.info('コミュニティ画面のデータ更新完了', tag: 'MainScreen');
      }
    } catch (e) {
      AppLogger.warning('コミュニティ画面データ更新エラー: $e', tag: 'MainScreen');
      // エラーの場合は従来の方法（キー再生成）を使用
      setState(() {
        communityScreenKey = GlobalKey();
      });
    }

    setState(() {
      // ギャラリーのキーを再生成して強制再構築
      galleryScreenKey = GlobalKey();
    });

    // WeatherScreenの軽量更新を削除（位置情報の状態リセットを防ぐ）
    // weatherScreenKey.currentState?.setState(() {});
  }

  /// 現在の位置情報を取得
  LatLng? _getCurrentLocation() {
    // まずキャッシュされた位置情報を確認
    final cachedLocation = LocationService.cachedLocation;
    if (cachedLocation != null) {
      return cachedLocation;
    }

    // キャッシュがない場合のみWeatherScreenから取得
    if (_currentIndex == AppConstants.navigationIndexWeather) {
      return weatherScreenKey.currentState?.getCurrentLocationForAppBar();
    }

    return null;
  }

  /// 現在の画面タイトルを取得
  String _getCurrentScreenTitle() {
    switch (_currentIndex) {
      case AppConstants.navigationIndexWeather:
        return '入道雲';
      case AppConstants.navigationIndexGallery:
        return 'ギャラリー';
      case AppConstants.navigationIndexCommunity:
        return 'コミュニティ';
      default:
        return '入道雲';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WeatherAppBar(
        currentLocation: _getCurrentLocation(),
        onProfileUpdated: _refreshAllScreens,
        title: _getCurrentScreenTitle(),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          weatherScreen,
          galleryScreen,
          communityScreen,
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// フローティングアクションボタンを構築
  /// コミュニティ画面でのみカメラボタンを表示
  Widget? _buildFloatingActionButton() {
    if (_currentIndex != AppConstants.navigationIndexCommunity) {
      return null;
    }

    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CameraScreen(),
          ),
        );
      },
      backgroundColor: AppConstants.primarySkyBlue,
      child: const Icon(Icons.camera_alt, color: Colors.white),
    );
  }

  /// ボトムナビゲーションバーを構築
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppConstants.primarySkyBlue,
      selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white.withValues(alpha: 0.6),
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: AppConstants.fontSizeSmall,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: AppConstants.fontSizeSmall,
      ),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.cloud),
          label: '入道雲',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.photo_library),
          label: 'ギャラリー',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'コミュニティ',
        ),
      ],
    );
  }

}