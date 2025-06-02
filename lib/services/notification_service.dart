import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'dart:developer';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// 通知の初期化
  static Future<void> initialize() async {
    log("通知サービスを初期化中...");

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        log("通知がタップされました: ${response.payload}");
      },
    );

    // Android通知チャンネルの作成
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    // 権限リクエストをここで実行
    await requestPermissions();
  }

  /// iOS用の通知受信コールバック
  static Future<void> onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    log("iOS通知受信: $title - $body");
  }

  /// Android通知チャンネルの作成
  static Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'thunder_cloud_channel',
      '入道雲通知',
      description: '入道雲が出現した時の通知',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// 権限のリクエスト
  static Future<bool> requestPermissions() async {
    log("通知権限をリクエスト中...");

    if (Platform.isAndroid) {
      // Android 13+ の通知権限リクエスト
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      bool? androidResult;
      if (androidPlugin != null) {
        androidResult = await androidPlugin.requestNotificationsPermission();
      }
      
      log("Android通知権限リクエスト結果: $androidResult");
      return androidResult ?? false;
      
    } else if (Platform.isIOS) {
      // iOS の通知権限リクエスト
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final result = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        log("iOS通知権限リクエスト結果: $result");
        return result ?? false;
      }
    }
    return false;
  }

  /// 権限状態の確認
  static Future<void> checkPermissionStatus() async {
    if (Platform.isIOS) {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final enabled = await iosPlugin.checkPermissions();
        log("iOS通知権限状態: $enabled");
        log("Alert: ${enabled?.isEnabled}");
        log("Badge: ${enabled?.isEnabled}");
        log("Sound: ${enabled?.isEnabled}");
      }
    }
  }


  /// 入道雲出現通知
  static Future<void> showThunderCloudNotification(
      List<String> directions) async {
    if (directions.isEmpty) return;

    final directionsText = directions.join('、');//例["north"] → "north"
    final timestamp = DateTime.now();

    try {
      
      const androidDetails = AndroidNotificationDetails(
        'thunder_cloud_channel',
        '入道雲通知',//ユーザに表示
        channelDescription: '入道雲が出現した時の通知',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        autoCancel: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'thunder_cloud_category',
        subtitle: '天気アラート',
        threadIdentifier: 'thunder_cloud_thread',
      );

      //各プラットフォームの通知設定を統合管理
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      //通知を送信
      await _notifications.show(
        timestamp.millisecondsSinceEpoch ~/ 1000, // ユニークなID
        '⛈️ 入道雲を発見！',
        '$directionsText方向に入道雲が出現しています',
        details,
        payload: 'thunder_cloud:$directionsText',
      );

      log("通知送信完了: $directionsText");
    } catch (e) {
      log("通知送信エラー: $e");
    }
  }

  /// テスト通知
  static Future<void> showTestNotification() async {
    log("テスト通知を送信中...");
    await showThunderCloudNotification(['北', '東']);
  }

  /// 即座にテスト通知を表示
  static Future<void> showImmediateTestNotification() async {
    try {
      log("即座テスト通知を送信中...");
      
      // 権限状態をチェック
      await checkPermissionStatus();

      await _notifications.show(
        999,
        '🧪 テスト通知',
        'ローカル通知が正常に動作しています',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'thunder_cloud_channel',
            '入道雲通知',
            channelDescription: 'テスト用通知',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            subtitle: 'テスト通知',
            threadIdentifier: 'test_thread',
          ),
        ),
      );
      log("即座テスト通知送信完了");
    } catch (e) {
      log("即座テスト通知エラー: $e");
    }
  }

  /// iOS専用：権限を再度リクエスト
  static Future<void> requestiOSPermissionsAgain() async {
    if (Platform.isIOS) {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        log("iOS権限を再リクエスト中...");
        final result = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        log("iOS権限再リクエスト結果: $result");
      }
    }
  }
  
}
