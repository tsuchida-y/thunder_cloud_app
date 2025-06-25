import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../utils/logger.dart';

/// ユーザーIDの生成と管理を行うサービス
class UserIdService {
  static const String _userIdKey = 'unique_user_id';
  static const Uuid _uuid = Uuid();
  static String? _cachedUserId;

  /// 一意のユーザーIDを取得（初回のみ生成、以降はキャッシュ）
  static Future<String> getUserId() async {
    if (_cachedUserId != null) {
      AppLogger.debug('キャッシュされたユーザーIDを使用: $_cachedUserId', tag: 'UserIdService');
      return _cachedUserId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString(_userIdKey);

      if (userId == null) {
        // 初回起動時：新しいUUIDを生成
        userId = _uuid.v4();
        await prefs.setString(_userIdKey, userId);
        AppLogger.info('新しいユーザーIDを生成: $userId', tag: 'UserIdService');
      } else {
        AppLogger.info('既存のユーザーIDを取得: $userId', tag: 'UserIdService');
      }

      _cachedUserId = userId;
      return userId;
    } catch (e) {
      AppLogger.error('ユーザーID取得エラー', error: e, tag: 'UserIdService');

      // エラー時はフォールバック用の一時IDを生成
      final fallbackId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      AppLogger.warning('フォールバックIDを使用: $fallbackId', tag: 'UserIdService');
      return fallbackId;
    }
  }

  /// ユーザーIDをリセット（デバッグ用）
  static Future<void> resetUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      _cachedUserId = null;
      AppLogger.info('ユーザーIDをリセットしました', tag: 'UserIdService');
    } catch (e) {
      AppLogger.error('ユーザーIDリセットエラー', error: e, tag: 'UserIdService');
    }
  }

  /// 現在のユーザーIDを取得（キャッシュのみ）
  static String? get currentUserId => _cachedUserId;

  /// ユーザーIDの状態を取得
  static Map<String, dynamic> getStatus() {
    return {
      'hasCachedId': _cachedUserId != null,
      'currentId': _cachedUserId,
      'idLength': _cachedUserId?.length,
    };
  }
}