import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../constants/app_constants.dart';
import '../../models/photo.dart';
import '../../services/photo/local_photo_service.dart';
import '../../services/photo/photo_service.dart';
import '../../utils/logger.dart';

/// 写真読み込み結果
class PhotoLoadResult {
  final List<Photo> photos;
  final bool hasMore;

  PhotoLoadResult({
    required this.photos,
    required this.hasMore,
  });
}

/// コミュニティ関連のビジネスロジックを管理するサービス
class CommunityService {
  // ===== キャッシュ =====
  // ユーザー情報キャッシュを削除（写真データのuserNameを直接使用）

  // ===== 状態管理 =====
  String? _currentUserId;
  List<Photo> _photos = []; // 現在読み込まれている写真データ
  bool _isInitialized = false; // 初期化状態の管理

  // ===== 定数 =====
  static const int _defaultPhotoLimit = 20;

  // ===== 公開メソッド =====

  /// サービスを初期化
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.info('CommunityService は既に初期化済み', tag: 'CommunityService');
      return;
    }

    _currentUserId = await AppConstants.getCurrentUserId();
    _isInitialized = true;
    AppLogger.info('CommunityService初期化完了: userId=$_currentUserId', tag: 'CommunityService');
  }

  /// 写真一覧を読み込み
  Future<PhotoLoadResult> loadPhotos({
    bool isInitialLoad = true,
    int limit = _defaultPhotoLimit,
  }) async {
    AppLogger.info('写真読み込み開始 (初期読み込み: $isInitialLoad)', tag: 'CommunityService');

    try {
      // 現在のユーザーIDを確認
      if (_currentUserId == null) {
        await initialize();
      }

      // 全ての公開写真を取得（位置情報による制限なし）
      AppLogger.info('全ての公開写真を取得', tag: 'CommunityService');
      final photos = await PhotoService.getPublicPhotos(limit: limit);

      // 写真データをキャッシュに保存
      _photos = photos;

      // ユーザー情報の事前読み込みを削除（写真データのuserNameを直接使用）

      final hasMore = photos.length >= limit;

      AppLogger.success('写真読み込み完了: ${photos.length}件', tag: 'CommunityService');
      return PhotoLoadResult(photos: photos, hasMore: hasMore);
    } catch (e) {
      AppLogger.error('写真読み込みエラー', error: e, tag: 'CommunityService');
      rethrow;
    }
  }

  /// 追加の写真を読み込み
  Future<PhotoLoadResult> loadMorePhotos(
    List<Photo> currentPhotos, {
    int limit = _defaultPhotoLimit,
  }) async {
    AppLogger.info('追加写真読み込み開始', tag: 'CommunityService');

    try {
      final photos = await PhotoService.getPublicPhotos(limit: limit);

      if (photos.isNotEmpty) {
        // 写真データをキャッシュに追加
        _photos.addAll(photos);

        // ユーザー情報の事前読み込みを削除（写真データのuserNameを直接使用）
      }

      final hasMore = photos.length >= limit;

      AppLogger.success('追加写真読み込み完了: ${photos.length}件', tag: 'CommunityService');
      return PhotoLoadResult(photos: photos, hasMore: hasMore);
    } catch (e) {
      AppLogger.error('追加写真読み込みエラー', error: e, tag: 'CommunityService');
      rethrow;
    }
  }

  /// いいねの切り替え
  Future<Photo?> toggleLike(Photo photo) async {
    AppLogger.info('いいね切り替え開始: ${photo.id}', tag: 'CommunityService');

    try {
      // 現在のユーザーIDを確認
      if (_currentUserId == null) {
        await initialize();
      }

      if (_currentUserId == null) {
        throw Exception('ユーザーIDが取得できません');
      }

      // 現在のいいね状態を確認
      final isCurrentlyLiked = photo.isLikedByUser(_currentUserId!);

      Photo? updatedPhoto;
      if (isCurrentlyLiked) {
        updatedPhoto = await PhotoService.unlikePhoto(photo.id, _currentUserId!);
        AppLogger.success('いいね削除完了: ${photo.id}', tag: 'CommunityService');
      } else {
        updatedPhoto = await PhotoService.likePhoto(photo.id, _currentUserId!);
        AppLogger.success('いいね追加完了: ${photo.id}', tag: 'CommunityService');
      }

      // キャッシュされた写真データを更新
      if (updatedPhoto != null) {
        final index = _photos.indexWhere((p) => p.id == photo.id);
        if (index != -1) {
          _photos[index] = updatedPhoto;
        }
      }

      return updatedPhoto;
    } catch (e) {
      AppLogger.error('いいね切り替えエラー', error: e, tag: 'CommunityService');
      rethrow;
    }
  }

  /// 写真をダウンロードしてローカル保存
  Future<void> downloadPhoto(Photo photo) async {
    AppLogger.info('写真ダウンロード開始: ${photo.id}', tag: 'CommunityService');

    try {
      // 画像をダウンロード
      final response = await http.get(Uri.parse(photo.imageUrl));
      if (response.statusCode != 200) {
        AppLogger.error('画像ダウンロード失敗: ${response.statusCode}', tag: 'CommunityService');
        throw Exception('画像のダウンロードに失敗しました');
      }

      // ユーザーIDを動的に取得
      final userId = await AppConstants.getCurrentUserId();

      // 一時ファイルを作成
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_download_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(response.bodyBytes);

      // ローカルに保存
      final success = await LocalPhotoService.savePhotoLocally(
        imageFile: tempFile,
        userId: userId,
        userName: 'ダウンロード',
        caption: '${photo.userName}さんの投稿をダウンロード',
        latitude: photo.latitude,
        longitude: photo.longitude,
        locationName: photo.locationName.isNotEmpty ? photo.locationName : 'ダウンロード済み写真',
        weatherData: photo.weatherData,
        tags: [...photo.tags, 'ダウンロード'],
      );

      // 一時ファイルを削除
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (success) {
        AppLogger.success('写真ローカル保存完了: ${photo.id}', tag: 'CommunityService');
      } else {
        throw Exception('ローカル保存に失敗しました');
      }
    } catch (e) {
      AppLogger.error('写真ダウンロードエラー', error: e, tag: 'CommunityService');
      rethrow;
    }
  }

  /// 写真を削除
  Future<void> deletePhoto(String photoId) async {
    AppLogger.info('写真削除開始: $photoId', tag: 'CommunityService');

    try {
      // ユーザーIDを動的に取得
      final userId = await AppConstants.getCurrentUserId();

      await PhotoService.deletePhoto(photoId, userId);

      // キャッシュからも削除
      // _userInfoCache.remove(photoId); // ユーザー情報キャッシュは削除

      AppLogger.success('写真削除完了: $photoId', tag: 'CommunityService');
    } catch (e) {
      AppLogger.error('写真削除エラー', error: e, tag: 'CommunityService');
      rethrow;
    }
  }

  /// いいね状態を取得
  bool getLikeStatus(String photoId) {
    if (_currentUserId == null) return false;

    // キャッシュされた写真データから直接いいね状態を取得
    try {
      final photo = _photos.firstWhere((p) => p.id == photoId);
      return photo.isLikedByUser(_currentUserId!);
    } catch (e) {
      AppLogger.warning('いいね状態取得エラー: $photoId', tag: 'CommunityService');
      return false;
    }
  }

  /// いいね数を取得
  int getLikeCount(String photoId, int defaultCount) {
    // キャッシュされた写真データから直接いいね数を取得
    try {
      final photo = _photos.firstWhere((p) => p.id == photoId);
      return photo.likes;
    } catch (e) {
      AppLogger.warning('いいね数取得エラー: $photoId', tag: 'CommunityService');
      return defaultCount;
    }
  }

  /// 写真データを更新
  void updatePhoto(Photo updatedPhoto) {
    final index = _photos.indexWhere((p) => p.id == updatedPhoto.id);
    if (index != -1) {
      _photos[index] = updatedPhoto;
      AppLogger.info('写真データ更新完了: ${updatedPhoto.id}', tag: 'CommunityService');
    }
  }

  /// キャッシュをクリア
  void clearCache() {
    // _userInfoCache.clear(); // ユーザー情報キャッシュは削除
    _photos.clear();
    AppLogger.info('キャッシュクリア完了', tag: 'CommunityService');
  }

  /// 特定のユーザーのキャッシュを無効化
  void invalidateUserCache(String userId) {
    // _userInfoCache.remove(userId); // ユーザー情報キャッシュは削除
    AppLogger.info('ユーザーキャッシュ無効化: $userId', tag: 'CommunityService');
  }

  /// 全てのユーザーキャッシュを無効化
  void invalidateAllUserCache() {
    // _userInfoCache.clear(); // ユーザー情報キャッシュは削除
    AppLogger.info('全ユーザーキャッシュ無効化完了', tag: 'CommunityService');
  }

  /// リソースを解放
  void dispose() {
    // _userInfoCache.clear(); // ユーザー情報キャッシュは削除
    _photos.clear();
    _currentUserId = null;
    _isInitialized = false;
    AppLogger.info('CommunityService リソース解放完了', tag: 'CommunityService');
  }

  // ===== プライベートメソッド =====

  /// ユーザー情報を事前読み込み
  Future<void> _preloadUserInfos(List<String> userIds) async {
    // ユーザー情報事前読み込みを削除
  }
}