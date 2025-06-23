import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';

import '../../constants/app_constants.dart';
import '../../models/photo.dart';
import '../../utils/logger.dart';
import '../location/location_service.dart';

class PhotoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 写真をアップロードして共有
  static Future<bool> uploadPhoto({
    required File imageFile,
    required String userId,
    required String userName,
    String? caption,
    List<String>? tags,
  }) async {
    try {
      // 現在の位置情報を取得
      final location = await LocationService.getCurrentLocationAsLatLng();
      if (location == null) {
        AppLogger.error('位置情報が取得できません', tag: 'PhotoService');
        return false;
      }

      // 地名を取得（簡易版）
      final locationName = await _getLocationName(location);

      // 座標を小数点2位に丸める（プライバシー保護）
      final roundedLatitude = AppConstants.roundCoordinate(location.latitude);
      final roundedLongitude = AppConstants.roundCoordinate(location.longitude);

      // Firebase Storageに画像をアップロード
      final imageUrl = await _uploadImageToStorage(imageFile, userId);
      if (imageUrl == null) {
        AppLogger.error('画像アップロードに失敗しました', tag: 'PhotoService');
        return false;
      }

      // サムネイル画像を作成・アップロード（同じ画像を使用、実際にはリサイズ版を作成）
      final thumbnailUrl = imageUrl; // 簡易版

      // Firestoreに写真データを保存（30日間のTTL付き）
      final photoId = _firestore.collection('photos').doc().id;
      final now = DateTime.now();
      final photo = Photo(
        id: photoId,
        userId: userId,
        userName: userName,
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        latitude: roundedLatitude,
        longitude: roundedLongitude,
        locationName: locationName,
        timestamp: now,
        weatherData: {},
        tags: tags ?? [],
      );

      // 写真データにTTLを追加
      final photoData = photo.toMap();
      photoData['expiresAt'] = Timestamp.fromDate(now.add(const Duration(days: 30))); // 30日後に期限切れ

      await _firestore.collection('photos').doc(photoId).set(photoData);

      return true;
    } catch (e) {
      AppLogger.error('写真アップロードエラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// Firebase Storageに画像をアップロード
  static Future<String?> _uploadImageToStorage(File imageFile, String userId) async {
    try {
      final fileName = 'thunder_cloud_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('photos').child(userId).child(fileName);

      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      AppLogger.error('画像アップロードエラー: $e', tag: 'PhotoService');
      return null;
    }
  }

  /// 地名を取得（簡易版）
  static Future<String> _getLocationName(LatLng location) async {
    // 実際のアプリでは Geocoding API を使用
    // ここでは簡易的に座標を文字列として返す
    return '撮影地点'; // 座標は非表示にして一般的な名前を使用
  }

  /// 公開写真一覧を取得（期限切れ除外）
  static Future<List<Photo>> getPublicPhotos({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      // まず全ての公開写真を取得してからクライアントサイドで期限切れをフィルタリング
      // （マイグレーション期間中は既存写真にexpiresAtが存在しないため）
      Query query = _firestore
          .collection('photos')
          .where('isPublic', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(limit * 2); // 期限切れフィルタリングのため多めに取得

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.error('Firestoreクエリタイムアウト', tag: 'PhotoService');
          throw TimeoutException('Firestore query timeout', const Duration(seconds: 10));
        },
      );

      // クライアントサイドで期限切れフィルタリング
      final now = DateTime.now();
      final validPhotos = <DocumentSnapshot>[];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

        // expiresAtが存在しない場合（マイグレーション前）またはまだ期限切れでない場合
        if (expiresAt == null || now.isBefore(expiresAt)) {
          validPhotos.add(doc);
          if (validPhotos.length >= limit) break; // 必要な件数に達したら終了
        }
      }

      if (validPhotos.isEmpty) {
        // 期限切れ写真のクリーンアップを非同期で実行
        _cleanupExpiredPhotosAsync();
      }

      final photos = validPhotos.map((doc) => Photo.fromDocument(doc)).toList();
      return photos;
    } catch (e) {
      AppLogger.error('公開写真取得エラー: $e', tag: 'PhotoService');
      return [];
    }
  }

  /// 期限切れ写真の非同期クリーンアップ
  static void _cleanupExpiredPhotosAsync() {
    // バックグラウンドで期限切れ写真を削除
    Future.delayed(Duration.zero, () async {
      try {
        final expiredSnapshot = await _firestore
            .collection('photos')
            .where('expiresAt', isLessThanOrEqualTo: Timestamp.now())
            .limit(10) // 一度に最大10件
            .get();

        if (expiredSnapshot.docs.isNotEmpty) {
          for (var doc in expiredSnapshot.docs) {
            await _deleteExpiredPhoto(doc);
          }
        }
      } catch (e) {
        AppLogger.error('期限切れ写真クリーンアップエラー: $e', tag: 'PhotoService');
      }
    });
  }

  /// 期限切れ写真を削除（Storage + Firestore + 関連データ）
  static Future<void> _deleteExpiredPhoto(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final imageUrl = data['imageUrl'] as String?;

      // Firebase Storageから画像を削除
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          AppLogger.warning('Storage削除エラー: $e', tag: 'PhotoService');
        }
      }

      // 関連するいいねを削除
      await _deleteRelatedLikes(doc.id);

      // Firestoreから写真データを削除
      await doc.reference.delete();
    } catch (e) {
      AppLogger.error('期限切れ写真削除エラー: ${doc.id} - $e', tag: 'PhotoService');
    }
  }

  /// ユーザーの写真一覧を取得
  static Future<List<Photo>> getUserPhotos(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('photos')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      final photos = snapshot.docs.map((doc) => Photo.fromDocument(doc)).toList();
      return photos;
    } catch (e) {
      AppLogger.error('ユーザー写真取得エラー: $e', tag: 'PhotoService');
      return [];
    }
  }

  /// 写真にいいねを追加
  static Future<bool> likePhoto(String photoId, String userId) async {
    try {
      // 既にいいねしているかチェック
      final isAlreadyLiked = await isPhotoLikedByUser(photoId, userId);
      if (isAlreadyLiked) {
        AppLogger.warning('既にいいね済み: $photoId', tag: 'PhotoService');
        return false;
      }

      // いいね情報を保存（TTL付きで30日後に自動削除）
      final likeId = '${photoId}_$userId';
      final like = {
        'photoId': photoId,
        'userId': userId,
        'timestamp': DateTime.now(),
        'expiresAt': DateTime.now().add(const Duration(days: 30)), // 30日後に期限切れ
      };

      await _firestore.collection('likes').doc(likeId).set(like);

      // 写真のいいね数を更新
      await _firestore.collection('photos').doc(photoId).update({
        'likes': FieldValue.increment(1),
      });

      AppLogger.info('いいね追加: $photoId', tag: 'PhotoService');
      return true;
    } catch (e) {
      AppLogger.error('いいね追加エラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// 写真のいいねを削除
  static Future<bool> unlikePhoto(String photoId, String userId) async {
    try {
      // いいねしているかチェック
      final isLiked = await isPhotoLikedByUser(photoId, userId);
      if (!isLiked) {
        AppLogger.warning('いいねしていません: $photoId', tag: 'PhotoService');
        return false;
      }

      final likeId = '${photoId}_$userId';
      await _firestore.collection('likes').doc(likeId).delete();

      // 写真のいいね数を更新
      await _firestore.collection('photos').doc(photoId).update({
        'likes': FieldValue.increment(-1),
      });

      AppLogger.info('いいね削除: $photoId', tag: 'PhotoService');
      return true;
    } catch (e) {
      AppLogger.error('いいね削除エラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// ユーザーが写真にいいねしているかチェック
  static Future<bool> isPhotoLikedByUser(String photoId, String userId) async {
    try {
      final likeId = '${photoId}_$userId';
      final doc = await _firestore.collection('likes').doc(likeId).get();

      if (!doc.exists) {
        return false;
      }

      // 期限切れチェック（クライアントサイドでも確認）
      final data = doc.data() as Map<String, dynamic>;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        // 期限切れの場合は削除
        await doc.reference.delete();
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('いいね状態確認エラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// 写真のいいね状態を一括取得（最適化版）
  static Future<Map<String, bool>> getPhotosLikeStatus(List<String> photoIds, String userId) async {
    try {
      final likeStatus = <String, bool>{};

      if (photoIds.isEmpty) {
        return likeStatus;
      }

      // 全ての写真を未いいね状態で初期化
      for (String photoId in photoIds) {
        likeStatus[photoId] = false;
      }

      // バッチでいいね状態を確認（最大10件ずつ）
      const batchSize = 10;
      for (int i = 0; i < photoIds.length; i += batchSize) {
        final batch = photoIds.skip(i).take(batchSize).toList();
        final likeIds = batch.map((photoId) => '${photoId}_$userId').toList();

        // whereIn クエリを使用して効率的に取得
        final likesSnapshot = await _firestore
            .collection('likes')
            .where(FieldPath.documentId, whereIn: likeIds)
            .get();

        final now = DateTime.now();
        for (var doc in likesSnapshot.docs) {
          final data = doc.data();
          final photoId = data['photoId'] as String;

          // 期限切れチェック
          final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
          if (expiresAt != null && now.isAfter(expiresAt)) {
            // 期限切れの場合は削除（バックグラウンドで）
            doc.reference.delete().catchError((e) {
              AppLogger.warning('期限切れいいね削除エラー: $e', tag: 'PhotoService');
            });
            continue;
          }

          if (batch.contains(photoId)) {
            likeStatus[photoId] = true;
          }
        }
      }

      AppLogger.info('いいね状態一括取得完了: ${likeStatus.length}件', tag: 'PhotoService');
      return likeStatus;
    } catch (e) {
      AppLogger.error('いいね状態一括取得エラー: $e', tag: 'PhotoService');
      // エラー時は全て未いいね状態で返す
      final likeStatus = <String, bool>{};
      for (String photoId in photoIds) {
        likeStatus[photoId] = false;
      }
      return likeStatus;
    }
  }

  /// 写真を削除
  static Future<bool> deletePhoto(String photoId, String userId) async {
    try {
      // 権限確認
      final photoDoc = await _firestore.collection('photos').doc(photoId).get();
      if (!photoDoc.exists) {
        AppLogger.error('写真が見つかりません: $photoId', tag: 'PhotoService');
        return false;
      }

      final photo = Photo.fromDocument(photoDoc);
      if (photo.userId != userId) {
        AppLogger.error('写真削除権限がありません: $photoId', tag: 'PhotoService');
        return false;
      }

      // Firebase Storageから画像を削除
      try {
        final ref = _storage.refFromURL(photo.imageUrl);
        await ref.delete();
      } catch (e) {
        AppLogger.warning('画像ファイル削除エラー: $e', tag: 'PhotoService');
      }

      // Firestoreから写真データを削除
      await _firestore.collection('photos').doc(photoId).delete();

      // 関連するいいねを削除
      await _deleteRelatedLikes(photoId);

      AppLogger.success('写真削除完了: $photoId', tag: 'PhotoService');
      return true;
    } catch (e) {
      AppLogger.error('写真削除エラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// 関連するいいねを削除
  static Future<void> _deleteRelatedLikes(String photoId) async {
    try {
      // いいねを削除
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('photoId', isEqualTo: photoId)
          .get();

      for (final doc in likesSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      AppLogger.error('関連いいね削除エラー: $e', tag: 'PhotoService');
    }
  }

  /// 写真をダウンロードして端末ギャラリーに保存
  static Future<bool> downloadPhoto(Photo photo, String currentUserId) async {
    try {
      AppLogger.info('📥 写真ダウンロード開始: ${photo.id}', tag: 'PhotoService');

      // 画像をダウンロード
      final response = await http.get(Uri.parse(photo.imageUrl));
      if (response.statusCode != 200) {
        AppLogger.error('❌ 画像ダウンロード失敗: ${response.statusCode}', tag: 'PhotoService');
        return false;
      }

      // 端末のギャラリーに保存
      final Uint8List imageBytes = response.bodyBytes;
      final result = await ImageGallerySaver.saveImage(
        imageBytes,
        name: 'thunder_cloud_${photo.id}_${DateTime.now().millisecondsSinceEpoch}',
        quality: 100,
      );

      if (result['isSuccess'] == true) {
        AppLogger.success('✅ 写真ダウンロード完了: ${photo.id}', tag: 'PhotoService');
        return true;
      } else {
        AppLogger.error('❌ 端末ギャラリーへの保存に失敗: ${photo.id}', tag: 'PhotoService');
        return false;
      }
    } catch (e) {
      AppLogger.error('写真ダウンロードエラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// 写真がダウンロード済みかチェック（プライベート）
  static Future<bool> _isPhotoDownloaded(String photoId, String userId) async {
    try {
      final doc = await _firestore
          .collection('downloads')
          .doc('${photoId}_$userId')
          .get();
      return doc.exists;
    } catch (e) {
      AppLogger.error('ダウンロード状況確認エラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// 写真がダウンロード済みかチェック（パブリック）
  static Future<bool> isPhotoDownloaded(String photoId, String userId) async {
    return _isPhotoDownloaded(photoId, userId);
  }

  /// ダウンロード済み写真一覧を取得
  static Future<List<Map<String, dynamic>>> getDownloadedPhotos(String userId) async {
    try {
      AppLogger.info('📥 ダウンロード済み写真取得開始 - ユーザーID: $userId', tag: 'PhotoService');

      final snapshot = await _firestore
          .collection('downloads')
          .where('downloadedBy', isEqualTo: userId)
          .orderBy('downloadedAt', descending: true)
          .get();

      final downloadedPhotos = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final localPath = data['localPath'] as String;

        // ローカルファイルが存在するかチェック
        if (await File(localPath).exists()) {
          downloadedPhotos.add({
            ...data,
            'id': doc.id,
            'localImagePath': localPath,
          });
        } else {
          // ファイルが存在しない場合はダウンロード情報を削除
          await doc.reference.delete();
          AppLogger.warning('🗑️ 存在しないファイルの情報を削除: $localPath', tag: 'PhotoService');
        }
      }

      AppLogger.success('✅ ダウンロード済み写真取得完了: ${downloadedPhotos.length}件', tag: 'PhotoService');
      return downloadedPhotos;
    } catch (e) {
      AppLogger.error('ダウンロード済み写真取得エラー: $e', tag: 'PhotoService');
      return [];
    }
  }

  /// ダウンロード済み写真を削除
  static Future<bool> deleteDownloadedPhoto(String downloadId, String userId) async {
    try {
      final doc = await _firestore.collection('downloads').doc(downloadId).get();
      if (!doc.exists) {
        return false;
      }

      final data = doc.data()!;
      if (data['downloadedBy'] != userId) {
        AppLogger.error('削除権限がありません: $downloadId', tag: 'PhotoService');
        return false;
      }

      // ローカルファイルを削除
      final localPath = data['localPath'] as String;
      final localFile = File(localPath);
      if (await localFile.exists()) {
        await localFile.delete();
      }

      // Firestoreから削除
      await doc.reference.delete();

      AppLogger.success('✅ ダウンロード済み写真削除完了: $downloadId', tag: 'PhotoService');
      return true;
    } catch (e) {
      AppLogger.error('ダウンロード済み写真削除エラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// 既存写真にexpiresAtフィールドを追加するマイグレーション
  static Future<void> migrateExistingPhotos() async {
    try {
      AppLogger.info('🔄 既存写真のマイグレーション開始', tag: 'PhotoService');

      // expiresAtフィールドが存在しない写真を検索
      final snapshot = await _firestore
          .collection('photos')
          .get();

      int migrated = 0;
      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // expiresAtフィールドが存在しない場合のみ追加
        if (!data.containsKey('expiresAt')) {
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          final expiresAt = timestamp.add(const Duration(days: 30));

          batch.update(doc.reference, {
            'expiresAt': Timestamp.fromDate(expiresAt),
          });

          migrated++;
          AppLogger.info('📝 マイグレーション対象: ${doc.id} - 期限: $expiresAt', tag: 'PhotoService');
        }
      }

      if (migrated > 0) {
        await batch.commit();
        AppLogger.success('✅ 既存写真マイグレーション完了: $migrated件', tag: 'PhotoService');
      } else {
        AppLogger.info('ℹ️ マイグレーション対象の写真なし', tag: 'PhotoService');
      }

    } catch (e) {
      AppLogger.error('既存写真マイグレーションエラー: $e', tag: 'PhotoService');
    }
  }
}