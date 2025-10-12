import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../utils/logger.dart';
//import 'fcm_token_manager.dart';

/// ローカル通知管理サービスクラス
class NotificationService {

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Firebase Messagingインスタンス。プッシュ通知の受信と管理に使用
  //final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Flutter Local Notificationsインスタンス。ローカル通知の表示と管理に使用
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // 通知サービスの初期化
  // チャンネル設定、ハンドラー登録を実行
  // Returns: 初期化の成功/失敗
  Future<bool> initialize() async {
    AppLogger.info('ローカル通知サービス初期化開始', tag: 'NotificationService');

    try {

      // ローカル通知の初期化
      await _initializeLocalNotifications();

      AppLogger.success('通知サービス初期化完了', tag: 'NotificationService');
      return true;
    } catch (e) {
      AppLogger.error('ローカル通知サービス初期化エラー', error: e, tag: 'NotificationService');
      return false;
    }
  }

  /// ローカル通知の初期化をするメソッド
  Future<void> _initializeLocalNotifications() async {
    try {
      // Android設定の初期化
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS設定の初期化
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      // プラットフォームごとの初期化設定を統合
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // プラグインの初期化(通知を表示する準備ができた！とOSに伝えている)
      await _localNotifications.initialize(initSettings);

      // 通知チャンネルの作成
      await _createNotificationChannels();

      AppLogger.info('ローカル通知初期化完了', tag: 'NotificationService');
    } catch (e) {
      AppLogger.error('ローカル通知初期化エラー', error: e, tag: 'NotificationService');
      rethrow;
    }
  }

  /// Android8.0以降で必須の通知チャンネルの作成
  /// ユーザがこの種類の通知だけON/OFFのような細かい設定が可能
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      try {
        //デフォルトチャンネルの作成
        const defaultChannel = AndroidNotificationChannel(
          'thunder_cloud_channel',
          '入道雲通知',
          description: '入道雲が出現した時の通知',
          importance: Importance.high,//重要度(高)
        );

        //チャンネルの登録
        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(defaultChannel);

        AppLogger.info('通知チャンネル作成完了', tag: 'NotificationService');
      } catch (e) {
        AppLogger.error('通知チャンネル作成エラー', error: e, tag: 'NotificationService');
      }
    }
  }



  /// ローカル通知用の公開API
  /// 引数(通知のタイトル,通知の本文,)
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final instance = NotificationService();
    await instance._showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,//通知を上書きしないように一意のIDを生成
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// ローカル通知のロジック部分
  /// showLocalNotificationと分けることで、責任の分離やテストがしやすくなる
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      //Android通知詳細の設定
      const androidDetails = AndroidNotificationDetails(
        'thunder_cloud_channel',                    //チャンネルID
        '入道雲通知',                                 //チャンネル名
        channelDescription: '入道雲が出現した時の通知', //チャンネル説明
        importance: Importance.high,                //通知の優先度
        priority: Priority.high,                     //通知の優先度
        showWhen: true,                              //通知時刻を表示
      );

      //iOS通知詳細の設定
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,//通知バナーを表示
        presentBadge: true,//アプリアイコンにバッジを表示
        presentSound: true,//通知音を鳴らす
      );

      //通知詳細の統合
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      //実際に通知を表示
      await _localNotifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      AppLogger.info('ローカル通知表示成功: $title', tag: 'NotificationService');
    } catch (e) {
      AppLogger.error('ローカル通知表示エラー', error: e, tag: 'NotificationService');
    }
  }
}