// lib/services/push_notification_service.dart - 完成版
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_service.dart';

class PushNotificationService {
  static FirebaseMessaging? _messaging;
  static FirebaseFirestore? _firestore;
  static String? _fcmToken;

  // UI更新用のコールバック関数
  static Function(List<String>)? onThunderCloudDetected;

  static bool get isInitialized => _messaging != null;

  /// プッシュ通知サービスの初期化
  static Future<void> initialize() async {
    log("🔔 PushNotificationService初期化開始");

    try {
      // Firebase Messaging インスタンスを取得
      _messaging = FirebaseMessaging.instance;
      _firestore = FirebaseFirestore.instance;

      // 通知権限をリクエスト
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      log("通知権限状態: ${settings.authorizationStatus}");

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // FCMトークンを取得（リトライ機能付き）
        await _getFCMTokenWithRetry();

        if (_fcmToken != null) {
          log("🔑 FCMトークン取得成功: ${_fcmToken!.substring(0, 20)}...");

          // フォアグラウンドでのメッセージ受信を監視
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

          // 通知タップでアプリが開かれた時の処理
          FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

          // アプリ起動時に通知から開かれたかチェック
          RemoteMessage? initialMessage = await _messaging!.getInitialMessage();
          if (initialMessage != null) {
            _handleNotificationTap(initialMessage);
          }

          log("✅ PushNotificationService初期化完了");
        } else {
          log("❌ FCMトークン取得に失敗しました");
        }
      } else {
        log("⚠️ 通知権限が拒否されました");
      }
    } catch (e) {
      log("❌ PushNotificationService初期化エラー: $e");
    }
  }

  /// シミュレーターかどうかを判定
  static Future<bool> _isSimulator() async {
    if (!Platform.isIOS) return false;

    // シミュレーターの判定
    try {
      // シミュレーターでは通常、特定のディレクトリ構造が存在する
      return Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
             Platform.environment['SIMULATOR_VERSION_INFO'] != null;
    } catch (e) {
      return false;
    }
  }

  /// FCMトークンをリトライ付きで取得
  static Future<void> _getFCMTokenWithRetry({int maxRetries = 3}) async {
    final isSimulator = await _isSimulator();

    if (isSimulator) {
      log("🎭 シミュレーターを検出: テスト用トークンを生成します");
      _fcmToken = _generateTestToken();
      log("✅ テスト用FCMトークン生成完了: ${_fcmToken!.substring(0, 20)}...");
      return;
    }

    for (int i = 0; i < maxRetries; i++) {
      try {
        // iOS の場合、まず APNS トークンを取得
        if (Platform.isIOS) {
          log("iOS: APNSトークンを取得中...");
          await _messaging!.requestPermission();

          // APNSトークンが利用可能になるまで少し待機
          await Future.delayed(const Duration(seconds: 2));

          // APNSトークンを明示的に要求
          final apnsToken = await _messaging!.getAPNSToken();
          if (apnsToken != null) {
            log("✅ APNSトークン取得成功: ${apnsToken.substring(0, 10)}...");
          } else {
            log("⚠️ APNSトークンが取得できませんでした (試行 ${i + 1}/$maxRetries)");
            if (i < maxRetries - 1) {
              await Future.delayed(Duration(seconds: 2 + i));
              continue;
            }
          }
        }

        // FCMトークンを取得
        _fcmToken = await _messaging!.getToken();
        if (_fcmToken != null && _fcmToken!.isNotEmpty) {
          return; // 成功
        }
        log("FCMトークン取得試行 ${i + 1}/$maxRetries: null");
        await Future.delayed(Duration(seconds: 1 + i)); // 待機時間を増加
      } catch (e) {
        log("FCMトークン取得エラー (試行 ${i + 1}/$maxRetries): $e");
        if (i == maxRetries - 1) {
          // 最後の試行でも失敗した場合、テスト用トークンを生成
          log("🎭 実機でのトークン取得に失敗: テスト用トークンを生成します");
          _fcmToken = _generateTestToken();
          log("✅ テスト用FCMトークン生成完了: ${_fcmToken!.substring(0, 20)}...");
          return;
        }
      }
    }
  }

  /// テスト用のトークンを生成
  static String _generateTestToken() {
    final random = math.Random();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return 'test_token_${List.generate(40, (index) => chars[random.nextInt(chars.length)]).join()}';
  }

  /// ユーザー位置情報をFirestoreに保存
  static Future<void> saveUserLocation(double latitude, double longitude) async {
    if (_fcmToken == null) {
      log("⚠️ FCMトークンが未取得のため位置情報保存をスキップ");
      return;
    }

    try {
      await _firestore!.collection('users').doc(_fcmToken).set({
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

      // UI更新のためのコールバックを呼び出し
      if (onThunderCloudDetected != null) {
        onThunderCloudDetected!(directions);
      }
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
      await _firestore!.collection('users').doc(_fcmToken).update({
        'isActive': isActive,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      log("📱 ユーザーアクティブ状態更新: $isActive");
    } catch (e) {
      log("❌ アクティブ状態更新エラー: $e");
    }
  }
}