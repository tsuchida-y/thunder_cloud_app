import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'notification.dart';
import 'push_notification.dart';

/// アプリケーション全体の初期化を管理するサービス
class AppInitializationService {
  static bool _isInitialized = false;

  /// 初期化状態の確認
  static bool get isInitialized => _isInitialized;

  /// アプリケーションの高速初期化（最小限のみ）
  static Future<void> initializeApp() async {
    if (_isInitialized) {
      dev.log("✅ アプリは既に初期化済みです");
      return;
    }

    try {
      dev.log("🚀 アプリケーション高速初期化開始");

      // 最小限のFirebase初期化のみ
      await _initializeFirebaseCore();

      _isInitialized = true;
      dev.log("✅ 高速初期化完了");

      // 残りの初期化はバックグラウンドで実行
      _initializeServicesInBackground();

    } catch (e) {
      dev.log("❌ アプリケーション初期化エラー: $e");
      // エラーでも続行（アプリは起動する）
    }
  }

  /// Firebase Coreのみの最小初期化
  static Future<void> _initializeFirebaseCore() async {
    try {
      dev.log("🔥 Firebase Core初期化開始");

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      dev.log("✅ Firebase Core初期化完了");
    } catch (e) {
      dev.log("❌ Firebase Core初期化エラー: $e");
      rethrow;
    }
  }

  /// バックグラウンドで残りのサービスを初期化
  static void _initializeServicesInBackground() {
    Future.microtask(() async {
      try {
        dev.log("🔄 バックグラウンド初期化開始");

        // バックグラウンド通知ハンドラーを設定
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // 通知サービスを並列初期化
        await _initializeNotificationServices();

        // デバッグ時のみFirestore接続テスト（軽量化）
        if (kDebugMode) {
          await _quickFirestoreTest();
        }

        dev.log("✅ バックグラウンド初期化完了");
      } catch (e) {
        dev.log("❌ バックグラウンド初期化エラー: $e");
      }
    });
  }

  /// 通知サービスの並列初期化
  static Future<void> _initializeNotificationServices() async {
    try {
      dev.log("🔔 通知サービス並列初期化開始");

      // 並列で両方の通知サービスを初期化
      await Future.wait([
        NotificationService.initialize(),
        PushNotificationService.initialize(),
      ]);

      dev.log("✅ 通知サービス初期化完了");
    } catch (e) {
      dev.log("❌ 通知サービス初期化エラー: $e");
    }
  }

  /// 軽量なFirestore接続確認
  static Future<void> _quickFirestoreTest() async {
    try {
      dev.log("🔍 軽量Firestore接続確認");

      // 単純なinstance取得のみで接続確認
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      dev.log("✅ Firestore接続確認完了");
    } catch (e) {
      dev.log("❌ Firestore接続確認エラー: $e");
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