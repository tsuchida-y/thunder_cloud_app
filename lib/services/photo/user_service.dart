import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/logger.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();

  /// ユーザー情報を取得
  static Future<Map<String, dynamic>> getUserInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        return doc.data() ?? {};
      } else {
        // デフォルトユーザー情報を作成
        final defaultUserInfo = {
          'userId': userId,
          'userName': 'ユーザー',
          'avatarUrl': '',
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        };

        await _firestore.collection('users').doc(userId).set(defaultUserInfo);
        return defaultUserInfo;
      }
    } catch (e) {
      AppLogger.error('ユーザー情報取得エラー: $e', tag: 'UserService');
      return {
        'userId': userId,
        'userName': 'ユーザー',
        'avatarUrl': '',
      };
    }
  }

  /// ユーザー名を更新
  static Future<bool> updateUserName(String userId, String newName) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'userName': newName,
        'updatedAt': DateTime.now(),
      });

      // 既存の写真の userName も更新
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

  /// アバター画像を更新
  static Future<bool> updateUserAvatar(String userId) async {
    try {
      // 画像選択
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 80,
      );

      if (image == null) {
        AppLogger.info('画像選択がキャンセルされました', tag: 'UserService');
        return false;
      }

      // Firebase Storageにアップロード
      final File imageFile = File(image.path);
      final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('avatars').child(fileName);

      AppLogger.info('アバター画像アップロード開始', tag: 'UserService');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Firestoreのユーザー情報を更新
      await _firestore.collection('users').doc(userId).update({
        'avatarUrl': downloadUrl,
        'updatedAt': DateTime.now(),
      });

      AppLogger.success('アバター画像更新完了: $downloadUrl', tag: 'UserService');
      return true;
    } catch (e) {
      AppLogger.error('アバター画像更新エラー: $e', tag: 'UserService');
      return false;
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