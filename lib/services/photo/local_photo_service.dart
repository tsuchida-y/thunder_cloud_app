import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_constants.dart';
import '../../models/photo.dart';
import '../../utils/logger.dart';

/// ローカル写真管理サービスクラス
/// 端末内での写真保存、取得、削除機能を提供
/// SharedPreferencesとファイルシステムを使用した管理
class LocalPhotoService {
  /*
  ================================================================================
                                    定数定義
                          ローカル保存用の設定値
  ================================================================================
  */
  static const String _photosKey = 'local_photos';
  static const String _photosDir = 'thunder_cloud_photos';

  /*
  ================================================================================
                                写真保存機能
                        ローカル写真の保存とメタデータ管理
  ================================================================================
  */

  /// 写真をローカルに保存
  /// 画像ファイルのコピーとメタデータの保存を実行
  ///
  /// [imageFile] 保存する画像ファイル
  /// [userId] ユーザーID
  /// [userName] ユーザー名
  /// [caption] 写真のキャプション（オプション）
  /// [latitude] 緯度（オプション）
  /// [longitude] 経度（オプション）
  /// [locationName] 地名（オプション）
  /// [weatherData] 気象データ（オプション）
  /// [tags] タグリスト（オプション）
  /// Returns: 保存成功時はtrue
  static Future<bool> savePhotoLocally({
    required File imageFile,
    required String userId,
    required String userName,
    String? caption,
    double? latitude,
    double? longitude,
    String? locationName,
    Map<String, dynamic>? weatherData,
    List<String>? tags,
  }) async {
    try {
      // ステップ1: 座標を小数点2位に丸める（プライバシー保護）
      final roundedLatitude = AppConstants.roundCoordinate(latitude ?? 0.0);
      final roundedLongitude = AppConstants.roundCoordinate(longitude ?? 0.0);

      // ステップ2: アプリのドキュメントディレクトリを取得
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${appDir.path}/$_photosDir');

      // ステップ3: ディレクトリが存在しない場合は作成
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      // ステップ4: ファイル名を生成（重複を避けるためタイムスタンプを使用）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'photo_$timestamp.jpg';
      final savedImagePath = '${photosDir.path}/$fileName';

      // ステップ5: 画像ファイルをコピー
      await imageFile.copy(savedImagePath);

      // ステップ6: 写真メタデータを作成
      final photoId = 'local_$timestamp';
      final photo = Photo(
        id: photoId,
        userId: userId,
        userName: userName,
        imageUrl: savedImagePath, // ローカルパスを保存
        thumbnailUrl: savedImagePath,
        latitude: roundedLatitude,
        longitude: roundedLongitude,
        locationName: locationName ?? '',
        timestamp: DateTime.now(),
        weatherData: weatherData ?? {},
        tags: tags ?? [],
      );

      // ステップ7: SharedPreferencesに写真メタデータを保存
      await _savePhotoMetadata(photo);

      return true;
    } catch (e) {
      AppLogger.error('ローカル写真保存エラー: $e', tag: 'LocalPhotoService');
      return false;
    }
  }

  /*
  ================================================================================
                                メタデータ管理
                        写真メタデータの保存と削除
  ================================================================================
  */

  /// ローカル写真のメタデータを保存
  /// SharedPreferencesに写真情報を追加
  ///
  /// [photo] 写真データ
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

  /// 写真メタデータを削除（内部使用）
  /// 指定された写真IDのメタデータを削除
  ///
  /// [photoId] 写真ID
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

  /*
  ================================================================================
                                写真取得機能
                        ローカル写真の一覧取得と検証
  ================================================================================
  */

  /// ユーザーのローカル写真一覧を取得
  /// 指定されたユーザーIDの写真を時系列順で取得
  ///
  /// [userId] ユーザーID
  /// Returns: ローカル写真データのリスト
  static Future<List<Photo>> getUserLocalPhotos(String userId) async {
    try {
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

      return photos;
    } catch (e) {
      AppLogger.error('ローカル写真取得エラー: $e', tag: 'LocalPhotoService');
      return [];
    }
  }

  /*
  ================================================================================
                                写真削除機能
                        ローカル写真の削除とクリーンアップ
  ================================================================================
  */

  /// ローカル写真を削除
  /// 画像ファイルとメタデータの両方を削除
  ///
  /// [photoId] 写真ID
  /// [userId] ユーザーID
  /// Returns: 削除成功時はtrue
  static Future<bool> deleteLocalPhoto(String photoId, String userId) async {
    try {
      AppLogger.info('ローカル写真削除開始: $photoId', tag: 'LocalPhotoService');

      final prefs = await SharedPreferences.getInstance();
      final photosJson = prefs.getStringList(_photosKey) ?? [];

      String? photoToDelete;
      String? imagePathToDelete;

      // ステップ1: 削除対象の写真を検索
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

      // ステップ2: メタデータから削除
      photosJson.remove(photoToDelete);
      await prefs.setStringList(_photosKey, photosJson);

      // ステップ3: 画像ファイルを削除
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

  /*
  ================================================================================
                                統計情報取得
                        ローカル写真の統計と状態確認
  ================================================================================
  */

  /// ローカル写真の統計情報を取得
  /// 保存されている写真数やストレージ使用量を確認
  ///
  /// Returns: 統計情報のマップ
  static Future<Map<String, dynamic>> getLocalPhotoStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photosJson = prefs.getStringList(_photosKey) ?? [];

      int totalPhotos = 0;
      int validPhotos = 0;
      int invalidPhotos = 0;
      int totalSizeBytes = 0;

      for (final photoJson in photosJson) {
        try {
          final photoMap = jsonDecode(photoJson) as Map<String, dynamic>;
          final photo = Photo.fromMap(photoMap);
          totalPhotos++;

          final file = File(photo.imageUrl);
          if (await file.exists()) {
            validPhotos++;
            final fileStat = await file.stat();
            totalSizeBytes += fileStat.size;
          } else {
            invalidPhotos++;
          }
        } catch (e) {
          invalidPhotos++;
        }
      }

      return {
        'totalPhotos': totalPhotos,
        'validPhotos': validPhotos,
        'invalidPhotos': invalidPhotos,
        'totalSizeBytes': totalSizeBytes,
        'totalSizeMB': (totalSizeBytes / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      AppLogger.error('ローカル写真統計取得エラー: $e', tag: 'LocalPhotoService');
      return {
        'totalPhotos': 0,
        'validPhotos': 0,
        'invalidPhotos': 0,
        'totalSizeBytes': 0,
        'totalSizeMB': '0.00',
      };
    }
  }

  /*
  ================================================================================
                                クリーンアップ機能
                        無効な写真データの削除
  ================================================================================
  */

  /// 無効な写真データをクリーンアップ
  /// ファイルが存在しない写真のメタデータを削除
  ///
  /// Returns: クリーンアップされた写真数
  static Future<int> cleanupInvalidPhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photosJson = prefs.getStringList(_photosKey) ?? [];
      final validPhotos = <String>[];
      int cleanedCount = 0;

      for (final photoJson in photosJson) {
        try {
          final photoMap = jsonDecode(photoJson) as Map<String, dynamic>;
          final photo = Photo.fromMap(photoMap);

          final file = File(photo.imageUrl);
          if (await file.exists()) {
            validPhotos.add(photoJson);
          } else {
            cleanedCount++;
          }
        } catch (e) {
          cleanedCount++;
        }
      }

      // 有効な写真のみを保存
      await prefs.setStringList(_photosKey, validPhotos);

      AppLogger.info('無効な写真データクリーンアップ完了: $cleanedCount件', tag: 'LocalPhotoService');
      return cleanedCount;
    } catch (e) {
      AppLogger.error('写真データクリーンアップエラー: $e', tag: 'LocalPhotoService');
      return 0;
    }
  }
}