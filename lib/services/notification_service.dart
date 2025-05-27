import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'dart:developer';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  /// 通知の初期化
  static Future<void> initialize() async {
    log("通知サービスを初期化中...");
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
    await _createNotificationChannel();
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
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// 権限のリクエスト
  static Future<bool> requestPermissions() async {
    // Android 13+ の通知権限リクエスト
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    final result = await androidPlugin?.requestNotificationsPermission();
    
    // iOS の通知権限リクエスト
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    
    log("通知権限リクエスト結果: $result");
    return result ?? false;
  }

  /// 入道雲出現通知
  static Future<void> showThunderCloudNotification(List<String> directions) async {
    if (directions.isEmpty) return;

    final directionsText = directions.join('、');
    final timestamp = DateTime.now();
    
    const androidDetails = AndroidNotificationDetails(
      'thunder_cloud_channel',
      '入道雲通知',
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
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      timestamp.millisecondsSinceEpoch ~/ 1000, // ユニークなID
      '⛈️ 入道雲を発見！',
      '$directionsText方向に入道雲が出現しています',
      details,
      payload: 'thunder_cloud:$directionsText',
    );
    
    log("通知送信完了: $directionsText");
  }

  /// テスト通知
  static Future<void> showTestNotification() async {
    await showThunderCloudNotification(['北', '東']);
  }
}