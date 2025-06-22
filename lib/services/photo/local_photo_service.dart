import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/photo.dart';
import '../../utils/logger.dart';

class LocalPhotoService {
  static const String _photosKey = 'local_photos';
  static const String _photosDir = 'thunder_cloud_photos';

  /// ローカルに写真を保存
  static Future<bool> savePhotoLocally({
    required File imageFile,
    required String userId,
    required String userName,
    String? caption,
    List<String>? tags,
    Map<String, dynamic>? weatherData,
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    try {
      AppLogger.info('ローカル写真保存開始', tag: 'LocalPhotoService');

      // アプリのドキュメントディレクトリを取得
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${appDir.path}/$_photosDir');

      // ディレクトリが存在しない場合は作成
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      // 一意のファイル名を生成
      final timestamp = DateTime.now();
      final fileName = 'photo_${timestamp.millisecondsSinceEpoch}.jpg';
      final localFile = File('${photosDir.path}/$fileName');

      // 画像ファイルをコピー
      await imageFile.copy(localFile.path);

      // 写真のメタデータを作成
      final photoId = 'local_${timestamp.millisecondsSinceEpoch}';
      final photo = Photo(
        id: photoId,
        userId: userId,
        userName: userName,
        imageUrl: localFile.path, // ローカルパスを使用
        thumbnailUrl: localFile.path,
        latitude: latitude ?? 0.0,
        longitude: longitude ?? 0.0,
        locationName: locationName ?? '撮影地点',
        timestamp: timestamp,
        weatherData: weatherData ?? {},
        tags: tags ?? [],
        isPublic: false, // ローカル写真は非公開
      );

      // SharedPreferencesに写真情報を保存
      await _savePhotoMetadata(photo);

      AppLogger.success('ローカル写真保存完了: $photoId', tag: 'LocalPhotoService');
      return true;
    } catch (e) {
      AppLogger.error('ローカル写真保存エラー: $e', tag: 'LocalPhotoService');
      return false;
    }
  }

  /// ローカル写真のメタデータを保存
  static Future<void> _savePhotoMetadata(Photo photo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photosJson = prefs.getStringList(_photosKey) ?? [];

            // 新しい写真を追加
      photosJson.add(jsonEncode(photo.toLocalMap()));

      await prefs.setStringList(_photosKey, photosJson);
    } catch (e) {
      AppLogger.error('写真メタデータ保存エラー: $e', tag: 'LocalPhotoService');
    }
  }

  /// ユーザーのローカル写真一覧を取得
  static Future<List<Photo>> getUserLocalPhotos(String userId) async {
    try {
      AppLogger.info('ローカル写真取得開始 - ユーザーID: $userId', tag: 'LocalPhotoService');

      final prefs = await SharedPreferences.getInstance();
      final photosJson = prefs.getStringList(_photosKey) ?? [];

      final photos = <Photo>[];
      for (final photoJson in photosJson) {
        try {
          final photoMap = jsonDecode(photoJson) as Map<String, dynamic>;
          final photo = Photo.fromMap(photoMap);

          // ユーザーIDでフィルタリング
          if (photo.userId == userId) {
            // ファイルが存在するかチェック
            final file = File(photo.imageUrl);
            if (await file.exists()) {
              photos.add(photo);
            } else {
              // ファイルが存在しない場合はメタデータから削除
              await _removePhotoMetadata(photo.id);
            }
          }
        } catch (e) {
          AppLogger.error('写真データ解析エラー: $e', tag: 'LocalPhotoService');
        }
      }

      // タイムスタンプの降順でソート
      photos.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      AppLogger.success('ローカル写真取得完了: ${photos.length}件', tag: 'LocalPhotoService');
      return photos;
    } catch (e) {
      AppLogger.error('ローカル写真取得エラー: $e', tag: 'LocalPhotoService');
      return [];
    }
  }

  /// ローカル写真を削除
  static Future<bool> deleteLocalPhoto(String photoId, String userId) async {
    try {
      AppLogger.info('ローカル写真削除開始: $photoId', tag: 'LocalPhotoService');

      final prefs = await SharedPreferences.getInstance();
      final photosJson = prefs.getStringList(_photosKey) ?? [];

      String? photoToDelete;
      String? imagePathToDelete;

      // 削除対象の写真を検索
      for (final photoJson in photosJson) {
        try {
          final photoMap = jsonDecode(photoJson) as Map<String, dynamic>;
          final photo = Photo.fromMap(photoMap);

          if (photo.id == photoId && photo.userId == userId) {
            photoToDelete = photoJson;
            imagePathToDelete = photo.imageUrl;
            break;
          }
        } catch (e) {
          AppLogger.error('写真データ解析エラー: $e', tag: 'LocalPhotoService');
        }
      }

      if (photoToDelete == null) {
        AppLogger.warning('削除対象の写真が見つかりません: $photoId', tag: 'LocalPhotoService');
        return false;
      }

      // メタデータから削除
      photosJson.remove(photoToDelete);
      await prefs.setStringList(_photosKey, photosJson);

      // 画像ファイルを削除
      if (imagePathToDelete != null) {
        final file = File(imagePathToDelete);
        if (await file.exists()) {
          await file.delete();
        }
      }

      AppLogger.success('ローカル写真削除完了: $photoId', tag: 'LocalPhotoService');
      return true;
    } catch (e) {
      AppLogger.error('ローカル写真削除エラー: $e', tag: 'LocalPhotoService');
      return false;
    }
  }

  /// 写真メタデータを削除（内部使用）
  static Future<void> _removePhotoMetadata(String photoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photosJson = prefs.getStringList(_photosKey) ?? [];

      photosJson.removeWhere((photoJson) {
        try {
          final photoMap = jsonDecode(photoJson) as Map<String, dynamic>;
          return photoMap['id'] == photoId;
        } catch (e) {
          return false;
        }
      });

      await prefs.setStringList(_photosKey, photosJson);
    } catch (e) {
      AppLogger.error('写真メタデータ削除エラー: $e', tag: 'LocalPhotoService');
    }
  }

  /// ローカル写真の総数を取得
  static Future<int> getLocalPhotosCount(String userId) async {
    try {
      final photos = await getUserLocalPhotos(userId);
      return photos.length;
    } catch (e) {
      AppLogger.error('ローカル写真数取得エラー: $e', tag: 'LocalPhotoService');
      return 0;
    }
  }

  /// ストレージ使用量を取得（概算）
  static Future<int> getStorageUsage(String userId) async {
    try {
      final photos = await getUserLocalPhotos(userId);
      int totalSize = 0;

      for (final photo in photos) {
        final file = File(photo.imageUrl);
        if (await file.exists()) {
          final size = await file.length();
          totalSize += size;
        }
      }

      return totalSize;
    } catch (e) {
      AppLogger.error('ストレージ使用量取得エラー: $e', tag: 'LocalPhotoService');
      return 0;
    }
  }

  /// すべてのローカル写真を削除（リセット機能）
  static Future<bool> clearAllLocalPhotos(String userId) async {
    try {
      AppLogger.info('全ローカル写真削除開始 - ユーザーID: $userId', tag: 'LocalPhotoService');

      final photos = await getUserLocalPhotos(userId);

      for (final photo in photos) {
        await deleteLocalPhoto(photo.id, userId);
      }

      AppLogger.success('全ローカル写真削除完了', tag: 'LocalPhotoService');
      return true;
    } catch (e) {
      AppLogger.error('全ローカル写真削除エラー: $e', tag: 'LocalPhotoService');
      return false;
    }
  }
}