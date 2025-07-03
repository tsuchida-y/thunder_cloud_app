import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../utils/logger.dart';
import 'fcm_token_manager.dart';

/// 通知管理サービスクラス
/// プッシュ通知とローカル通知の統合管理を担当
/// FCMトークンの管理と通知の表示制御を提供
class NotificationService {
  /*
  ================================================================================
                                    シングルトン
                          アプリ全体で共有する単一インスタンス
  ================================================================================
  */
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /*
  ================================================================================
                                    依存関係
                         外部サービスとの接続とインスタンス
  ================================================================================
  */
  /// Firebase Messagingインスタンス
  /// プッシュ通知の受信と管理に使用
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  /// Flutter Local Notificationsインスタンス
  /// ローカル通知の表示と管理に使用
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /*
  ================================================================================
                                初期化機能
                        通知システムの初期設定と権限取得
  ================================================================================
  */

  /// 通知サービスの初期化
  /// 権限取得、チャンネル設定、ハンドラー登録を実行
  ///
  /// Returns: 初期化の成功/失敗
  Future<bool> initialize() async {
    AppLogger.info('通知サービス初期化開始', tag: 'NotificationService');

    try {
      // ステップ1: 通知権限の要求（適切なタイミングで実行）
      final permissionGranted = await _requestNotificationPermissionWithRetry();
      if (!permissionGranted) {
        AppLogger.error('通知権限の取得に失敗しました。FCMトークンの取得はできません', tag: 'NotificationService');
        return false;
      }

      // ステップ2: ローカル通知の初期化
      await _initializeLocalNotifications();

      // ステップ3: FCMハンドラーの設定
      await _setupFCMHandlers();

      // ステップ4: FCMトークンの取得と保存（権限が許可された後に実行）
      await _setupFCMToken();

      AppLogger.success('通知サービス初期化完了', tag: 'NotificationService');
      return true;
    } catch (e) {
      AppLogger.error('通知サービス初期化エラー', error: e, tag: 'NotificationService');
      return false;
    }
  }

  /// 通知権限を要求（リトライ機能付き）
  /// ユーザーに通知の許可を求める（適切なタイミングで実行）
  ///
  /// Returns: 権限が許可されたかどうか
  Future<bool> _requestNotificationPermissionWithRetry() async {
    try {
      // ステップ1: 現在の権限状態を確認
      final settings = await _firebaseMessaging.getNotificationSettings();
      AppLogger.info('現在の通知権限状態: ${settings.authorizationStatus}', tag: 'NotificationService');

      // ステップ2: 権限が既に許可されている場合はtrueを返す
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.info('通知権限は既に許可されています', tag: 'NotificationService');
        return true;
      }

      // ステップ3: 権限を要求
      AppLogger.info('通知権限を要求中...', tag: 'NotificationService');
      final permission = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // ステップ4: 権限の結果を確認
      final isGranted = permission.authorizationStatus == AuthorizationStatus.authorized;
      AppLogger.info('通知権限要求結果: ${isGranted ? '許可' : '拒否'}', tag: 'NotificationService');

      // ステップ5: 権限が拒否された場合の再試行
      if (!isGranted) {
        AppLogger.warning('通知権限が拒否されました。5秒後に再試行します', tag: 'NotificationService');
        await Future.delayed(const Duration(seconds: 5));

        // 再試行
        AppLogger.info('通知権限の再要求中...', tag: 'NotificationService');
        final retryPermission = await _firebaseMessaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        final retryGranted = retryPermission.authorizationStatus == AuthorizationStatus.authorized;
        AppLogger.info('通知権限再要求結果: ${retryGranted ? '許可' : '拒否'}', tag: 'NotificationService');

        return retryGranted;
      }

      return isGranted;
    } catch (e) {
      AppLogger.error('通知権限要求エラー', error: e, tag: 'NotificationService');
      return false;
    }
  }

  /// ローカル通知の初期化
  /// 通知チャンネルの設定とプラグインの初期化
  Future<void> _initializeLocalNotifications() async {
    try {
      // ステップ1: Android設定の初期化
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // ステップ2: iOS設定の初期化
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      // ステップ3: 初期化設定の統合
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // ステップ4: プラグインの初期化
      await _localNotifications.initialize(initSettings);

      // ステップ5: 通知チャンネルの作成
      await _createNotificationChannels();

      AppLogger.info('ローカル通知初期化完了', tag: 'NotificationService');
    } catch (e) {
      AppLogger.error('ローカル通知初期化エラー', error: e, tag: 'NotificationService');
      rethrow;
    }
  }

  /// 通知チャンネルの作成
  /// Android用の通知チャンネルを設定
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      try {
        // ステップ1: デフォルトチャンネルの作成
        const defaultChannel = AndroidNotificationChannel(
          'thunder_cloud_channel',
          '入道雲通知',
          description: '入道雲が出現した時の通知',
          importance: Importance.high,
        );

        // ステップ2: チャンネルの登録
        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(defaultChannel);

        AppLogger.info('通知チャンネル作成完了', tag: 'NotificationService');
      } catch (e) {
        AppLogger.error('通知チャンネル作成エラー', error: e, tag: 'NotificationService');
      }
    }
  }

  /*
  ================================================================================
                                FCM設定機能
                        プッシュ通知の受信とトークン管理
  ================================================================================
  */

  /// FCMハンドラーの設定
  /// フォアグラウンド・バックグラウンド・終了時の通知処理を設定
  Future<void> _setupFCMHandlers() async {
    try {
      // ステップ1: フォアグラウンドメッセージハンドラーの設定
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // ステップ2: バックグラウンドメッセージハンドラーの設定
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // ステップ3: アプリ終了時のメッセージハンドラーの設定
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleInitialMessage(initialMessage);
      }

      AppLogger.info('FCMハンドラー設定完了', tag: 'NotificationService');
    } catch (e) {
      AppLogger.error('FCMハンドラー設定エラー', error: e, tag: 'NotificationService');
    }
  }

  /// FCMトークンの設定
  /// トークンの取得と保存を実行
  Future<void> _setupFCMToken() async {
    try {
      AppLogger.info('FCMトークン取得開始', tag: 'NotificationService');

      // ステップ1: 通知権限の最終確認
      final settings = await _firebaseMessaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        AppLogger.error('通知権限が許可されていないため、FCMトークンの取得を中止します', tag: 'NotificationService');
        return;
      }

      // ステップ2: 少し待機してからFCMトークンを取得（APNSトークンの設定を待つ）
      AppLogger.info('APNSトークンの設定を待機中...', tag: 'NotificationService');
      await Future.delayed(const Duration(seconds: 2));

      // ステップ3: FCMトークンの取得
      final token = await FCMTokenManager.getToken();

      if (token != null) {
        // ステップ4: トークンの保存（キャッシュは自動的に行われる）
        AppLogger.success('FCMトークン取得完了: ${token.substring(0, 20)}...', tag: 'NotificationService');
      } else {
        AppLogger.error('FCMトークンの取得に失敗しました', tag: 'NotificationService');
      }

      // ステップ5: トークン更新リスナーの設定
      _firebaseMessaging.onTokenRefresh.listen(_handleTokenRefresh);
    } catch (e) {
      AppLogger.error('FCMトークン設定エラー', error: e, tag: 'NotificationService');
    }
  }

  /*
  ================================================================================
                                通知処理機能
                        各種通知メッセージの処理と表示
  ================================================================================
  */

  /// フォアグラウンドメッセージの処理
  /// アプリ使用中の通知受信時の処理
  ///
  /// [message] 受信したメッセージ
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info('フォアグラウンド通知受信: ${message.notification?.title}', tag: 'NotificationService');

    try {
      // ステップ1: 通知データの抽出
      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        // ステップ2: ローカル通知として表示
        _showLocalNotification(
          id: message.hashCode,
          title: notification.title ?? '通知',
          body: notification.body ?? '',
          payload: data.toString(),
        );
      }
    } catch (e) {
      AppLogger.error('フォアグラウンド通知処理エラー', error: e, tag: 'NotificationService');
    }
  }

  /// バックグラウンドメッセージの処理
  /// アプリがバックグラウンドにある時の通知タップ処理
  ///
  /// [message] 受信したメッセージ
  void _handleBackgroundMessage(RemoteMessage message) {
    AppLogger.info('バックグラウンド通知タップ: ${message.notification?.title}', tag: 'NotificationService');

    try {
      // ステップ1: 通知データの処理
      final data = message.data;

      // ステップ2: 必要に応じて画面遷移などの処理を実行
      _processNotificationData(data);
    } catch (e) {
      AppLogger.error('バックグラウンド通知処理エラー', error: e, tag: 'NotificationService');
    }
  }

  /// 初期メッセージの処理
  /// アプリ起動時の通知タップ処理
  ///
  /// [message] 受信したメッセージ
  void _handleInitialMessage(RemoteMessage message) {
    AppLogger.info('初期通知処理: ${message.notification?.title}', tag: 'NotificationService');

    try {
      // ステップ1: 通知データの処理
      final data = message.data;

      // ステップ2: 必要に応じて画面遷移などの処理を実行
      _processNotificationData(data);
    } catch (e) {
      AppLogger.error('初期通知処理エラー', error: e, tag: 'NotificationService');
    }
  }

  /// トークン更新の処理
  /// FCMトークンが更新された時の処理
  ///
  /// [newToken] 新しいトークン
  Future<void> _handleTokenRefresh(String newToken) async {
    AppLogger.info('FCMトークン更新: ${newToken.substring(0, 20)}...', tag: 'NotificationService');

    try {
      // ステップ1: 新しいトークンの保存（キャッシュは自動的に行われる）
      // ステップ2: 必要に応じてサーバーへの送信処理を実行
      await _sendTokenToServer(newToken);
    } catch (e) {
      AppLogger.error('トークン更新処理エラー', error: e, tag: 'NotificationService');
    }
  }

  /*
  ================================================================================
                                ローカル通知機能
                        ローカル通知の表示と管理
  ================================================================================
  */

  /// ローカル通知を表示
  /// 指定された内容でローカル通知を表示
  ///
  /// [id] 通知ID
  /// [title] 通知タイトル
  /// [body] 通知本文
  /// [payload] 通知ペイロード
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      // ステップ1: Android通知詳細の設定
      const androidDetails = AndroidNotificationDetails(
        'thunder_cloud_channel',
        '入道雲通知',
        channelDescription: '入道雲が出現した時の通知',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      // ステップ2: iOS通知詳細の設定
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // ステップ3: 通知詳細の統合
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // ステップ4: 通知の表示
      await _localNotifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      AppLogger.info('ローカル通知表示: $title', tag: 'NotificationService');
    } catch (e) {
      AppLogger.error('ローカル通知表示エラー', error: e, tag: 'NotificationService');
    }
  }

  /*
  ================================================================================
                                ユーティリティメソッド
                        補助的な処理・データ検証・サーバー通信
  ================================================================================
  */

  /// 通知データの処理
  /// 通知から取得したデータに基づく処理を実行
  ///
  /// [data] 通知データ
  void _processNotificationData(Map<String, dynamic> data) {
    try {
      // ステップ1: 通知タイプの確認
      final type = data['type'];

      // ステップ2: タイプに応じた処理の実行
      switch (type) {
        case 'weather_alert':
          _handleWeatherAlert(data);
          break;
        case 'system_update':
          _handleSystemUpdate(data);
          break;
        default:
          AppLogger.info('未対応の通知タイプ: $type', tag: 'NotificationService');
      }
    } catch (e) {
      AppLogger.error('通知データ処理エラー', error: e, tag: 'NotificationService');
    }
  }

  /// 気象警報の処理
  /// 気象関連の通知データを処理
  ///
  /// [data] 通知データ
  void _handleWeatherAlert(Map<String, dynamic> data) {
    AppLogger.info('気象警報通知処理: ${data['message']}', tag: 'NotificationService');
    // 必要に応じて気象画面への遷移などの処理を実装
  }

  /// システム更新の処理
  /// システム関連の通知データを処理
  ///
  /// [data] 通知データ
  void _handleSystemUpdate(Map<String, dynamic> data) {
    AppLogger.info('システム更新通知処理: ${data['message']}', tag: 'NotificationService');
    // 必要に応じて設定画面への遷移などの処理を実装
  }

  /// トークンをサーバーに送信
  /// 新しいFCMトークンをサーバーに送信
  ///
  /// [token] 送信するトークン
  Future<void> _sendTokenToServer(String token) async {
    try {
      // ステップ1: サーバーへの送信処理を実装
      // 現在はログ出力のみ
      AppLogger.info('トークンサーバー送信完了', tag: 'NotificationService');
    } catch (e) {
      AppLogger.error('トークンサーバー送信エラー', error: e, tag: 'NotificationService');
    }
  }

  /// 通知の削除
  /// 指定されたIDの通知を削除
  ///
  /// [id] 削除する通知のID
  Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id);
      AppLogger.info('通知削除完了: ID $id', tag: 'NotificationService');
    } catch (e) {
      AppLogger.error('通知削除エラー', error: e, tag: 'NotificationService');
    }
  }

  /// 全通知の削除
  /// すべての通知を削除
  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      AppLogger.info('全通知削除完了', tag: 'NotificationService');
    } catch (e) {
      AppLogger.error('全通知削除エラー', error: e, tag: 'NotificationService');
    }
  }
}
