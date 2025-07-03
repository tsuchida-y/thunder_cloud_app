import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCMトークン管理サービスクラス
/// Firebase Cloud Messagingトークンの取得・キャッシュ・管理を担当
/// シミュレーター環境での代替トークン生成も提供
class FCMTokenManager {
  /*
  ================================================================================
                                    定数定義
                          キャッシュ期間とリトライ設定
  ================================================================================
  */
  /// キャッシュされたトークンの有効期限（1時間）
  /// トークンの再取得頻度を制御
  static const Duration _tokenValidityDuration = Duration(hours: 1);

  /// 最大リトライ回数
  /// トークン取得失敗時の再試行回数
  static const int _maxRetries = 3;

  /*
  ================================================================================
                                    状態管理
                          トークンのキャッシュと有効性管理
  ================================================================================
  */
  /// キャッシュされたFCMトークン
  /// 有効期限内のトークンを保持
  static String? _cachedToken;

  /// 最後のトークン更新時刻
  /// キャッシュの有効期限判定に使用
  static DateTime? _lastTokenUpdate;

  /*
  ================================================================================
                                プロパティアクセス
                        トークン状態の取得と確認
  ================================================================================
  */

  /// 現在のFCMトークンを取得
  /// キャッシュされたトークンを返す（nullの可能性あり）
  static String? get currentToken => _cachedToken;

  /// トークンが有効かどうかチェック
  /// キャッシュの有効期限を確認
  static bool get isTokenValid {
    if (_cachedToken == null || _lastTokenUpdate == null) return false;

    final now = DateTime.now();
    return now.difference(_lastTokenUpdate!) < _tokenValidityDuration;
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
    // ステップ1: 有効なキャッシュがある場合はそれを返す
    if (!forceRefresh && isTokenValid && _cachedToken != null) {
      dev.log("✅ キャッシュされたFCMトークンを使用: ${_cachedToken!.substring(0, 20)}...");
      return _cachedToken;
    }

    dev.log("🔄 FCMトークンを新規取得中...");

    try {
      final messaging = FirebaseMessaging.instance;

      // ステップ2: シミュレーター検出
      if (Platform.isIOS && await _isSimulator()) {
        return await _generateDevelopmentToken();
      }

      // ステップ3: 実機での取得を試行
      final token = await _acquireRealToken(messaging);

      if (token != null) {
        _cacheToken(token);
        return token;
      }

      // ステップ4: 開発環境では代替トークンを生成
      if (kDebugMode) {
        return await _generateDevelopmentToken();
      }

      return null;

    } catch (e) {
      dev.log("❌ FCMトークン取得エラー: $e");

      if (kDebugMode) {
        return await _generateDevelopmentToken();
      }

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
  static Future<String?> _acquireRealToken(FirebaseMessaging messaging, {int maxRetries = _maxRetries}) async {
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
      // ステップ1: APNSトークンの取得
      final apnsToken = await messaging.getAPNSToken();

      if (apnsToken != null) {
        dev.log("✅ APNSトークン確認済み");
      } else {
        dev.log("⚠️ APNSトークン未取得 (試行 $attempt)");
        // ステップ2: 短時間待機してAPNSの準備を待つ
        await Future.delayed(Duration(seconds: 2 * attempt));
      }

    } catch (e) {
      dev.log("❌ APNSトークン確認エラー: $e");
    }
  }

  /*
  ================================================================================
                                開発環境対応
                        シミュレーター・開発環境での代替トークン生成
  ================================================================================
  */

  /// 開発用トークンの生成
  /// シミュレーターや開発環境で使用する代替トークンを生成
  ///
  /// Returns: 生成された開発用トークン
  static Future<String?> _generateDevelopmentToken() async {
    // ステップ1: 環境の判定
    final isSimulator = Platform.isIOS && await _isSimulator();
    final tokenType = isSimulator ? "シミュレーター" : "開発";

    dev.log("🎭 $tokenType用トークンを生成");

    // ステップ2: ランダムトークンの生成
    final random = math.Random();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final token = 'dev_token_${List.generate(40, (index) => chars[random.nextInt(chars.length)]).join()}';

    // ステップ3: トークンのキャッシュ
    _cacheToken(token);
    dev.log("✅ 開発用トークン生成完了: ${token.substring(0, 20)}...");

    return token;
  }

  /// シミュレーター判定
  /// iOSシミュレーター環境かどうかを判定
  ///
  /// Returns: シミュレーター環境の場合はtrue
  static Future<bool> _isSimulator() async {
    if (!Platform.isIOS) return false;

    try {
      // ステップ1: 環境変数によるシミュレーター検出
      return Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
             Platform.environment['SIMULATOR_VERSION_INFO'] != null;
    } catch (e) {
      return false;
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
      'isDevelopmentToken': _cachedToken?.startsWith('dev_token_') ?? false,
    };
  }
}