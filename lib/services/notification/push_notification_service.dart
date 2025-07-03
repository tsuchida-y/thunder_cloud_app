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
  /*
  ================================================================================
                                    シングルトン
                          アプリ全体で共有する単一インスタンス
  ================================================================================
  */
  static FirebaseMessaging? _messaging;
  static FirebaseFirestore? _firestore;

  /*
  ================================================================================
                                    状態管理
                          サービス状態とコールバック管理
  ================================================================================
  */
  /// UI更新用のコールバック関数
  /// 入道雲検出時にUIを更新するためのコールバック
  static Function(List<String>)? onThunderCloudDetected;

  /// サービスが初期化されているかどうか
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /*
  ================================================================================
                                初期化機能
                        FCMサービスとFirestore接続の初期化
  ================================================================================
  */

  /// プッシュ通知サービスの初期化
  /// FCM権限取得、トークン管理、メッセージハンドラー設定を実行
  ///
  /// Returns: 初期化の成功/失敗
  static Future<void> initialize() async {
    // 重複初期化を防ぐ
    if (_isInitialized) {
      AppLogger.info('プッシュ通知サービスは既に初期化済みです', tag: 'PushNotificationService');
      return;
    }

    AppLogger.info('プッシュ通知サービス初期化開始', tag: 'PushNotificationService');

    try {
      // ステップ1: Firebaseインスタンスの初期化
      _messaging = FirebaseMessaging.instance;
      _firestore = FirebaseFirestore.instance;

      AppLogger.info('ローカル通知権限は初期化時に処理済み', tag: 'PushNotificationService');

      // ステップ2: FCM通知権限の要求
      final settings = await _requestFCMPermission();

      // ステップ3: 権限に基づく処理の分岐
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
  ///
  /// Returns: 通知設定情報
  static Future<NotificationSettings> _requestFCMPermission() async {
    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      AppLogger.info('FCM通知権限状態: ${settings.authorizationStatus}', tag: 'PushNotificationService');
      return settings;
    } catch (e) {
      AppLogger.error('FCM通知権限要求エラー', error: e, tag: 'PushNotificationService');
      rethrow;
    }
  }

  /// 権限が許可されているかどうかを判定
  /// 許可または暫定許可の場合にtrueを返す
  ///
  /// [status] 権限状態
  /// Returns: 権限が許可されているかどうか
  static bool _isPermissionGranted(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
           status == AuthorizationStatus.provisional;
  }

  /// 権限ありでの初期化
  /// 完全な通知機能を有効化
  static Future<void> _initializeWithPermission() async {
    try {
      // ステップ1: FCMトークンの取得
      final token = await FCMTokenManager.getToken();

      if (token != null) {
        AppLogger.info('FCMトークン取得成功: ${token.substring(0, 20)}...', tag: 'PushNotificationService');

        // ステップ2: メッセージハンドラーの設定
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

  /*
  ================================================================================
                                メッセージ処理機能
                        FCMメッセージの受信とハンドリング
  ================================================================================
  */

  /// メッセージハンドラーの設定
  /// フォアグラウンド・バックグラウンド・初期メッセージの処理を設定
  static void _setupMessageHandlers() {
    try {
      // ステップ1: フォアグラウンドでのメッセージ受信を監視
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // ステップ2: 通知タップでアプリが開かれた時の処理
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // ステップ3: アプリ起動時に通知から開かれたかチェック
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
      // ステップ1: 初期メッセージの取得
      RemoteMessage? initialMessage = await _messaging!.getInitialMessage();

      if (initialMessage != null) {
        // ステップ2: 初期メッセージの処理
        _handleNotificationTap(initialMessage);
        AppLogger.info('初期メッセージ処理完了', tag: 'PushNotificationService');
      }
    } catch (e) {
      AppLogger.error('初期メッセージチェックエラー', error: e, tag: 'PushNotificationService');
    }
  }

  /// フォアグラウンドでメッセージを受信した時の処理
  /// アプリ使用中の通知受信時の処理
  ///
  /// [message] 受信したメッセージ
  static void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info('フォアグラウンドメッセージ受信: ${message.notification?.title}', tag: 'PushNotificationService');

    try {
      // ステップ1: メッセージタイプの確認
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

  /// 通知タップ時の処理
  /// 通知がタップされた時の処理
  ///
  /// [message] 受信したメッセージ
  static void _handleNotificationTap(RemoteMessage message) {
    AppLogger.info('通知がタップされました: ${message.data}', tag: 'PushNotificationService');

    try {
      // ステップ1: メッセージタイプの確認
      if (message.data['type'] == 'thunder_cloud') {
        AppLogger.info('入道雲通知タップ - 詳細画面へ遷移予定', tag: 'PushNotificationService');
        // TODO: 詳細画面への遷移処理を実装
      }
    } catch (e) {
      AppLogger.error('通知タップ処理エラー', error: e, tag: 'PushNotificationService');
    }
  }

  /*
  ================================================================================
                                位置情報管理機能
                        ユーザー位置情報のFirestore保存と更新
  ================================================================================
  */

  /// ユーザー位置情報をFirestoreに保存
  /// FCMトークンをドキュメントIDとして使用、座標は小数点2位に丸める（プライバシー保護）
  ///
  /// [latitude] 緯度
  /// [longitude] 経度
  static Future<void> saveUserLocation(double latitude, double longitude) async {
    try {
      // ステップ1: FCMトークンを取得
      final fcmToken = FCMTokenManager.currentToken;
      if (fcmToken == null) {
        AppLogger.error('FCMトークンが取得できません', tag: 'PushNotificationService');
        return;
      }

      // ステップ2: 座標を小数点2位に丸める（プライバシー保護）
      final roundedLatitude = double.parse(latitude.toStringAsFixed(2));
      final roundedLongitude = double.parse(longitude.toStringAsFixed(2));

      AppLogger.info('ユーザー位置情報保存開始: 緯度=$latitude → $roundedLatitude, 経度=$longitude → $roundedLongitude', tag: 'PushNotificationService');

      // ステップ3: 統合構造のユーザーデータを作成
      // 既存のプロフィール情報を保持しながら位置情報を更新
      final userData = {
        'fcmToken': fcmToken,
        'latitude': roundedLatitude,
        'longitude': roundedLongitude,
        'lastUpdated': FieldValue.serverTimestamp(),
        'isActive': true,
        'appVersion': '1.0.0',
        'platform': 'flutter',
      };

      // ステップ4: FCMトークンをドキュメントIDとして使用
      await _firestore!.collection('users').doc(fcmToken).set(
        userData,
        SetOptions(merge: true),
      );

      AppLogger.success('ユーザー位置情報保存完了（FCMトークン付き）: (${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})', tag: 'PushNotificationService');
      AppLogger.info('ドキュメントID: users/${fcmToken.substring(0, 20)}...', tag: 'PushNotificationService');

      // ステップ5: 保存確認のためにデータを読み取り
      await _verifySavedData(fcmToken);
    } catch (e) {
      AppLogger.error('ユーザー位置情報保存エラー', error: e, tag: 'PushNotificationService');
    }
  }

  /// 保存されたデータの確認
  /// Firestoreに正しく保存されたかを確認
  ///
  /// [fcmToken] FCMトークン
  static Future<void> _verifySavedData(String fcmToken) async {
    try {
      // ステップ1: ドキュメントの取得
      final doc = await _firestore!.collection('users').doc(fcmToken).get();

      if (doc.exists) {
        // ステップ2: データの確認
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