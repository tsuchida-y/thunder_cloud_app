// lib/services/push_notification_service.dart - 完成版
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_service.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static String? _fcmToken;

  /// プッシュ通知サービスの初期化
  static Future<void> initialize() async {
    log("🔔 プッシュ通知サービス初期化中...");

    try {
      // 通知権限をリクエスト
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      log("📱 FCM通知権限: ${settings.authorizationStatus}");

      // FCMトークンを取得
      _fcmToken = await _firebaseMessaging.getToken();
      log("🔑 FCMトークン: $_fcmToken");

      // フォアグラウンドメッセージのリスナー
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 通知タップ時の処理
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // アプリ起動時に通知から開かれたかチェック
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      log("✅ プッシュ通知サービス初期化完了");
    } catch (e) {
      log("❌ プッシュ通知サービス初期化エラー: $e");
    }
  }

  /// ユーザー位置情報をFirestoreに保存
  static Future<void> saveUserLocation(double latitude, double longitude) async {
    if (_fcmToken == null) {
      log("⚠️ FCMトークンが未取得のため位置情報保存をスキップ");
      return;
    }

    try {
      await _firestore.collection('users').doc(_fcmToken).set({
        'fcmToken': _fcmToken,
        'latitude': latitude,
        'longitude': longitude,
        'lastUpdated': FieldValue.serverTimestamp(),
        'isActive': true,
        'appVersion': '1.0.0',
        'platform': 'flutter',
      }, SetOptions(merge: true));

      log("📍 ユーザー位置情報保存完了: (${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})");
    } catch (e) {
      log("❌ ユーザー位置情報保存エラー: $e");
    }
  }

  /// フォアグラウンドでメッセージを受信した時の処理
  static void _handleForegroundMessage(RemoteMessage message) {
    log("📨 フォアグラウンドメッセージ受信: ${message.notification?.title}");

    // 入道雲通知の場合
    if (message.data['type'] == 'thunder_cloud') {
      final directionsData = message.data['directions'] ?? '';
      final directions = directionsData.isNotEmpty ? directionsData.split(',') : <String>[];

      log("⛈️ 入道雲通知受信: $directions");

      // ローカル通知として表示
      NotificationService.showThunderCloudNotification(directions);
    }
  }

  /// 通知タップ時の処理
  static void _handleNotificationTap(RemoteMessage message) {
    log("👆 通知がタップされました: ${message.data}");

    if (message.data['type'] == 'thunder_cloud') {
      log("⛈️ 入道雲通知タップ - 詳細画面へ遷移予定");
    }
  }

  /// FCMトークンを取得
  static String? get fcmToken => _fcmToken;

  /// ユーザーのアクティブ状態を更新
  static Future<void> updateUserActiveStatus(bool isActive) async {
    if (_fcmToken == null) return;

    try {
      await _firestore.collection('users').doc(_fcmToken).update({
        'isActive': isActive,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      log("📱 ユーザーアクティブ状態更新: $isActive");
    } catch (e) {
      log("❌ アクティブ状態更新エラー: $e");
    }
  }
}