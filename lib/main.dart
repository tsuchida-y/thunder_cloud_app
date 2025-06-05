import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:thunder_cloud_app/services/notification_service.dart';
import 'package:thunder_cloud_app/services/push_notification_service.dart';

import 'firebase_options.dart';
import 'screens/weather_screen.dart';

// バックグラウンドメッセージハンドラー
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("📨 バックグラウンドメッセージ受信: ${message.messageId}");
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase初期化成功");
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    // 通知サービスの初期化（権限リクエストも含む）
    await NotificationService.initialize();
    await PushNotificationService.initialize();

    runApp(const MyApp());
  } catch (e) {
    print("初期化エラー: $e");
    runApp(const MyApp()); // エラーがあってもアプリは起動
  }
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