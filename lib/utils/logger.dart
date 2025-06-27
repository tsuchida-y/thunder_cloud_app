import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// アプリケーション全体で統一されたログ出力を提供するユーティリティ
class AppLogger {
  static const String _prefix = "ThunderCloudApp";

  /// ログレベル設定（本番環境では ERROR のみ）
  static bool get _isDebugMode => kDebugMode;

  /// 情報ログ
  static void info(String message, {String? tag}) {
    if (!_isDebugMode) return; // 本番環境では無効
    final logMessage = _formatMessage(message, tag, "INFO");
    dev.log(logMessage);
  }

  /// エラーログ（本番環境でも出力）
  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    final logMessage = _formatMessage(message, tag, "ERROR");
    dev.log(
      logMessage,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// 警告ログ
  static void warning(String message, {String? tag}) {
    if (!_isDebugMode) return; // 本番環境では無効
    final logMessage = _formatMessage(message, tag, "WARN");
    dev.log(logMessage);
  }

  /// デバッグログ
  static void debug(String message, {String? tag}) {
    if (!_isDebugMode) return; // 本番環境では無効
    final logMessage = _formatMessage(message, tag, "DEBUG");
    dev.log(logMessage);
  }

  /// 成功ログ
  static void success(String message, {String? tag}) {
    if (!_isDebugMode) return; // 本番環境では無効
    final logMessage = _formatMessage("✅ $message", tag, "SUCCESS");
    dev.log(logMessage);
  }

  /// 失敗ログ（本番環境でも出力）
  static void failure(String message, {Object? error, String? tag}) {
    final logMessage = _formatMessage("❌ $message", tag, "FAILURE");
    dev.log(logMessage, error: error);
  }

  /// 進行中ログ
  static void progress(String message, {String? tag}) {
    if (!_isDebugMode) return; // 本番環境では無効
    final logMessage = _formatMessage("🔄 $message", tag, "PROGRESS");
    dev.log(logMessage);
  }

  /// ログメッセージのフォーマット
  static String _formatMessage(String message, String? tag, String level) {
    final timestamp = DateTime.now().toIso8601String();
    final tagPart = tag != null ? "[$tag] " : "";
    return "[$_prefix][$level][$timestamp] $tagPart$message";
  }
}

/// サービス別のロガー
abstract class ServiceLogger {
  static void location(String message, {String? level}) {
    switch (level?.toLowerCase()) {
      case 'error':
        AppLogger.error(message, tag: 'Location');
        break;
      case 'warning':
        AppLogger.warning(message, tag: 'Location');
        break;
      case 'success':
        AppLogger.success(message, tag: 'Location');
        break;
      default:
        AppLogger.info(message, tag: 'Location');
    }
  }

  static void fcm(String message, {String? level}) {
    switch (level?.toLowerCase()) {
      case 'error':
        AppLogger.error(message, tag: 'FCM');
        break;
      case 'warning':
        AppLogger.warning(message, tag: 'FCM');
        break;
      case 'success':
        AppLogger.success(message, tag: 'FCM');
        break;
      default:
        AppLogger.info(message, tag: 'FCM');
    }
  }

  static void notification(String message, {String? level}) {
    switch (level?.toLowerCase()) {
      case 'error':
        AppLogger.error(message, tag: 'Notification');
        break;
      case 'warning':
        AppLogger.warning(message, tag: 'Notification');
        break;
      case 'success':
        AppLogger.success(message, tag: 'Notification');
        break;
      default:
        AppLogger.info(message, tag: 'Notification');
    }
  }

  static void weather(String message, {String? level}) {
    switch (level?.toLowerCase()) {
      case 'error':
        AppLogger.error(message, tag: 'Weather');
        break;
      case 'warning':
        AppLogger.warning(message, tag: 'Weather');
        break;
      case 'success':
        AppLogger.success(message, tag: 'Weather');
        break;
      default:
        AppLogger.info(message, tag: 'Weather');
    }
  }
}