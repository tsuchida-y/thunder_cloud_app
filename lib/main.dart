import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/home/home_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'services/notification/cloud_notifications.dart';
import 'theme/app_theme.dart';

/// アプリが閉じているときに届いた通知
///
/// Android はデータだけが届くので、ここでボタン付きの通知を出す。iOS は OS がそのまま出す。
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!Platform.isAndroid) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CloudNotifications.showFromData(message.data);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 画面の向きを縦向きに固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // 通知の準備は画面を出すのと並べて進める（iOS で返事が遅いことがあるため、待たない）
  unawaited(CloudNotifications.initialize());

  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(showWelcome: !WelcomeScreen.isDone(prefs)));
}

/// アプリケーションのルートウィジェット
///
/// はじめての起動では Welcome（許可のお願い）、2回目からはホーム。
/// 匿名ログイン・位置・雲の一覧の読み込みは、ホーム（HomeController）が始める。
class MyApp extends StatelessWidget {
  final bool showWelcome;

  const MyApp({super.key, this.showWelcome = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '入道雲サーチ',
      theme: AppTheme.light,
      home: showWelcome ? const WelcomeScreen() : const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
