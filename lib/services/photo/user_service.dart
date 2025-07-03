import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_constants.dart';
import '../../utils/logger.dart';
import '../notification/fcm_token_manager.dart';

/// ユーザー情報管理サービス
/// FCMトークンベースの統合構造でユーザー情報を管理
class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();

  /*
  ================================================================================
                                ユーザー情報取得
                    FCMトークンベースの統合構造でユーザー情報を取得
  ================================================================================
  */

  /// ユーザー情報を取得（統合構造）
  /// FCMトークンをドキュメントIDとして使用し、存在しない場合は作成
  ///
  /// [userId] ユーザーID（プロフィール情報用）
  /// Returns: ユーザー情報マップ
  static Future<Map<String, dynamic>> getUserInfo(String userId) async {
    try {
      // ステップ1: FCMトークンを取得
      final fcmToken = FCMTokenManager.currentToken;
      if (fcmToken == null) {
        AppLogger.error('FCMトークンが取得できません', tag: 'UserService');
        return _createFallbackUserInfo(userId);
      }

      // ステップ2: FCMトークンベースでドキュメントを取得
      final doc = await _firestore.collection('users').doc(fcmToken).get();

      if (doc.exists) {
        final data = doc.data() ?? {};

        // ステップ3: プロフィール情報が不足している場合は補完
        if (!data.containsKey('userId') || !data.containsKey('userName')) {
          await _updateProfileInfo(fcmToken, userId, data);
          // 更新後のデータを再取得
          final updatedDoc = await _firestore.collection('users').doc(fcmToken).get();
          return updatedDoc.data() ?? _createFallbackUserInfo(userId);
        }

        return data;
      } else {
        // ステップ4: ドキュメントが存在しない場合は統合構造で作成
        final defaultUserInfo = _createDefaultUserInfo(fcmToken, userId);
        await _firestore.collection('users').doc(fcmToken).set(defaultUserInfo);
        return defaultUserInfo;
      }
    } catch (e) {
      AppLogger.error('ユーザー情報取得エラー: $e', tag: 'UserService');
      return _createFallbackUserInfo(userId);
    }
  }

  /*
  ================================================================================
                                ユーザー情報更新
                        統合構造でのユーザー情報更新処理
  ================================================================================
  */

  /// ユーザー名を更新
  /// FCMトークンベースのドキュメントを更新
  ///
  /// [userId] ユーザーID
  /// [newName] 新しいユーザー名
  /// Returns: 更新成功時はtrue
  static Future<bool> updateUserName(String userId, String newName) async {
    try {
      // ステップ1: FCMトークンを取得
      final fcmToken = FCMTokenManager.currentToken;
      if (fcmToken == null) {
        AppLogger.error('FCMトークンが取得できません', tag: 'UserService');
        return false;
      }

      // ステップ2: FCMトークンベースでドキュメントを更新
      await _firestore.collection('users').doc(fcmToken).update({
        'userName': newName,
        'updatedAt': DateTime.now(),
      });

      // ステップ3: 既存の写真のuserNameも更新
      final photosQuery = await _firestore
          .collection('photos')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (var doc in photosQuery.docs) {
        batch.update(doc.reference, {'userName': newName});
      }
      await batch.commit();

      AppLogger.success('ユーザー名更新完了: $newName', tag: 'UserService');
      return true;
    } catch (e) {
      AppLogger.error('ユーザー名更新エラー: $e', tag: 'UserService');
      return false;
    }
  }

  /// アバター画像を更新（古い画像を自動削除）
  /// FCMトークンベースのドキュメントを更新
  ///
  /// [userId] ユーザーID
  /// Returns: 更新成功時はtrue
  static Future<bool> updateUserAvatar(String userId) async {
    try {
      AppLogger.info('アバター画像更新開始', tag: 'UserService');

      // ステップ1: FCMトークンを取得
      final fcmToken = FCMTokenManager.currentToken;
      if (fcmToken == null) {
        AppLogger.error('FCMトークンが取得できません', tag: 'UserService');
        return false;
      }

      // ステップ2: 現在のユーザー情報を取得（古いアバターURL取得のため）
      final currentUserInfo = await getUserInfo(userId);
      final oldAvatarUrl = currentUserInfo['avatarUrl'] as String? ?? '';

      // ステップ3: 画像選択
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: AppConstants.imageMaxWidth.toDouble(),
        maxHeight: AppConstants.imageMaxHeight.toDouble(),
        imageQuality: AppConstants.imageQuality,
      );

      if (image == null) {
        AppLogger.info('画像選択がキャンセルされました', tag: 'UserService');
        return false;
      }

      // ステップ4: 画像ファイルの存在確認
      final File imageFile = File(image.path);
      if (!await imageFile.exists()) {
        AppLogger.error('選択された画像ファイルが存在しません: ${image.path}', tag: 'UserService');
        throw Exception('選択された画像ファイルが見つかりません');
      }

      // ステップ5: ファイルサイズチェック（5MB制限）
      final int fileSize = await imageFile.length();
      const int maxSize = 5 * 1024 * 1024; // 5MB
      if (fileSize > maxSize) {
        AppLogger.error('画像ファイルサイズが大きすぎます: $fileSize bytes', tag: 'UserService');
        throw Exception('画像ファイルサイズが大きすぎます（5MB以下にしてください）');
      }

      // ステップ6: Firebase Storageに新しい画像をアップロード
      final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('avatars').child(fileName);

      AppLogger.info('新しいアバター画像アップロード開始: $fileName', tag: 'UserService');

      try {
        final uploadTask = ref.putFile(imageFile);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        AppLogger.info('新しいアバターURL: $downloadUrl', tag: 'UserService');

        // ステップ7: FCMトークンベースでFirestoreのユーザー情報を更新
        await _firestore.collection('users').doc(fcmToken).update({
          'avatarUrl': downloadUrl,
          'updatedAt': DateTime.now(),
        });

        AppLogger.success('Firestore更新完了', tag: 'UserService');

        // ステップ8: 古いアバター画像を削除（非同期で実行、エラーは無視）
        if (oldAvatarUrl.isNotEmpty) {
          AppLogger.info('古いアバター削除を開始します: $oldAvatarUrl', tag: 'UserService');

          // 非同期で削除を実行（エラーは無視）
          _deleteOldAvatar(oldAvatarUrl).catchError((error) {
            AppLogger.warning('古いアバター削除でエラー（無視）: $error', tag: 'UserService');
          });
        } else {
          AppLogger.info('削除対象の古いアバターがありません', tag: 'UserService');
        }

        AppLogger.success('アバター画像更新完了', tag: 'UserService');
        return true;

      } catch (uploadError) {
        AppLogger.error('Firebase Storageアップロードエラー: $uploadError', tag: 'UserService');

        // ネットワークエラーの場合
        if (uploadError.toString().contains('network') ||
            uploadError.toString().contains('timeout') ||
            uploadError.toString().contains('connection')) {
          throw Exception('ネットワーク接続エラーです。インターネット接続を確認してください');
        }

        // 権限エラーの場合
        if (uploadError.toString().contains('unauthorized') ||
            uploadError.toString().contains('permission')) {
          throw Exception('アップロード権限がありません');
        }

        // その他のエラー
        throw Exception('画像のアップロードに失敗しました: $uploadError');
      }

    } catch (e) {
      AppLogger.error('アバター画像更新エラー: $e', tag: 'UserService');
      return false;
    }
  }

  /*
  ================================================================================
                                ヘルパーメソッド
                        統合構造作成・更新のためのヘルパー関数
  ================================================================================
  */

  /// 統合構造のデフォルトユーザー情報を作成
  /// 通知システム用とプロフィール用の情報を統合
  ///
  /// [fcmToken] FCMトークン
  /// [userId] ユーザーID
  /// Returns: 統合構造のユーザー情報
  static Map<String, dynamic> _createDefaultUserInfo(String fcmToken, String userId) {
    final now = DateTime.now();
    return {
      // 通知システム用フィールド
      'fcmToken': fcmToken,
      'isActive': true,
      'appVersion': '1.0.0',
      'platform': 'flutter',
      'lastUpdated': now,

      // プロフィール情報用フィールド
      'userId': userId,
      'userName': 'ユーザー',
      'avatarUrl': '',
      'createdAt': now,
      'updatedAt': now,
    };
  }

  /// プロフィール情報を補完
  /// 既存のドキュメントにプロフィール情報が不足している場合に補完
  ///
  /// [fcmToken] FCMトークン
  /// [userId] ユーザーID
  /// [existingData] 既存のデータ
  static Future<void> _updateProfileInfo(String fcmToken, String userId, Map<String, dynamic> existingData) async {
    try {
      final updateData = <String, dynamic>{};
      final now = DateTime.now();

      // 不足しているプロフィール情報を補完
      if (!existingData.containsKey('userId')) {
        updateData['userId'] = userId;
      }
      if (!existingData.containsKey('userName')) {
        updateData['userName'] = 'ユーザー';
      }
      if (!existingData.containsKey('avatarUrl')) {
        updateData['avatarUrl'] = '';
      }
      if (!existingData.containsKey('createdAt')) {
        updateData['createdAt'] = now;
      }
      updateData['updatedAt'] = now;

      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(fcmToken).update(updateData);
        AppLogger.info('プロフィール情報補完完了', tag: 'UserService');
      }
    } catch (e) {
      AppLogger.error('プロフィール情報補完エラー: $e', tag: 'UserService');
    }
  }

  /// フォールバック用のユーザー情報を作成
  /// FCMトークンが取得できない場合の代替情報
  ///
  /// [userId] ユーザーID
  /// Returns: フォールバック用のユーザー情報
  static Map<String, dynamic> _createFallbackUserInfo(String userId) {
    return {
      'userId': userId,
      'userName': 'ユーザー',
      'avatarUrl': '',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    };
  }

  /// 古いアバター画像を削除
  static Future<void> _deleteOldAvatar(String oldAvatarUrl) async {
    if (oldAvatarUrl.isEmpty) {
      AppLogger.info('削除対象URLが空です', tag: 'UserService');
      return;
    }

    try {
      AppLogger.info('古いアバター画像削除開始: $oldAvatarUrl', tag: 'UserService');

      // URLの形式をチェック
      if (!oldAvatarUrl.contains('firebase') && !oldAvatarUrl.contains('googleapis')) {
        AppLogger.warning('Firebase StorageのURLではありません: $oldAvatarUrl', tag: 'UserService');
        return;
      }

      // Firebase StorageのURLから参照を取得
      AppLogger.info('Firebase Storage参照を取得中...', tag: 'UserService');
      final ref = _storage.refFromURL(oldAvatarUrl);
      AppLogger.info('参照パス: ${ref.fullPath}', tag: 'UserService');

      // ファイルの存在確認
      try {
        final metadata = await ref.getMetadata();
        AppLogger.info('ファイル存在確認OK: サイズ ${metadata.size} bytes', tag: 'UserService');
      } catch (e) {
        AppLogger.warning('ファイルが存在しないか、メタデータ取得エラー: $e', tag: 'UserService');
        // ファイルが存在しない場合でも削除を試行
      }

      // 削除実行
      AppLogger.info('ファイル削除を実行中...', tag: 'UserService');
      await ref.delete();

      AppLogger.success('古いアバター画像削除完了', tag: 'UserService');
    } catch (e) {
      // 削除エラーの詳細を記録
      AppLogger.error('古いアバター画像削除エラー: $e', tag: 'UserService');
      AppLogger.error('エラータイプ: ${e.runtimeType}', tag: 'UserService');
      AppLogger.error('対象URL: $oldAvatarUrl', tag: 'UserService');

      // Firebase Storage特有のエラーをチェック
      if (e.toString().contains('object-not-found')) {
        AppLogger.info('ファイルが既に削除されているか存在しません', tag: 'UserService');
      } else if (e.toString().contains('unauthorized')) {
        AppLogger.error('削除権限がありません', tag: 'UserService');
      } else if (e.toString().contains('invalid-url')) {
        AppLogger.error('無効なURLです', tag: 'UserService');
      }

      rethrow; // エラーを再スローして上位で処理
    }
  }

  /// 選択済みファイルでアバター画像を更新
  static Future<String?> updateUserAvatarWithFile(String userId, File imageFile) async {
    try {
      AppLogger.info('ファイルベースアバター画像更新開始', tag: 'UserService');

      // 現在のユーザー情報を取得（古いアバターURL取得のため）
      final currentUserInfo = await getUserInfo(userId);
      final oldAvatarUrl = currentUserInfo['avatarUrl'] as String? ?? '';

      // ファイルサイズチェック（5MB制限）
      final int fileSize = await imageFile.length();
      const int maxSize = 5 * 1024 * 1024; // 5MB
      if (fileSize > maxSize) {
        AppLogger.error('画像ファイルサイズが大きすぎます: $fileSize bytes', tag: 'UserService');
        throw Exception('画像ファイルサイズが大きすぎます（5MB以下にしてください）');
      }

      // Firebase Storageに新しい画像をアップロード
      final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('avatars').child(fileName);

      AppLogger.info('新しいアバター画像アップロード開始: $fileName', tag: 'UserService');

      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      AppLogger.info('新しいアバターURL: $downloadUrl', tag: 'UserService');

      // Firestoreのユーザー情報を更新
      await _firestore.collection('users').doc(userId).update({
        'avatarUrl': downloadUrl,
        'updatedAt': DateTime.now(),
      });

      AppLogger.success('Firestore更新完了', tag: 'UserService');

      // 古いアバター画像を削除（非同期で実行、エラーは無視）
      if (oldAvatarUrl.isNotEmpty) {
        AppLogger.info('古いアバター削除を開始します: $oldAvatarUrl', tag: 'UserService');

        // 非同期で削除を実行（エラーは無視）
        _deleteOldAvatar(oldAvatarUrl).catchError((error) {
          AppLogger.warning('古いアバター削除でエラー（無視）: $error', tag: 'UserService');
        });
      } else {
        AppLogger.info('削除対象の古いアバターがありません', tag: 'UserService');
      }

      AppLogger.success('ファイルベースアバター画像更新完了', tag: 'UserService');
      return downloadUrl;

    } catch (e) {
      AppLogger.error('ファイルベースアバター画像更新エラー: $e', tag: 'UserService');

      // エラーメッセージをユーザーフレンドリーに変換
      String userMessage = '画像の更新に失敗しました';

      if (e.toString().contains('network') || e.toString().contains('connection')) {
        userMessage = 'ネットワーク接続エラーです。インターネット接続を確認してください';
      } else if (e.toString().contains('permission') || e.toString().contains('unauthorized')) {
        userMessage = '権限エラーが発生しました';
      } else if (e.toString().contains('ファイルサイズ')) {
        userMessage = '画像ファイルサイズが大きすぎます（5MB以下にしてください）';
      }

      // エラーを再スロー（上位でユーザーフレンドリーなメッセージを表示）
      throw Exception(userMessage);
    }
  }

  /// ユーザー情報を一括更新
  static Future<bool> updateUserInfo(String userId, {
    String? userName,
    String? avatarUrl,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'updatedAt': DateTime.now(),
      };

      if (userName != null) updateData['userName'] = userName;
      if (avatarUrl != null) updateData['avatarUrl'] = avatarUrl;

      await _firestore.collection('users').doc(userId).update(updateData);

      // 写真の userName も更新（userName が指定された場合のみ）
      if (userName != null) {
        final photosQuery = await _firestore
            .collection('photos')
            .where('userId', isEqualTo: userId)
            .get();

        final batch = _firestore.batch();
        for (var doc in photosQuery.docs) {
          batch.update(doc.reference, {'userName': userName});
        }
        await batch.commit();
      }

      AppLogger.success('ユーザー情報更新完了', tag: 'UserService');
      return true;
    } catch (e) {
      AppLogger.error('ユーザー情報更新エラー: $e', tag: 'UserService');
      return false;
    }
  }
}