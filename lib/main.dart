import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/home/home_screen.dart';
import 'services/core/app_initialization.dart';
import 'theme/app_theme.dart';
import 'utils/logger.dart';

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
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// アプリ全体の初期化（通知、位置情報、必要なサービスのセットアップなど）
  Future<void> _initializeApp() async {
    try {
      AppLogger.info('アプリケーション初期化開始', tag: 'MyApp');
      await AppInitializationService.initializeApp();
      AppLogger.success('アプリケーション初期化完了', tag: 'MyApp');
    } catch (e) {
      AppLogger.error('アプリケーション初期化エラー', error: e, tag: 'MyApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '入道雲サーチ',
      theme: AppTheme.light,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
