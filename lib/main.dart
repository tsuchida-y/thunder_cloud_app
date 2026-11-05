import 'dart:async';
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/home/home_screen.dart';
import 'screens/intro/intro_screen.dart';
import 'screens/plus/plus_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'services/notification/cloud_notifications.dart';
import 'theme/app_theme.dart';
import 'utils/logger.dart';
import 'widgets/common/loading_view.dart';

/// アプリが閉じているときに届いた通知
///
/// Android はデータだけが届くので、ここでボタン付きの通知を出す。iOS は OS がそのまま出す。
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!Platform.isAndroid) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CloudNotifications.showFromData(message.data);
}

/// App Check（本物のアプリからの通信だけを Firebase に通す仕組み）を始める
///
/// iPhone は App Attest（使えない端末は DeviceCheck）、Android は Play Integrity。デバッグ版はデバッグ用の印を使う。
/// いまは Firebase 側で「強制」にしていないので、失敗してもアプリは今までどおり動く（記録が残るだけ）。
/// 強制にすると、App Check を持たない v1（1.0.4）が使えなくなるので、v1 を止めたあとに行う。
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (e) {
    AppLogger.warning('App Check を始められませんでした: $e', tag: 'main');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 画面の向きを縦向きに固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // 通知の準備は画面を出すのと並べて進める（iOS で返事が遅いことがあるため、待たない）
  unawaited(CloudNotifications.initialize());

  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(showIntro: !IntroScreen.isDone(prefs), showWelcome: !WelcomeScreen.isDone(prefs)));
}

/// アプリケーションのルートウィジェット
///
/// はじめての起動では Intro（使い方）→ Welcome（許可のお願い）、2回目からはホーム。
/// 匿名ログイン・位置・雲の一覧の読み込みは、ホーム（HomeController）が始める。
class MyApp extends StatelessWidget {
  final bool showIntro;
  final bool showWelcome;

  const MyApp({super.key, this.showIntro = false, this.showWelcome = false});

  /// 開発中の確かめ用。デバッグ版で --dart-define=START_SCREEN=plus を付けると、起動したら Plus の画面を出す
  /// （ストアの審査用のスクリーンショットをシミュレータで撮るため）。START_SCREEN=loading なら読み込み画面を出し続ける
  static const String _startScreen = kDebugMode ? String.fromEnvironment('START_SCREEN') : '';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '入道雲サーチ',
      theme: AppTheme.light,
      home: _startScreen == 'plus'
          ? const PlusScreen()
          : _startScreen == 'loading'
              ? const LoadingView()
              : showIntro
                  ? const IntroScreen()
                  : showWelcome
                      ? const WelcomeScreen()
                      : const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
