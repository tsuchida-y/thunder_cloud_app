import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCMトークンの取得と管理を専門に行うサービス
class FCMTokenManager {
  static String? _cachedToken;
  static DateTime? _lastTokenUpdate;

  /// キャッシュされたトークンの有効期限（1時間）
  static const Duration _tokenValidityDuration = Duration(hours: 1);

  /// 現在のFCMトークンを取得
  static String? get currentToken => _cachedToken;

  /// トークンが有効かどうかチェック
  static bool get isTokenValid {
    if (_cachedToken == null || _lastTokenUpdate == null) return false;

    final now = DateTime.now();
    return now.difference(_lastTokenUpdate!) < _tokenValidityDuration;
  }

  /// FCMトークンを取得（キャッシュ機能付き）
  static Future<String?> getToken({bool forceRefresh = false}) async {
    // 有効なキャッシュがある場合はそれを返す
    if (!forceRefresh && isTokenValid && _cachedToken != null) {
      dev.log("✅ キャッシュされたFCMトークンを使用: ${_cachedToken!.substring(0, 20)}...");
      return _cachedToken;
    }

    dev.log("🔄 FCMトークンを新規取得中...");

    try {
      final messaging = FirebaseMessaging.instance;

      // シミュレーター検出
      if (Platform.isIOS && await _isSimulator()) {
        return await _generateDevelopmentToken();
      }

      // 実機での取得を試行
      final token = await _acquireRealToken(messaging);

      if (token != null) {
        _cacheToken(token);
        return token;
      }

      // 開発環境では代替トークンを生成
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

  /// 実機でのトークン取得
  static Future<String?> _acquireRealToken(FirebaseMessaging messaging, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        dev.log("🔑 FCMトークン取得試行 $attempt/$maxRetries");

        // iOS実機の場合はAPNSトークンを先に確認
        if (Platform.isIOS) {
          await _ensureAPNSToken(messaging, attempt);
        }

        final token = await messaging.getToken();

        if (token != null && token.isNotEmpty) {
          dev.log("✅ 実機FCMトークン取得成功");
          return token;
        }

        dev.log("⚠️ FCMトークンがnull (試行 $attempt/$maxRetries)");

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
  static Future<void> _ensureAPNSToken(FirebaseMessaging messaging, int attempt) async {
    try {
      final apnsToken = await messaging.getAPNSToken();

      if (apnsToken != null) {
        dev.log("✅ APNSトークン確認済み");
      } else {
        dev.log("⚠️ APNSトークン未取得 (試行 $attempt)");
        // 短時間待機してAPNSの準備を待つ
        await Future.delayed(Duration(seconds: 2 * attempt));
      }

    } catch (e) {
      dev.log("❌ APNSトークン確認エラー: $e");
    }
  }

  /// 開発用トークンの生成
  static Future<String?> _generateDevelopmentToken() async {
    final isSimulator = Platform.isIOS && await _isSimulator();
    final tokenType = isSimulator ? "シミュレーター" : "開発";

    dev.log("🎭 $tokenType用トークンを生成");

    final random = math.Random();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final token = 'dev_token_${List.generate(40, (index) => chars[random.nextInt(chars.length)]).join()}';

    _cacheToken(token);
    dev.log("✅ 開発用トークン生成完了: ${token.substring(0, 20)}...");

    return token;
  }

  /// トークンをキャッシュ
  static void _cacheToken(String token) {
    _cachedToken = token;
    _lastTokenUpdate = DateTime.now();
    dev.log("💾 FCMトークンをキャッシュ");
  }

  /// トークンキャッシュをクリア
  static void clearCache() {
    _cachedToken = null;
    _lastTokenUpdate = null;
    dev.log("🗑️ FCMトークンキャッシュをクリア");
  }

  /// シミュレーター判定
  static Future<bool> _isSimulator() async {
    if (!Platform.isIOS) return false;

    try {
      return Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
             Platform.environment['SIMULATOR_VERSION_INFO'] != null;
    } catch (e) {
      return false;
    }
  }

  /// トークン状態の詳細情報
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