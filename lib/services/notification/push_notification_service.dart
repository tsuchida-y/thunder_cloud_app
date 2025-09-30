// lib/services/push_notification_service.dart - リファクタリング版
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../utils/logger.dart';
import 'fcm_token_manager.dart';

/// プッシュ通知専用サービスクラス
/// FCMメッセージ処理とユーザー位置情報管理を担当
/// 入道雲検出時の通知処理とFirestore連携を提供
class PushNotificationService {

  // Firebaseインスタンス
  static FirebaseMessaging? _messaging;
  static FirebaseFirestore? _firestore;

  /// UI更新用のコールバック関数
  /// 入道雲検出時にUIを更新するためのコールバック
  static Function(List<String>)? onThunderCloudDetected;

  /// サービスが初期化されているかどうか(外部からは読み取り専用)
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;


  /// プッシュ通知サービスの初期化
  /// FCM権限取得、トークン管理、メッセージハンドラー設定を実行
  static Future<void> initialize() async {
    // 重複初期化を防ぐ
    if (_isInitialized) {
      AppLogger.info('プッシュ通知サービスは既に初期化済みです', tag: 'PushNotificationService');
      return;
    }

    AppLogger.info('プッシュ通知サービス初期化開始', tag: 'PushNotificationService');

    try {
      //Firebaseインスタンスの初期化
      _messaging = FirebaseMessaging.instance;
      _firestore = FirebaseFirestore.instance;

      AppLogger.info('ローカル通知権限は初期化時に処理済み', tag: 'PushNotificationService');

      //FCM通知権限の要求
      final settings = await _requestFCMPermission();

      //権限に基づく処理の分岐
      if (_isPermissionGranted(settings.authorizationStatus)) {
        await _initializeWithPermission();
      } else {
        AppLogger.warning('通知権限が拒否されました: ${settings.authorizationStatus}', tag: 'PushNotificationService');
        await _initializeWithoutPermission();
      }

      // 初期化完了をマーク
      _isInitialized = true;
    } catch (e) {
      AppLogger.error('プッシュ通知サービス初期化エラー', error: e, tag: 'PushNotificationService');
    }
  }

  /// FCM通知権限を要求
  /// ユーザーにFCM通知の許可を求める
  /// 権限状態を確認し、拒否された場合は再試行する
  static Future<NotificationSettings> _requestFCMPermission() async {
    try {
      // 現在の権限状態をネイティブに確認
      final currentSettings = await _messaging!.getNotificationSettings();
      AppLogger.info('現在の通知権限状態: ${currentSettings.authorizationStatus}', tag: 'PushNotificationService');

      //既に許可されている場合はそのまま返す
      if (currentSettings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.info('通知権限は既に許可されています', tag: 'PushNotificationService');
        return currentSettings;
      }

      //権限を要求
      //通知権限ダイアログを表示して、ユーザーの応答を待つ
      AppLogger.info('通知権限を要求中...', tag: 'PushNotificationService');
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      //権限の結果を確認
      final isGranted = settings.authorizationStatus == AuthorizationStatus.authorized;
      AppLogger.info('通知権限要求結果: ${isGranted ? '許可' : '拒否'}', tag: 'PushNotificationService');

      //権限が拒否された場合の再試行
      if (!isGranted) {
        AppLogger.warning('通知権限が拒否されました。5秒後に再試行します', tag: 'PushNotificationService');
        await Future.delayed(const Duration(seconds: 5));

        //再試行
        AppLogger.info('通知権限の再要求中...', tag: 'PushNotificationService');
        final retryPermission = await _messaging!.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          announcement: false,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
        );

        final retryGranted = retryPermission.authorizationStatus == AuthorizationStatus.authorized;
        AppLogger.info('通知権限再要求結果: ${retryGranted ? '許可' : '拒否'}', tag: 'PushNotificationService');

        return retryPermission;
      }

      return settings;
    } catch (e) {
      AppLogger.error('FCM通知権限要求エラー', error: e, tag: 'PushNotificationService');
      rethrow;
    }
  }

  /// 権限が許可されているかどうかを判定
  /// 許可または暫定許可の場合にtrueを返す
  static bool _isPermissionGranted(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
           status == AuthorizationStatus.provisional;
  }

  /// 権限ありでの初期化
  /// 完全な通知機能を有効化
  static Future<void> _initializeWithPermission() async {
    try {
      //FCMトークンの取得
      final token = await FCMTokenManager.getToken();

      if (token != null) {
        AppLogger.info('FCMトークン取得成功: ${token.substring(0, 20)}...', tag: 'PushNotificationService');

        //メッセージハンドラーの設定
        _setupMessageHandlers();

        AppLogger.success('プッシュ通知サービス初期化完了', tag: 'PushNotificationService');
      } else {
        AppLogger.error('FCMトークン取得に失敗しました', tag: 'PushNotificationService');
      }
    } catch (e) {
      AppLogger.error('権限あり初期化エラー', error: e, tag: 'PushNotificationService');
    }
  }

  /// 権限なしでの初期化
  /// 基本機能のみを有効化
  static Future<void> _initializeWithoutPermission() async {
    try {
      // ステップ1: FCMトークンの取得（権限なしでも可能）
      final token = await FCMTokenManager.getToken();

      if (token != null) {
        // ステップ2: メッセージハンドラーの設定
        _setupMessageHandlers();
        AppLogger.info('権限なしでも基本機能を初期化しました', tag: 'PushNotificationService');
      }
    } catch (e) {
      AppLogger.error('権限なし初期化エラー', error: e, tag: 'PushNotificationService');
    }
  }

  /// メッセージハンドラーの設定
  /// フォアグラウンド・バックグラウンド・初期メッセージの処理を設定
  static void _setupMessageHandlers() {
    try {
      //フォアグラウンドでのメッセージ受信を監視
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      //通知タップでアプリが開かれた時の処理
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      //アプリが停止している状態に通知から開かれたかチェック
      _checkInitialMessage();

      AppLogger.info('メッセージハンドラー設定完了', tag: 'PushNotificationService');
    } catch (e) {
      AppLogger.error('メッセージハンドラー設定エラー', error: e, tag: 'PushNotificationService');
    }
  }

  /// 初期メッセージのチェック
  /// アプリ起動時に通知から開かれた場合の処理
  static void _checkInitialMessage() async {
    try {
      // 初期メッセージの取得
      RemoteMessage? initialMessage = await _messaging!.getInitialMessage();

      if (initialMessage != null) {
        // 初期メッセージの処理
        _handleNotificationTap(initialMessage);
        AppLogger.info('初期メッセージ処理完了', tag: 'PushNotificationService');
      }
    } catch (e) {
      AppLogger.error('初期メッセージチェックエラー', error: e, tag: 'PushNotificationService');
    }
  }

  /// アプリ使用中に通知を受信した時の処理
  static void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info('フォアグラウンドメッセージ受信: ${message.notification?.title}', tag: 'PushNotificationService');

    try {
      //メッセージタイプの確認
      if (message.data['type'] == 'thunder_cloud') {
        // ステップ2: 方向データの抽出
        final directionsData = message.data['directions'] ?? '';
        final directions = directionsData.isNotEmpty ? directionsData.split(',') : <String>[];

        AppLogger.info('入道雲通知受信: $directions', tag: 'PushNotificationService');

        // ステップ3: UI更新のためのコールバックを呼び出し
        if (onThunderCloudDetected != null) {
          onThunderCloudDetected!(directions);
        }
      }
    } catch (e) {
      AppLogger.error('フォアグラウンドメッセージ処理エラー', error: e, tag: 'PushNotificationService');
    }
  }

  /// 通知がタップされた時の処理
  static void _handleNotificationTap(RemoteMessage message) {
    AppLogger.info('通知がタップされました: ${message.data}', tag: 'PushNotificationService');

    try {
      // メッセージタイプの確認
      if (message.data['type'] == 'thunder_cloud') {
        AppLogger.info('入道雲通知タップ - 詳細画面へ遷移予定', tag: 'PushNotificationService');
        // TODO: 入道雲画面への遷移処理を実装
      }
    } catch (e) {
      AppLogger.error('通知タップ処理エラー', error: e, tag: 'PushNotificationService');
    }
  }

  /// ユーザー位置情報をFirestoreに保存
  /// FCMトークンをドキュメントIDとして使用、座標は小数点2位に丸める（プライバシー保護）
  static Future<void> saveUserLocation(double latitude, double longitude) async {
    try {
      // FCMトークンを取得
      final fcmToken = FCMTokenManager.currentToken;
      if (fcmToken == null) {
        AppLogger.error('FCMトークンが取得できません', tag: 'PushNotificationService');
        return;
      }

      // 座標を小数点2位に丸める（プライバシー保護）
      final roundedLatitude = double.parse(latitude.toStringAsFixed(2));
      final roundedLongitude = double.parse(longitude.toStringAsFixed(2));

      AppLogger.info('ユーザー位置情報保存開始: 緯度=$latitude → $roundedLatitude, 経度=$longitude → $roundedLongitude', tag: 'PushNotificationService');

      // Firestoreに保存するためのデータ構造を作成
      final userData = {
        'fcmToken': fcmToken,
        'latitude': roundedLatitude,
        'longitude': roundedLongitude,
        'lastUpdated': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      //TODO:FCMトークンは一時的なものだから、ドキュメントIDとしては適切か検討する必要あり
      await _firestore!.collection('users').doc(fcmToken).set(
        userData,
        SetOptions(merge: true),
      );

      AppLogger.success('ユーザー位置情報保存完了（FCMトークン付き）: (${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})', tag: 'PushNotificationService');
      AppLogger.info('ドキュメントID: users/${fcmToken.substring(0, 20)}...', tag: 'PushNotificationService');

      // 保存確認のためにデータを読み取り
      await _verifySavedData(fcmToken);
    } catch (e) {
      AppLogger.error('ユーザー位置情報保存エラー', error: e, tag: 'PushNotificationService');
    }
  }


  /// Firestoreに正しく保存されたかを確認
  /// 保存されているデータを読み取り、ログに出力
  static Future<void> _verifySavedData(String fcmToken) async {
    try {
      // ドキュメントの取得
      final doc = await _firestore!.collection('users').doc(fcmToken).get();

      if (doc.exists) {
        // データの確認
        final data = doc.data();
        AppLogger.success('Firestore保存確認成功:', tag: 'PushNotificationService');
        AppLogger.info('FCMトークン: ${data?['fcmToken']?.substring(0, 20)}...', tag: 'PushNotificationService');
        AppLogger.info('緯度: ${data?['latitude']}', tag: 'PushNotificationService');
        AppLogger.info('経度: ${data?['longitude']}', tag: 'PushNotificationService');
        AppLogger.info('最終更新: ${data?['lastUpdated']}', tag: 'PushNotificationService');
        AppLogger.info('アクティブ状態: ${data?['isActive']}', tag: 'PushNotificationService');
        AppLogger.info('ドキュメントID: users/${fcmToken.substring(0, 20)}...', tag: 'PushNotificationService');
      } else {
        AppLogger.error('保存確認失敗: ドキュメントが見つかりません', tag: 'PushNotificationService');
      }
    } catch (readError) {
      AppLogger.error('保存確認エラー: $readError', tag: 'PushNotificationService');
    }
  }

  /// ユーザーのアクティブ状態を更新
  /// アプリの使用状態をFirestoreに反映
  ///
  /// [isActive] アクティブ状態
  static Future<void> updateUserActiveStatus(bool isActive) async {
    try {
      // ステップ1: FCMトークンの取得
      final fcmToken = FCMTokenManager.currentToken;
      if (fcmToken == null) {
        AppLogger.warning('FCMトークンが取得できません', tag: 'PushNotificationService');
        return;
      }

      // ステップ2: アクティブ状態の更新
      await _firestore!.collection('users').doc(fcmToken).update({
        'isActive': isActive,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      AppLogger.info('ユーザーアクティブ状態更新: $isActive', tag: 'PushNotificationService');
    } catch (e) {
      AppLogger.error('アクティブ状態更新エラー', error: e, tag: 'PushNotificationService');
    }
  }

  /*
  ================================================================================
                                プロパティアクセス
                        外部からの状態取得とトークン管理
  ================================================================================
  */

  /// FCMトークンを取得（マネージャーを経由）
  /// 現在のFCMトークンを取得
  static String? get fcmToken => FCMTokenManager.currentToken;

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