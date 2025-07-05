import 'dart:developer' as dev;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// import '../firebase_options.dart'; // ファイルが見つからないためコメントアウト
import '../location/location_service.dart';
import '../notification/notification_service.dart';
import '../notification/push_notification_service.dart';
import '../photo/user_service.dart';
import '../user/user_id_service.dart';

/// アプリケーション全体の初期化を管理するサービス
class AppInitializationService {
  static bool _isInitialized = false;

  /// 初期化状態の確認
  static bool get isInitialized => _isInitialized;

  /// アプリケーションの初期化（Firebase Coreは同期、他はバックグラウンド）
  static Future<void> initializeApp() async {
    if (_isInitialized) {
      dev.log("✅ アプリは既に初期化済みです");
      return;
    }

    try {
      dev.log("🔥 Firebase Core初期化開始");

      // Firebase Core初期化（同期的に実行）
      await _initializeFirebaseCore();

      _isInitialized = true;
      dev.log("✅ Firebase Core初期化完了");

      // 他のサービスはバックグラウンドで初期化
      _initializeBackgroundServices();

    } catch (e) {
      dev.log("❌ 初期化エラー: $e");
      rethrow;
    }
  }

  /// バックグラウンドサービスの初期化
  /// 通知、位置情報、ユーザーIDサービスの並列初期化
  static Future<void> _initializeBackgroundServices() async {
    dev.log("🔄 バックグラウンドサービス初期化開始");

    try {
      // ステップ1: サービス並列初期化
      dev.log("🔔 サービス並列初期化開始");
      await Future.wait([
        _initializeNotificationService(),
        _initializeLocationService(),
        _initializeUserIdService(),
      ]);

      // ステップ2: 初回アクセス時のユーザー作成（FCMトークン取得を待つ）
      dev.log("👤 初回アクセス時のユーザー作成開始");
      final userId = await UserIdService.getUserId();
      dev.log("👤 ユーザーID取得: ${userId.substring(0, 8)}...");

      // FCMトークンの取得を待つ（最大60秒）
      bool userCreated = false;
      for (int i = 0; i < 12; i++) {
        try {
          await UserService.createUserOnFirstAccess(userId);
          userCreated = true;
          dev.log("✅ 初回アクセス時のユーザー作成完了");
          break;
        } catch (e) {
          dev.log("⚠️ 初回アクセス時のユーザー作成失敗 (試行 ${i + 1}/12): $e");
          if (i < 11) {
            dev.log("⏳ 5秒後に再試行します...");
            await Future.delayed(const Duration(seconds: 5));
          }
        }
      }

      if (!userCreated) {
        dev.log("❌ 初回アクセス時のユーザー作成に失敗しました");
      }

      // ステップ3: バックグラウンド位置情報取得
      dev.log("🔄 バックグラウンド位置情報取得開始");
      try {
        final location = await LocationService.getLocationFast(forceRefresh: false);
        if (location != null) {
          dev.log("✅ バックグラウンド位置情報取得成功: $location");

          // 位置情報をFirestoreに保存
          dev.log("📍 アプリ起動時の位置情報をFirestoreに保存開始...");
          await _saveLocationToFirestore(location);
          dev.log("📍 ✅ アプリ起動時の位置情報をFirestoreに自動保存完了");
          dev.log("📍 保存された座標: 緯度=${location.latitude.toStringAsFixed(2)}, 経度=${location.longitude.toStringAsFixed(2)}");
        }
      } catch (e) {
        dev.log("❌ バックグラウンド位置情報取得エラー: $e");
      }

      dev.log("✅ サービス初期化完了");
    } catch (e) {
      dev.log("❌ バックグラウンドサービス初期化エラー: $e");
    }
  }

  /// 位置情報をFirestoreに保存
  static Future<void> _saveLocationToFirestore(LatLng location) async {
    try {
      await PushNotificationService.saveUserLocation(location.latitude, location.longitude);
    } catch (e) {
      dev.log("❌ 位置情報のFirestore保存エラー: $e");
    }
  }

  /// Firebase Coreのみの最小初期化
  static Future<void> _initializeFirebaseCore() async {
    try {
      dev.log("🔥 Firebase Core初期化開始");

      await Firebase.initializeApp(
        //options: DefaultFirebaseOptions.currentPlatform, // 一時的にコメントアウト
      );

      dev.log("✅ Firebase Core初期化完了");
    } catch (e) {
      dev.log("❌ Firebase Core初期化エラー: $e");
      rethrow;
    }
  }

  /// 通知サービスの初期化
  static Future<void> _initializeNotificationService() async {
    try {
      dev.log("🔔 通知サービス初期化開始");
      await NotificationService().initialize();
      dev.log("✅ 通知サービス初期化完了");
    } catch (e) {
      dev.log("❌ 通知サービス初期化エラー: $e");
    }
  }

  /// 位置情報サービスの初期化（一度だけ実行）
  static Future<void> _initializeLocationService() async {
    try {
      dev.log("📍 位置情報サービス初期化開始");

      // 位置情報監視を先に開始（軽量）
      LocationService.startLocationMonitoring();
      dev.log("✅ 位置情報監視開始");

      // 位置情報取得は非同期で実行（UIをブロックしない）
      _getLocationInBackground();

      dev.log("✅ 位置情報サービス初期化完了");

    } catch (e) {
      dev.log("❌ 位置情報サービス初期化エラー: $e");

      // エラーが発生しても監視は開始（後で再取得できるように）
      try {
        LocationService.startLocationMonitoring();
        dev.log("⚠️ 位置情報監視のみ開始");
      } catch (monitoringError) {
        dev.log("❌ 位置情報監視開始エラー: $monitoringError");
      }
    }
  }

  /// バックグラウンドで位置情報を取得
  static void _getLocationInBackground() {
    Future.microtask(() async {
      try {
        dev.log("🔄 バックグラウンド位置情報取得開始");

        final location = await LocationService.getCurrentLocationAsLatLng()
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                dev.log("⏰ バックグラウンド位置情報取得タイムアウト");
                return null;
              },
            );

        if (location != null) {
          dev.log("✅ バックグラウンド位置情報取得成功: $location");

          // 位置情報をFirestoreに自動保存
          try {
            dev.log("📍 アプリ起動時の位置情報をFirestoreに保存開始...");
            await PushNotificationService.saveUserLocation(
              location.latitude,
              location.longitude,
            );
            dev.log("📍 ✅ アプリ起動時の位置情報をFirestoreに自動保存完了");
            dev.log("📍 保存された座標: 緯度=${location.latitude.toStringAsFixed(2)}, 経度=${location.longitude.toStringAsFixed(2)}");
          } catch (saveError) {
            dev.log("❌ 位置情報自動保存エラー: $saveError");
          }

        } else {
          dev.log("⚠️ バックグラウンド位置情報取得失敗");
        }

      } catch (e) {
        dev.log("❌ バックグラウンド位置情報取得エラー: $e");
      }
    });
  }

  /// ユーザーIDサービスの初期化
  static Future<void> _initializeUserIdService() async {
    try {
      dev.log("👤 ユーザーIDサービス初期化開始");

      // ユーザーIDを初期化（初回起動時はUUID生成）
      final userId = await UserIdService.getUserId();
      dev.log("✅ ユーザーID初期化完了: ${userId.substring(0, 8)}...");

    } catch (e) {
      dev.log("❌ ユーザーIDサービス初期化エラー: $e");
    }
  }

  /// FCMトークンの状態確認
  static String? getFCMTokenStatus() {
    final token = PushNotificationService.fcmToken;
    if (token == null) return null;

    dev.log("📝 FCMトークン状態: ${token.substring(0, 20)}...");
    return token;
  }

  /// ユーザー統計情報を取得（外部公開用）
  static Future<Map<String, dynamic>> getUserStatistics() async {
    return await UserService.getUserStatistics();
  }
}

/// バックグラウンドメッセージハンドラー
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(/* options: DefaultFirebaseOptions.currentPlatform */); // 一時的にコメントアウト
  dev.log("📨 バックグラウンドメッセージ受信: ${message.messageId}");
}