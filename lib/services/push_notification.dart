// lib/services/push_notification_service.dart - リファクタリング版
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'fcm_token.dart';
import 'notification.dart';

/// プッシュ通知サービス（FCMメッセージ処理に特化）
class PushNotificationService {
  static FirebaseMessaging? _messaging;
  static FirebaseFirestore? _firestore;

  // UI更新用のコールバック関数
  static Function(List<String>)? onThunderCloudDetected;

  static bool get isInitialized => _messaging != null;

  /// プッシュ通知サービスの初期化
  static Future<void> initialize() async {
    dev.log("🔔 PushNotificationService初期化開始");

    try {
      // Firebase Messaging インスタンスを取得
      _messaging = FirebaseMessaging.instance;
      _firestore = FirebaseFirestore.instance;

      // ローカル通知は NotificationService.initialize() で既に処理済み
      dev.log("📱 ローカル通知権限は初期化時に処理済み");

      // FCM 通知権限をリクエスト
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      dev.log("🔥 FCM通知権限状態: ${settings.authorizationStatus}");

      // 権限が許可された場合、または暫定的に許可された場合
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {

        // FCMトークンを取得（専用マネージャーを使用）
        final token = await FCMTokenManager.getToken();

        if (token != null) {
          dev.log("🔑 FCMトークン取得成功: ${token.substring(0, 20)}...");

          // メッセージハンドラーを設定
          _setupMessageHandlers();

          dev.log("✅ PushNotificationService初期化完了");
        } else {
          dev.log("❌ FCMトークン取得に失敗しました");
        }
      } else {
        dev.log("⚠️ 通知権限が拒否されました: ${settings.authorizationStatus}");

        // 権限が拒否されていても基本機能は初期化
        final token = await FCMTokenManager.getToken();
        if (token != null) {
          _setupMessageHandlers();
          dev.log("📝 権限なしでも基本機能を初期化しました");
        }
      }
    } catch (e) {
      dev.log("❌ PushNotificationService初期化エラー: $e");
    }
  }

  /// メッセージハンドラーの設定
  static void _setupMessageHandlers() {
    // フォアグラウンドでのメッセージ受信を監視
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 通知タップでアプリが開かれた時の処理
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // アプリ起動時に通知から開かれたかチェック
    _checkInitialMessage();
  }

  /// 初期メッセージのチェック
  static void _checkInitialMessage() async {
    try {
      RemoteMessage? initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      dev.log("❌ 初期メッセージチェックエラー: $e");
    }
  }

  /// ユーザー位置情報をFirestoreに保存（本番環境のみ）
  static Future<void> saveUserLocation(double latitude, double longitude) async {
    // 開発環境では位置情報保存をスキップ
    if (kDebugMode) {
      dev.log("🚧 開発環境のため位置情報保存をスキップ: (${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})");
      return;
    }

    final fcmToken = FCMTokenManager.currentToken;

    if (fcmToken == null) {
      dev.log("⚠️ FCMトークンが未取得のため位置情報保存をスキップ");
      return;
    }

    // 開発用トークンの場合はスキップ
    if (fcmToken.startsWith('dev_token_')) {
      dev.log("🎭 開発用トークンのため位置情報保存をスキップ");
      return;
    }

    try {
      await _firestore!.collection('users').doc(fcmToken).set({
        'fcmToken': fcmToken,
        'latitude': latitude,
        'longitude': longitude,
        'lastUpdated': FieldValue.serverTimestamp(),
        'isActive': true,
        'appVersion': '1.0.0',
        'platform': 'flutter',
      }, SetOptions(merge: true));

      dev.log("📍 ユーザー位置情報保存完了: (${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})");
    } catch (e) {
      dev.log("❌ ユーザー位置情報保存エラー: $e");
    }
  }

  /// フォアグラウンドでメッセージを受信した時の処理
  static void _handleForegroundMessage(RemoteMessage message) {
    dev.log("📨 フォアグラウンドメッセージ受信: ${message.notification?.title}");

    // 入道雲通知の場合
    if (message.data['type'] == 'thunder_cloud') {
      final directionsData = message.data['directions'] ?? '';
      final directions = directionsData.isNotEmpty ? directionsData.split(',') : <String>[];

      dev.log("⛈️ 入道雲通知受信: $directions");

      // ローカル通知として表示
      NotificationService.showThunderCloudNotification(directions);

      // UI更新のためのコールバックを呼び出し
      if (onThunderCloudDetected != null) {
        onThunderCloudDetected!(directions);
      }
    }
  }

  /// 通知タップ時の処理
  static void _handleNotificationTap(RemoteMessage message) {
    dev.log("👆 通知がタップされました: ${message.data}");

    if (message.data['type'] == 'thunder_cloud') {
      dev.log("⛈️ 入道雲通知タップ - 詳細画面へ遷移予定");
    }
  }

  /// FCMトークンを取得（マネージャーを経由）
  static String? get fcmToken => FCMTokenManager.currentToken;

  /// ユーザーのアクティブ状態を更新（本番環境のみ）
  static Future<void> updateUserActiveStatus(bool isActive) async {
    // 開発環境ではアクティブ状態更新をスキップ
    if (kDebugMode) {
      dev.log("🚧 開発環境のためアクティブ状態更新をスキップ: $isActive");
      return;
    }

    final fcmToken = FCMTokenManager.currentToken;
    if (fcmToken == null) return;

    // 開発用トークンの場合はスキップ
    if (fcmToken.startsWith('dev_token_')) {
      dev.log("🎭 開発用トークンのためアクティブ状態更新をスキップ");
      return;
    }

    try {
      await _firestore!.collection('users').doc(fcmToken).update({
        'isActive': isActive,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      dev.log("📱 ユーザーアクティブ状態更新: $isActive");
    } catch (e) {
      dev.log("❌ アクティブ状態更新エラー: $e");
    }
  }

  /// サービス状態の詳細情報
  static Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': isInitialized,
      'hasCallback': onThunderCloudDetected != null,
      'fcmTokenStatus': FCMTokenManager.getTokenStatus(),
    };
  }

  /// リソースのクリーンアップ
  static void dispose() {
    onThunderCloudDetected = null;
    dev.log("🧹 PushNotificationService リソースクリーンアップ完了");
  }
}