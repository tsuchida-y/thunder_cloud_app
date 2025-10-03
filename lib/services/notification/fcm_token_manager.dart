import 'dart:developer' as dev;
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../constants/app_constants.dart';

/// FCMトークン管理サービスクラス
/// Firebase Cloud Messagingトークンの取得・キャッシュ・管理を担当
/// シミュレーター環境での代替トークン生成も提供
class FCMTokenManager {

  // キャッシュされたFCMトークン
  static String? _cachedToken;

  // 最後のトークン更新時刻
  // キャッシュの有効期限判定に使用
  static DateTime? _lastTokenUpdate;

  // 現在のFCMトークンを取得
  // キャッシュされたトークンを返す（nullの可能性あり）
  static String? get currentToken => _cachedToken;

  /// トークンが有効かどうかチェック
  /// キャッシュの有効期限を確認
  static bool get isTokenValid {
    if (_cachedToken == null || _lastTokenUpdate == null) return false;

    final now = DateTime.now();
    return now.difference(_lastTokenUpdate!) < AppConstants.tokenValidityDuration;
  }

  /*
  ================================================================================
                                トークン取得機能
                        主要なトークン取得とキャッシュ管理
  ================================================================================
  */

  /// FCMトークンを取得（キャッシュ機能付き）
  /// 有効なキャッシュがある場合はそれを返し、なければ新規取得
  ///
  /// [forceRefresh] 強制的に新規取得するかどうか
  /// Returns: FCMトークン、取得できない場合はnull
  static Future<String?> getToken({bool forceRefresh = false}) async {
    if (!forceRefresh && isTokenValid && _cachedToken != null) {
      dev.log("✅ キャッシュされたFCMトークンを使用: ${_cachedToken!.substring(0, 20)}...");
      // デバッグ用：完全なキャッシュトークンを表示
      if (kDebugMode) {
        dev.log("🔑 キャッシュされた完全なFCMトークン: $_cachedToken");
      }
      return _cachedToken;
    }
    dev.log("🔄 FCMトークンを新規取得中...");
    try {
      final messaging = FirebaseMessaging.instance;
      // シミュレーターや開発用トークン生成は削除
      final token = await _acquireRealToken(messaging);
      if (token != null) {
        _cacheToken(token);
        return token;
      }
      dev.log("❌ FCMトークンの取得に失敗しました");
      return null;
    } catch (e) {
      dev.log("❌ FCMトークン取得エラー: $e");
      return null;
    }
  }

  /*
  ================================================================================
                                実機トークン取得
                        実際のデバイスでのトークン取得処理
  ================================================================================
  */

  /// 実機でのトークン取得
  /// リトライ機能付きでFCMトークンを取得
  ///
  /// [messaging] Firebase Messagingインスタンス
  /// [maxRetries] 最大リトライ回数
  /// Returns: 取得したトークン、失敗時はnull
  static Future<String?> _acquireRealToken(FirebaseMessaging messaging, {int maxRetries = AppConstants.fcmTokenMaxRetries}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        dev.log("🔑 FCMトークン取得試行 $attempt/$maxRetries");

        // ステップ1: iOS実機の場合はAPNSトークンを先に確認
        if (Platform.isIOS) {
          await _ensureAPNSToken(messaging, attempt);
        }

        // ステップ2: FCMトークンの取得
        final token = await messaging.getToken();

        if (token != null && token.isNotEmpty) {
          dev.log("✅ 実機FCMトークン取得成功");
          // デバッグ用：完全なトークンを表示
          if (kDebugMode) {
            dev.log("🔑 取得した完全なFCMトークン: $token");
          }
          return token;
        }

        dev.log("⚠️ FCMトークンがnull (試行 $attempt/$maxRetries)");

        // ステップ3: リトライ前の待機
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt));
        }

      } catch (e) {
        dev.log("❌ FCMトークン取得エラー (試行 $attempt/$maxRetries): $e");

        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt));
        }
      }
    }

    dev.log("❌ 全ての試行でFCMトークン取得に失敗");
    return null;
  }

  /// APNSトークンの確保（iOS用）
  /// iOS実機でのプッシュ通知に必要なAPNSトークンを確認
  ///
  /// [messaging] Firebase Messagingインスタンス
  /// [attempt] 現在の試行回数
  static Future<void> _ensureAPNSToken(FirebaseMessaging messaging, int attempt) async {
    try {
      // シミュレータの場合は処理をスキップ
      if (kDebugMode && Platform.isIOS) {
        // シミュレータかどうかの判定を追加
        try {
          final deviceInfo = await _getDeviceInfo();
          if (deviceInfo['isSimulator'] == true) {
            dev.log("⚠️ iOSシミュレータ環境のため、APNSトークン処理をスキップ");
            return;
          }
        } catch (e) {
          dev.log("⚠️ デバイス情報取得失敗、実機として処理継続: $e");
        }
      }

      // ステップ1: 通知権限の確認と要求
      final settings = await messaging.getNotificationSettings();
      dev.log("📱 現在の通知権限状態: ${settings.authorizationStatus}");

      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        dev.log("🔔 通知権限を要求中...");
        final permission = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          announcement: false,
        );
        dev.log("🔔 通知権限要求結果: ${permission.authorizationStatus}");

        if (permission.authorizationStatus != AuthorizationStatus.authorized) {
          dev.log("❌ 通知権限が拒否されました");
          return;
        }
      } else if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        dev.log("❌ 通知権限が許可されていません: ${settings.authorizationStatus}");
        dev.log("💡 設定アプリで手動で権限を許可してください");
        return;
      }

      // ステップ2: APNSトークンの取得（より長い待機時間で試行）
      String? apnsToken;
      const int maxAttempts = 10; // 試行回数を増加
      const int waitTimeMs = 2000; // 待機時間を2秒に延長

      for (int i = 0; i < maxAttempts; i++) {
        dev.log("⚠️ APNSトークン未取得 (試行 $attempt-${i + 1})");

        // APNSトークンを取得
        apnsToken = await messaging.getAPNSToken();

        if (apnsToken != null && apnsToken.isNotEmpty) {
          dev.log("✅ APNSトークン確認済み: ${apnsToken.substring(0, 10)}...");
          return;
        }

        // 待機時間を延長（iOSシステムがAPNSトークンを設定する時間を確保）
        await Future.delayed(const Duration(milliseconds: waitTimeMs));
      }

      dev.log("❌ APNSトークンの取得に失敗しました");

      // 開発環境での回避策
      if (kDebugMode) {
        dev.log("⚠️ 開発環境のため、APNSトークンなしで続行します");
        return;
      }

    } catch (e) {
      dev.log("❌ APNSトークン取得エラー: $e");
    }
  }

  /*
  ================================================================================
                                キャッシュ管理
                        トークンのキャッシュ操作と状態管理
  ================================================================================
  */

  /// トークンをキャッシュ
  /// 取得したトークンを内部キャッシュに保存
  ///
  /// [token] キャッシュするトークン
  static void _cacheToken(String token) {
    _cachedToken = token;
    _lastTokenUpdate = DateTime.now();
    dev.log("💾 FCMトークンをキャッシュ");

    // デバッグ用：完全なトークンを表示
    if (kDebugMode) {
      dev.log("🔑 完全なFCMトークン: $token");
    }
  }

  /// トークンキャッシュをクリア
  /// キャッシュされたトークンと更新時刻をリセット
  static void clearCache() {
    _cachedToken = null;
    _lastTokenUpdate = null;
    dev.log("🗑️ FCMトークンキャッシュをクリア");
  }

  /*
  ================================================================================
                                状態情報取得
                        トークンの詳細状態とデバッグ情報
  ================================================================================
  */

  /// トークン状態の詳細情報
  /// デバッグや監視用のトークン状態情報を取得
  ///
  /// Returns: トークン状態の詳細情報マップ
  static Map<String, dynamic> getTokenStatus() {
    return {
      'hasToken': _cachedToken != null,
      'isValid': isTokenValid,
      'lastUpdate': _lastTokenUpdate?.toIso8601String(),
      'tokenPreview': _cachedToken?.substring(0, 20),
    };
  }
}