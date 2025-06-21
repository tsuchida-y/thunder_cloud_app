import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../models/photo.dart';
import '../../utils/logger.dart';
import '../location/location_service.dart';
import '../weather/weather_data_service.dart';

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
      AppLogger.info('写真アップロード開始', tag: 'PhotoService');

      // 現在の位置情報を取得
      final location = await LocationService.getCurrentLocationAsLatLng();
      if (location == null) {
        AppLogger.error('位置情報が取得できません', tag: 'PhotoService');
        return false;
      }

      // 現在の気象データを取得
      final weatherDataService = WeatherDataService.instance;
      await weatherDataService.fetchAndStoreWeatherData(location);
      final weatherData = weatherDataService.lastWeatherData;

      // 地名を取得（簡易版）
      final locationName = await _getLocationName(location);

      // Firebase Storageに画像をアップロード
      final imageUrl = await _uploadImageToStorage(imageFile, userId);
      if (imageUrl == null) {
        AppLogger.error('画像アップロードに失敗しました', tag: 'PhotoService');
        return false;
      }

      // サムネイル画像を作成・アップロード（同じ画像を使用、実際にはリサイズ版を作成）
      final thumbnailUrl = imageUrl; // 簡易版

      // Firestoreに写真データを保存
      final photoId = _firestore.collection('photos').doc().id;
      final photo = Photo(
        id: photoId,
        userId: userId,
        userName: userName,
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        latitude: location.latitude,
        longitude: location.longitude,
        locationName: locationName,
        timestamp: DateTime.now(),
        weatherData: weatherData,
        tags: tags ?? [],
      );

      await _firestore.collection('photos').doc(photoId).set(photo.toMap());

      AppLogger.success('写真アップロード完了: $photoId', tag: 'PhotoService');
      return true;
    } catch (e) {
      AppLogger.error('写真アップロードエラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// Firebase Storageに画像をアップロード
  static Future<String?> _uploadImageToStorage(File imageFile, String userId) async {
    try {
      AppLogger.info('Firebase Storage アップロード開始', tag: 'PhotoService');
      AppLogger.info('ファイルパス: ${imageFile.path}', tag: 'PhotoService');
      AppLogger.info('ファイルサイズ: ${await imageFile.length()} bytes', tag: 'PhotoService');

      final fileName = 'thunder_cloud_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('photos').child(userId).child(fileName);

      AppLogger.info('Storage参照パス: photos/$userId/$fileName', tag: 'PhotoService');

      final uploadTask = ref.putFile(imageFile);
      AppLogger.info('アップロードタスク開始', tag: 'PhotoService');

      final snapshot = await uploadTask;
      AppLogger.info('アップロード完了、ダウンロードURL取得中...', tag: 'PhotoService');

      final downloadUrl = await snapshot.ref.getDownloadURL();
      AppLogger.success('画像アップロード完了: $downloadUrl', tag: 'PhotoService');
      return downloadUrl;
    } catch (e) {
      AppLogger.error('画像アップロードエラー: $e', tag: 'PhotoService');
      AppLogger.error('エラータイプ: ${e.runtimeType}', tag: 'PhotoService');

      // Firebase関連のエラーを詳細に出力
      if (e.toString().contains('permission')) {
        AppLogger.error('権限エラー: Firebase Storage の権限設定を確認してください', tag: 'PhotoService');
      } else if (e.toString().contains('network')) {
        AppLogger.error('ネットワークエラー: インターネット接続を確認してください', tag: 'PhotoService');
      } else if (e.toString().contains('quota')) {
        AppLogger.error('容量エラー: Firebase Storage の容量制限に達しています', tag: 'PhotoService');
      }

      return null;
    }
  }

  /// 地名を取得（簡易版）
  static Future<String> _getLocationName(LatLng location) async {
    // 実際のアプリでは Geocoding API を使用
    // ここでは簡易的に座標を文字列として返す
    return '撮影地点'; // 座標は非表示にして一般的な名前を使用
  }

  /// 公開写真一覧を取得
  static Future<List<Photo>> getPublicPhotos({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      AppLogger.info('📸 公開写真取得開始 - limit: $limit', tag: 'PhotoService');

      Query query = _firestore
          .collection('photos')
          .where('isPublic', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
        AppLogger.info('📄 ページネーション: 前のドキュメントから継続', tag: 'PhotoService');
      }

      AppLogger.info('🔍 Firestoreクエリ実行中...', tag: 'PhotoService');
      final snapshot = await query.get();

      AppLogger.info('📊 クエリ結果: ${snapshot.docs.length}件のドキュメント取得', tag: 'PhotoService');

      if (snapshot.docs.isEmpty) {
        AppLogger.warning('⚠️ 公開写真が見つかりません', tag: 'PhotoService');

        // 全写真数を確認
        final allPhotosSnapshot = await _firestore.collection('photos').get();
        AppLogger.info('📈 全写真数: ${allPhotosSnapshot.docs.length}件', tag: 'PhotoService');

        // isPublicフィールドの状況を確認
        for (var doc in allPhotosSnapshot.docs.take(5)) {
          final data = doc.data();
          AppLogger.info('📋 写真データ例: ${doc.id} - isPublic: ${data['isPublic']}, timestamp: ${data['timestamp']}', tag: 'PhotoService');
        }
      } else {
        AppLogger.success('✅ 公開写真取得成功: ${snapshot.docs.length}件', tag: 'PhotoService');
        for (var doc in snapshot.docs.take(3)) {
          final data = doc.data() as Map<String, dynamic>;
          AppLogger.info('📸 写真: ${doc.id} - ユーザー: ${data['userName']}, 時刻: ${data['timestamp']}', tag: 'PhotoService');
        }
      }

      final photos = snapshot.docs.map((doc) => Photo.fromDocument(doc)).toList();
      return photos;
    } catch (e) {
      AppLogger.error('公開写真取得エラー: $e', tag: 'PhotoService');
      AppLogger.error('エラータイプ: ${e.runtimeType}', tag: 'PhotoService');
      AppLogger.error('スタックトレース: ${StackTrace.current}', tag: 'PhotoService');
      return [];
    }
  }

  /// ユーザーの写真一覧を取得
  static Future<List<Photo>> getUserPhotos(String userId) async {
    try {
      AppLogger.info('👤 ユーザー写真取得開始 - ユーザーID: $userId', tag: 'PhotoService');

      final snapshot = await _firestore
          .collection('photos')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      AppLogger.info('📊 ユーザー写真クエリ結果: ${snapshot.docs.length}件', tag: 'PhotoService');

      if (snapshot.docs.isEmpty) {
        // 全写真を確認してユーザーIDをチェック
        final allPhotos = await _firestore.collection('photos').get();
        AppLogger.info('🔍 全写真数: ${allPhotos.docs.length}件', tag: 'PhotoService');

        for (var doc in allPhotos.docs.take(5)) {
          final data = doc.data();
          AppLogger.info('📋 写真例: ${doc.id} - userId: ${data['userId']}, userName: ${data['userName']}', tag: 'PhotoService');
        }
      }

      final photos = snapshot.docs.map((doc) => Photo.fromDocument(doc)).toList();
      AppLogger.success('✅ ユーザー写真取得完了: ${photos.length}件', tag: 'PhotoService');
      return photos;
    } catch (e) {
      AppLogger.error('ユーザー写真取得エラー: $e', tag: 'PhotoService');
      return [];
    }
  }

  /// 近くの写真を取得
  static Future<List<Photo>> getNearbyPhotos({
    required LatLng center,
    double radiusKm = 50.0,
    int limit = 20,
  }) async {
    try {
      // Firestoreの地理クエリは複雑なので、簡易版として全写真を取得してフィルタリング
      final snapshot = await _firestore
          .collection('photos')
          .where('isPublic', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(100) // 最大100件を取得してフィルタリング
          .get();

      final photos = snapshot.docs.map((doc) => Photo.fromDocument(doc)).toList();

      // 距離でフィルタリング
      final nearbyPhotos = photos.where((photo) {
        final distance = _calculateDistance(
          center.latitude,
          center.longitude,
          photo.latitude,
          photo.longitude,
        );
        return distance <= radiusKm;
      }).take(limit).toList();

      return nearbyPhotos;
    } catch (e) {
      AppLogger.error('近くの写真取得エラー: $e', tag: 'PhotoService');
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

      final likeId = '${photoId}_$userId';
      final like = PhotoLike(
        id: likeId,
        photoId: photoId,
        userId: userId,
        timestamp: DateTime.now(),
      );

      await _firestore.collection('likes').doc(likeId).set(like.toMap());

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
      return doc.exists;
    } catch (e) {
      AppLogger.error('いいね状態確認エラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// 写真のいいね状態を一括取得
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

      // ユーザーのいいね一覧を取得
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('userId', isEqualTo: userId)
          .get();

      // いいねしている写真をtrueに設定
      for (var doc in likesSnapshot.docs) {
        final data = doc.data();
        final photoId = data['photoId'] as String;
        if (photoIds.contains(photoId)) {
          likeStatus[photoId] = true;
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

  /// 写真にコメントを追加
  static Future<bool> addComment({
    required String photoId,
    required String userId,
    required String userName,
    required String text,
  }) async {
    try {
      final commentId = _firestore.collection('comments').doc().id;
      final comment = PhotoComment(
        id: commentId,
        photoId: photoId,
        userId: userId,
        userName: userName,
        text: text,
        timestamp: DateTime.now(),
      );

      await _firestore.collection('comments').doc(commentId).set(comment.toMap());

      // 写真のコメント数を更新
      await _firestore.collection('photos').doc(photoId).update({
        'comments': FieldValue.increment(1),
      });

      AppLogger.info('コメント追加: $photoId', tag: 'PhotoService');
      return true;
    } catch (e) {
      AppLogger.error('コメント追加エラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// 写真のコメント一覧を取得
  static Future<List<PhotoComment>> getPhotoComments(String photoId) async {
    try {
      final snapshot = await _firestore
          .collection('comments')
          .where('photoId', isEqualTo: photoId)
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs.map((doc) => PhotoComment.fromDocument(doc)).toList();
    } catch (e) {
      AppLogger.error('コメント取得エラー: $e', tag: 'PhotoService');
      return [];
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

      // 関連するいいねとコメントも削除
      await _deleteRelatedData(photoId);

      AppLogger.success('写真削除完了: $photoId', tag: 'PhotoService');
      return true;
    } catch (e) {
      AppLogger.error('写真削除エラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// 関連データ（いいね・コメント）を削除
  static Future<void> _deleteRelatedData(String photoId) async {
    try {
      // いいねを削除
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('photoId', isEqualTo: photoId)
          .get();

      for (final doc in likesSnapshot.docs) {
        await doc.reference.delete();
      }

      // コメントを削除
      final commentsSnapshot = await _firestore
          .collection('comments')
          .where('photoId', isEqualTo: photoId)
          .get();

      for (final doc in commentsSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      AppLogger.error('関連データ削除エラー: $e', tag: 'PhotoService');
    }
  }

  /// 2点間の距離を計算（km）
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // 地球の半径（km）

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// 度をラジアンに変換
  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// 写真をダウンロードしてローカルに保存
  static Future<bool> downloadPhoto(Photo photo, String currentUserId) async {
    try {
      AppLogger.info('📥 写真ダウンロード開始: ${photo.id}', tag: 'PhotoService');

      // ダウンロード済みかチェック
      final isAlreadyDownloaded = await _isPhotoDownloaded(photo.id, currentUserId);
      if (isAlreadyDownloaded) {
        AppLogger.info('⚠️ 既にダウンロード済み: ${photo.id}', tag: 'PhotoService');
        return true;
      }

      // アプリのドキュメントディレクトリを取得
      final appDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${appDir.path}/downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // ファイル名を生成
      final fileName = '${photo.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final localPath = '${downloadDir.path}/$fileName';

      // 画像をダウンロード
      final response = await http.get(Uri.parse(photo.imageUrl));
      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);

        // ダウンロード情報をFirestoreに保存
        await _saveDownloadInfo(photo, currentUserId, localPath);

        AppLogger.success('✅ 写真ダウンロード完了: ${photo.id}', tag: 'PhotoService');
        return true;
      } else {
        AppLogger.error('❌ 画像ダウンロード失敗: ${response.statusCode}', tag: 'PhotoService');
        return false;
      }
    } catch (e) {
      AppLogger.error('写真ダウンロードエラー: $e', tag: 'PhotoService');
      return false;
    }
  }

  /// ダウンロード情報をFirestoreに保存
  static Future<void> _saveDownloadInfo(Photo photo, String userId, String localPath) async {
    try {
      final downloadInfo = {
        'originalPhotoId': photo.id,
        'originalUserId': photo.userId,
        'originalUserName': photo.userName,
        'downloadedBy': userId,
        'downloadedAt': DateTime.now(),
        'localPath': localPath,
        'originalImageUrl': photo.imageUrl,
        'originalTimestamp': photo.timestamp,
        'latitude': photo.latitude,
        'longitude': photo.longitude,
        'locationName': photo.locationName,
        'weatherData': photo.weatherData,
        'tags': photo.tags,
        'isDownloaded': true,
      };

      await _firestore
          .collection('downloads')
          .doc('${photo.id}_$userId')
          .set(downloadInfo);
    } catch (e) {
      AppLogger.error('ダウンロード情報保存エラー: $e', tag: 'PhotoService');
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
}