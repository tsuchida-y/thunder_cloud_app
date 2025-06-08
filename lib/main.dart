import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:thunder_cloud_app/services/notification_service.dart';
import 'package:thunder_cloud_app/services/push_notification_service.dart';

import 'firebase_options.dart';
import 'screens/weather_screen.dart';

/// ユーザーがアプリを閉じても入道雲通知を受信
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // アプリが終了・最小化時に FCM 通知を受信する処理
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("バックグラウンドメッセージ受信: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    //Firebaseの初期化
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Firestoreの接続テスト
    await _testFirestoreConnection();

    // バックグラウンド通知設定
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 通知サービスの初期化（権限リクエストも含む）
    await NotificationService.initialize();//ローカル通知
    await PushNotificationService.initialize();//FCM通知

    // FCMトークンの取得と確認
    final fcmToken = PushNotificationService.fcmToken;
    print("main.dart でのFCMトークン確認: ${fcmToken?.substring(0, 20) ?? 'null'}...");

    runApp(const MyApp());
  } catch (e) {
    print("初期化エラー: $e");
    runApp(const MyApp()); // エラーがあってもアプリは起動
  }
}
/// Firestore 接続テスト
Future<void> _testFirestoreConnection() async {
  try {
    print("Firestore 接続テスト開始");

    final firestore = FirebaseFirestore.instance;
    print("Firestore インスタンス取得成功: ${firestore.app.name}");

    // 基本的な接続テスト（読み取り権限不要）
    final testDoc = firestore.collection('_test_connection').doc('init');

    // タイムスタンプのみの軽量ドキュメント作成
    await testDoc.set({
      'timestamp': FieldValue.serverTimestamp(),
      'source': 'main_init',
      'version': '1.0.0',
    }, SetOptions(merge: true));

    print("Firestore 基本接続テスト成功");

    // テストドキュメント削除（クリーンアップ）
    await testDoc.delete();
    print("🧹 テストドキュメント削除完了");

  } catch (e) {
    print("Firestore 接続テストエラー: $e");
    print("Firestore が正しく設定されていない可能性があります");
    // エラーでも続行（アプリは起動する）
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