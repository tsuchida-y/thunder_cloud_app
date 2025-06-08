import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';
import 'notification.dart';
import 'push_notification.dart';

/// アプリケーション全体の初期化を管理するサービス
class AppInitializationService {
  static bool _isInitialized = false;

  /// 初期化状態の確認
  static bool get isInitialized => _isInitialized;

  /// アプリケーションの完全初期化
  static Future<void> initializeApp() async {
    if (_isInitialized) {
      dev.log("✅ アプリは既に初期化済みです");
      return;
    }

    try {
      dev.log("🚀 アプリケーション初期化開始");

      // 並列で初期化を実行（高速化）
      final futures = [
        _initializeFirebase(),
        _initializeNotificationServices(),
      ];

      await Future.wait(futures);

      // Firebase接続テスト
      await _testFirestoreConnection();

      _isInitialized = true;
      dev.log("✅ アプリケーション初期化完了");

    } catch (e) {
      dev.log("❌ アプリケーション初期化エラー: $e");
      // エラーでも続行（アプリは起動する）
    }
  }

  /// Firebaseの初期化
  static Future<void> _initializeFirebase() async {
    try {
      dev.log("🔥 Firebase初期化開始");

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // バックグラウンド通知ハンドラーを設定
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      dev.log("✅ Firebase初期化完了");
    } catch (e) {
      dev.log("❌ Firebase初期化エラー: $e");
      rethrow;
    }
  }

  /// 通知サービスの初期化
  static Future<void> _initializeNotificationServices() async {
    try {
      dev.log("🔔 通知サービス初期化開始");

      // 並列で両方の通知サービスを初期化
      final futures = [
        NotificationService.initialize(),
        PushNotificationService.initialize(),
      ];

      await Future.wait(futures);

      dev.log("✅ 通知サービス初期化完了");
    } catch (e) {
      dev.log("❌ 通知サービス初期化エラー: $e");
      rethrow;
    }
  }

  /// Firestore接続テスト
  static Future<void> _testFirestoreConnection() async {
    try {
      dev.log("🔍 Firestore接続テスト開始");

      final firestore = FirebaseFirestore.instance;
      final testDoc = firestore.collection('_test_connection').doc('init');

      // 軽量ドキュメント作成テスト
      await testDoc.set({
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'app_init',
        'version': '1.0.0',
      }, SetOptions(merge: true));

      dev.log("✅ Firestore接続テスト成功");

      // クリーンアップ
      await testDoc.delete();

    } catch (e) {
      dev.log("❌ Firestore接続テストエラー: $e");
      // エラーでも続行
    }
  }

  /// FCMトークンの状態確認
  static String? getFCMTokenStatus() {
    final token = PushNotificationService.fcmToken;
    if (token == null) return null;

    dev.log("📝 FCMトークン状態: ${token.substring(0, 20)}...");
    return token;
  }
}

/// バックグラウンドメッセージハンドラー
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  dev.log("📨 バックグラウンドメッセージ受信: ${message.messageId}");
}