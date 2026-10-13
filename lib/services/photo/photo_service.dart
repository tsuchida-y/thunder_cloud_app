import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gal/gal.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../constants/app_constants.dart';
import '../../models/photo.dart';
import '../../utils/logger.dart';
import '../location/location_service.dart';

/// 写真管理サービスクラス
/// 写真のアップロード、共有、取得、削除機能を提供
/// Firebase Storage と Firestore を使用した統合管理
class PhotoService {
  /*
  ================================================================================
                                    依存関係
                         外部サービスとの接続とインスタンス
  ================================================================================
  */
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /*
  ================================================================================
                                写真アップロード機能
                        写真の投稿と共有機能の実装
  ================================================================================
  */

  /// 写真をアップロードして共有
  /// 位置情報の取得、画像アップロード、Firestoreへの保存を実行
  ///
  /// [imageFile] アップロードする画像ファイル
  /// [userId] ユーザーID
  /// [userName] ユーザー名
  /// [caption] 写真のキャプション（オプション）
  /// [tags] 写真のタグ（オプション）
  /// Returns: アップロード成功時はtrue
  static Future<bool> uploadPhoto({
    required File imageFile,
    required String userId,
    required String userName,
    String? caption,
    List<String>? tags,
  }) async {
    try {
      // ステップ1: 現在の位置情報を取得
      final location = await LocationService.getCurrentLocationAsLatLng();
      if (location == null) {
        AppLogger.error('位置情報が取得できません', tag: 'PhotoService');
        return false;
      }

      // ステップ2: 地名を取得（簡易版）
      final locationName = await _getLocationName(location);

      // ステップ3: 座標を小数点2位に丸める（プライバシー保護）
      final roundedLatitude = AppConstants.roundCoordinate(location.latitude);
      final roundedLongitude = AppConstants.roundCoordinate(location.longitude);

      // ステップ4: Firebase Storageに画像をアップロード
      final imageUrl = await _uploadImageToStorage(imageFile, userId);
      if (imageUrl == null) {
        AppLogger.error('画像アップロードに失敗しました', tag: 'PhotoService');
        return false;
      }

      // ステップ5: サムネイル画像を作成・アップロード（同じ画像を使用、実際にはリサイズ版を作成）
      final thumbnailUrl = imageUrl; // 簡易版

      // ステップ6: Firestoreに写真データを保存（30日間のTTL付き）
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

      // ステップ7: 写真データにTTLを追加
      final photoData = photo.toMap();
      photoData['expiresAt'] = Timestamp.fromDate(now.add(const Duration(days: 30))); // 30日後に期限切れ

      await _firestore.collection('photos').doc(photoId).set(photoData);

      return true;
    } catch (e) {
      AppLogger.error('写真アップロードエラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /*
  ================================================================================
                                Storage操作機能
                        Firebase Storageでの画像管理
  ================================================================================
  */

  /// Firebase Storageに画像をアップロード
  /// ユーザーIDごとのディレクトリに画像を保存
  ///
  /// [imageFile] アップロードする画像ファイル
  /// [userId] ユーザーID
  /// Returns: アップロード成功時はダウンロードURL
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

  /*
  ================================================================================
                                位置情報処理機能
                        地名取得とジオコーディング
  ================================================================================
  */

  /// 地名を取得（簡易版）
  /// 座標から地名を取得する機能（実際のアプリでは Geocoding API を使用）
  ///
  /// [location] 位置座標
  /// Returns: 地名文字列
  static Future<String> _getLocationName(LatLng location) async {
    // 実際のアプリでは Geocoding API を使用
    // ここでは簡易的に座標を文字列として返す
    return '撮影地点'; // 座標は非表示にして一般的な名前を使用
  }

  /*
  ================================================================================
                                写真取得機能
                        公開写真の取得とフィルタリング
  ================================================================================
  */

  /// 公開写真一覧を取得（期限切れ除外）
  /// 期限切れ写真のクライアントサイドフィルタリングを実行
  ///
  /// [limit] 取得する写真の最大数
  /// [lastDocument] ページネーション用の最後のドキュメント
  /// [startAfterTimestamp] ページネーション用の最後の写真の投稿日時（lastDocumentがない場合に使用）
  /// Returns: 写真データのリスト
  static Future<List<Photo>> getPublicPhotos({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    DateTime? startAfterTimestamp,
  }) async {
    try {
      // ステップ1: 全ての公開写真を取得してからクライアントサイドで期限切れをフィルタリング
      // （マイグレーション期間中は既存写真にexpiresAtが存在しないため）
      Query query = _firestore
          .collection('photos')
          .where('isPublic', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(limit * 2); // 期限切れフィルタリングのため多めに取得

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      } else if (startAfterTimestamp != null) {
        query = query.startAfter([Timestamp.fromDate(startAfterTimestamp)]);
      }

      final snapshot = await query.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.error('Firestoreクエリタイムアウト', tag: 'PhotoService');
          throw TimeoutException('Firestore query timeout', const Duration(seconds: 10));
        },
      );

      // ステップ2: クライアントサイドで期限切れフィルタリング
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

      // ステップ3: 期限切れ写真のクリーンアップを非同期で実行
      if (validPhotos.isEmpty) {
        _cleanupExpiredPhotosAsync();
      }

      final photos = validPhotos.map((doc) => Photo.fromDocument(doc)).toList();
      return photos;
    } catch (e) {
      AppLogger.error('公開写真取得エラー: $e', tag: 'PhotoService');
      return [];
    }
  }

  /*
  ================================================================================
                                期限切れ写真管理
                        期限切れ写真の検出と削除
  ================================================================================
  */

  /// 期限切れ写真の非同期クリーンアップ
  /// バックグラウンドで期限切れ写真を削除
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

  /// 期限切れ写真を削除（Storage + Firestore）
  /// 画像ファイルとFirestoreドキュメントを削除（いいねは写真と一緒に削除される）
  ///
  /// [doc] 削除する写真のドキュメント
  static Future<void> _deleteExpiredPhoto(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final imageUrl = data['imageUrl'] as String?;

      // ステップ1: Firebase Storageから画像を削除
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          AppLogger.warning('Storage削除エラー: $e', tag: 'PhotoService');
        }
      }

      // ステップ2: Firestoreから写真データを削除（いいね情報も一緒に削除される）
      await doc.reference.delete();
    } catch (e) {
      AppLogger.error('期限切れ写真削除エラー: ${doc.id} - $e', tag: 'PhotoService');
    }
  }

  /*
  ================================================================================
                                ユーザー写真管理
                        ユーザー固有の写真取得機能
  ================================================================================
  */

  /// ユーザーの写真一覧を取得
  /// 指定されたユーザーIDの写真を時系列順で取得
  ///
  /// [userId] ユーザーID
  /// Returns: ユーザーの写真データリスト
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

  /*
  ================================================================================
                                いいね機能
                        写真のいいね追加・削除・状態確認
  ================================================================================
  */

  /// 写真にいいねを追加
  /// シンプルな配列ベースの実装でパフォーマンスと可読性を向上
  ///
  /// [photoId] 写真ID
  /// [userId] ユーザーID
  /// Returns: 更新された写真オブジェクト（成功時）、null（失敗時）
  static Future<Photo?> likePhoto(String photoId, String userId) async {
    try {
      AppLogger.info('いいね追加開始: $photoId', tag: 'PhotoService');

      // ステップ1: 写真の存在確認
      final photoDoc = await _firestore.collection('photos').doc(photoId).get();
      if (!photoDoc.exists) {
        AppLogger.error('写真が見つかりません: $photoId', tag: 'PhotoService');
        return null;
      }

      // ステップ2: 現在のいいね状態をチェック
      final photo = Photo.fromDocument(photoDoc);
      if (photo.isLikedByUser(userId)) {
        AppLogger.info('既にいいね済みです: $photoId', tag: 'PhotoService');
        return photo; // 既にいいね済みの場合は現在の状態を返す
      }

      // ステップ3: いいねを追加（アトミック操作）
      await _firestore.collection('photos').doc(photoId).update({
        'likedBy': FieldValue.arrayUnion([userId]),
        'likes': FieldValue.increment(1),
      });

      // ステップ4: 更新後の写真データを取得
      final updatedDoc = await _firestore.collection('photos').doc(photoId).get();
      if (updatedDoc.exists) {
        final updatedPhoto = Photo.fromDocument(updatedDoc);
        AppLogger.success('いいね追加完了: $photoId (いいね数: ${updatedPhoto.likes})', tag: 'PhotoService');
        return updatedPhoto;
      }

      return null;
    } catch (e) {
      AppLogger.error('いいね追加エラー: $photoId - $e', tag: 'PhotoService');
      return null;
    }
  }

  /// 写真のいいねを削除
  /// シンプルな配列ベースの実装でパフォーマンスと可読性を向上
  ///
  /// [photoId] 写真ID
  /// [userId] ユーザーID
  /// Returns: 更新された写真オブジェクト（成功時）、null（失敗時）
  static Future<Photo?> unlikePhoto(String photoId, String userId) async {
    try {
      AppLogger.info('いいね削除開始: $photoId', tag: 'PhotoService');

      // ステップ1: 写真の存在確認
      final photoDoc = await _firestore.collection('photos').doc(photoId).get();
      if (!photoDoc.exists) {
        AppLogger.error('写真が見つかりません: $photoId', tag: 'PhotoService');
        return null;
      }

      // ステップ2: 現在のいいね状態をチェック
      final photo = Photo.fromDocument(photoDoc);
      if (!photo.isLikedByUser(userId)) {
        AppLogger.info('いいねしていません: $photoId', tag: 'PhotoService');
        return photo; // いいねしていない場合は現在の状態を返す
      }

      // ステップ3: いいねを削除（アトミック操作）
      await _firestore.collection('photos').doc(photoId).update({
        'likedBy': FieldValue.arrayRemove([userId]),
        'likes': FieldValue.increment(-1),
      });

      // ステップ4: 更新後の写真データを取得
      final updatedDoc = await _firestore.collection('photos').doc(photoId).get();
      if (updatedDoc.exists) {
        final updatedPhoto = Photo.fromDocument(updatedDoc);
        AppLogger.success('いいね削除完了: $photoId (いいね数: ${updatedPhoto.likes})', tag: 'PhotoService');
        return updatedPhoto;
      }

      return null;
    } catch (e) {
      AppLogger.error('いいね削除エラー: $photoId - $e', tag: 'PhotoService');
      return null;
    }
  }

  /// ユーザーが写真にいいねしているかチェック
  /// Photoオブジェクトから直接判定するシンプルな実装
  ///
  /// [photo] 写真オブジェクト
  /// [userId] ユーザーID
  /// Returns: いいね状態（true=いいね済み）
  static bool isPhotoLikedByUser(Photo photo, String userId) {
    return photo.isLikedByUser(userId);
  }

  /// 写真のいいね状態を一括取得（最適化版）
  /// 写真データと一緒に取得されるため、追加のクエリが不要
  ///
  /// [photos] 写真オブジェクトのリスト
  /// [userId] ユーザーID
  /// Returns: 写真IDをキーとしたいいね状態マップ
  static Map<String, bool> getPhotosLikeStatus(List<Photo> photos, String userId) {
      final likeStatus = <String, bool>{};

    for (final photo in photos) {
      likeStatus[photo.id] = photo.isLikedByUser(userId);
      }

      AppLogger.info('いいね状態一括取得完了: ${likeStatus.length}件', tag: 'PhotoService');
      return likeStatus;
  }

  /*
  ================================================================================
                                写真削除機能
                        写真の削除と関連データのクリーンアップ
  ================================================================================
  */

  /// 写真を削除
  /// 権限チェック、Storage削除、Firestore削除を実行（いいねは写真と一緒に削除される）
  ///
  /// [photoId] 写真ID
  /// [userId] ユーザーID
  /// Returns: 削除成功時はtrue
  static Future<bool> deletePhoto(String photoId, String userId) async {
    try {
      // ステップ1: 権限確認
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

      // ステップ2: Firebase Storageから画像を削除
      try {
        final ref = _storage.refFromURL(photo.imageUrl);
        await ref.delete();
      } catch (e) {
        AppLogger.warning('画像ファイル削除エラー: $e', tag: 'PhotoService');
      }

      // ステップ3: Firestoreから写真データを削除（いいね情報も一緒に削除される）
      await _firestore.collection('photos').doc(photoId).delete();

      AppLogger.success('写真削除完了: $photoId', tag: 'PhotoService');
      return true;
    } catch (e) {
      AppLogger.error('写真削除エラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /*
  ================================================================================
                                写真ダウンロード機能
                        写真の端末保存とダウンロード管理
  ================================================================================
  */

  /// 写真をダウンロードして端末ギャラリーに保存
  /// 画像をダウンロードし、端末のギャラリーに保存
  ///
  /// [photo] 写真データ
  /// [currentUserId] 現在のユーザーID
  /// Returns: ダウンロード成功時はtrue
static Future<bool> downloadPhoto(Photo photo, String currentUserId) async {
  try {
    AppLogger.info('📥 写真ダウンロード開始: ${photo.id}', tag: 'PhotoService');

    // ステップ1: 画像をダウンロード
    final response = await http.get(Uri.parse(photo.imageUrl));
    if (response.statusCode != 200) {
      AppLogger.error('❌ 画像ダウンロード失敗: ${response.statusCode}', tag: 'PhotoService');
      return false;
    }

    // ステップ2: 端末のギャラリーに保存
    final Uint8List imageBytes = response.bodyBytes;

    // 変更前
    // final result = await ImageGallerySaver.saveImage(
    //   imageBytes,
    //   name: 'thunder_cloud_${photo.id}_${DateTime.now().millisecondsSinceEpoch}',
    //   quality: 100,
    // );

    // 変更後
    await Gal.putImageBytes(
      imageBytes,
      name: 'thunder_cloud_${photo.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    AppLogger.success('✅ 写真ダウンロード完了: ${photo.id}', tag: 'PhotoService');
    return true;

    // 変更前の結果チェック部分を削除
    // if (result['isSuccess'] == true) {
    //   AppLogger.success('✅ 写真ダウンロード完了: ${photo.id}', tag: 'PhotoService');
    //   return true;
    // } else {
    //   AppLogger.error('❌ 端末ギャラリーへの保存に失敗: ${photo.id}', tag: 'PhotoService');
    //   return false;
    // }
  } catch (e) {
    AppLogger.error('写真ダウンロードエラー: $e', tag: 'PhotoService');
    return false;
  }
}

  /*
  ================================================================================
                                ダウンロード状態管理
                        ダウンロード済み写真の管理と確認
  ================================================================================
  */

  /// 写真がダウンロード済みかチェック（プライベート）
  /// 内部使用のためのダウンロード状態確認
  ///
  /// [photoId] 写真ID
  /// [userId] ユーザーID
  /// Returns: ダウンロード済みの場合はtrue
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
  /// 外部からのダウンロード状態確認
  ///
  /// [photoId] 写真ID
  /// [userId] ユーザーID
  /// Returns: ダウンロード済みの場合はtrue
  static Future<bool> isPhotoDownloaded(String photoId, String userId) async {
    return _isPhotoDownloaded(photoId, userId);
  }

  /// ダウンロード済み写真一覧を取得
  /// ユーザーがダウンロードした写真の一覧を取得
  ///
  /// [userId] ユーザーID
  /// Returns: ダウンロード済み写真の情報リスト
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

  /// ダウンロード済み写真をローカルファイルとFirestoreから削除
  ///
  /// [downloadId] ダウンロードID
  /// [userId] ユーザーID
  /// Returns: 削除成功時はtrue
  static Future<bool> deleteDownloadedPhoto(String downloadId, String userId) async {
    try {
      // ステップ1: ダウンロード情報を取得
      final doc = await _firestore.collection('downloads').doc(downloadId).get();
      if (!doc.exists) {
        return false;
      }

      final data = doc.data()!;
      if (data['downloadedBy'] != userId) {
        AppLogger.error('削除権限がありません: $downloadId', tag: 'PhotoService');
        return false;
      }

      // ステップ2: ローカルファイルを削除
      final localPath = data['localPath'] as String;
      final localFile = File(localPath);
      if (await localFile.exists()) {
        await localFile.delete();
      }

      // ステップ3: Firestoreから削除
      await doc.reference.delete();

      AppLogger.success('✅ ダウンロード済み写真削除完了: $downloadId', tag: 'PhotoService');
      return true;
    } catch (e) {
      AppLogger.error('ダウンロード済み写真削除エラー: $e', tag: 'PhotoService');
      return false;
    }
  }
}