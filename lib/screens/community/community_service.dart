import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/photo.dart';
import '../../services/photo/photo_service.dart';
import '../../services/photo/user_service.dart';
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
  final Map<String, Map<String, dynamic>> _userInfoCache = {};
  final Map<String, bool> _likeStatusCache = {};

  // ===== 定数 =====
  static const int _defaultPhotoLimit = 20;
  static const double _nearbyPhotosRadiusKm = 50.0;
  static const String _currentUserId = 'user_001';

  // ===== 公開メソッド =====

  /// 写真一覧を読み込み
  Future<PhotoLoadResult> loadPhotos({
    LatLng? currentLocation,
    bool isInitialLoad = true,
    int limit = _defaultPhotoLimit,
  }) async {
    AppLogger.info('写真読み込み開始 (初期読み込み: $isInitialLoad)', tag: 'CommunityService');

    try {
      List<Photo> photos;

      if (currentLocation != null) {
        AppLogger.info('近くの写真を取得: $currentLocation', tag: 'CommunityService');
        photos = await PhotoService.getNearbyPhotos(
          center: currentLocation,
          radiusKm: _nearbyPhotosRadiusKm,
          limit: limit,
        );
      } else {
        AppLogger.info('公開写真を取得', tag: 'CommunityService');
        photos = await PhotoService.getPublicPhotos(limit: limit);
      }

      // ユーザー情報といいね状態を並行して取得
      await Future.wait([
        _preloadUserInfos(photos.map((p) => p.userId).toSet().toList()),
        _preloadLikeStatus(photos.map((p) => p.id).toList()),
      ]);

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
        await Future.wait([
          _preloadUserInfos(photos.map((p) => p.userId).toSet().toList()),
          _preloadLikeStatus(photos.map((p) => p.id).toList()),
        ]);
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
  Future<void> toggleLike(Photo photo) async {
    AppLogger.info('いいね切り替え開始: ${photo.id}', tag: 'CommunityService');

    try {
      final currentStatus = _likeStatusCache[photo.id] ?? false;
      final newStatus = !currentStatus;

      // 楽観的更新
      _likeStatusCache[photo.id] = newStatus;

      if (newStatus) {
        await PhotoService.likePhoto(photo.id, _currentUserId);
      } else {
        await PhotoService.unlikePhoto(photo.id, _currentUserId);
      }

      AppLogger.success('いいね切り替え完了: ${photo.id} -> $newStatus', tag: 'CommunityService');
    } catch (e) {
      // エラー時は元の状態に戻す
      final originalStatus = !(_likeStatusCache[photo.id] ?? false);
      _likeStatusCache[photo.id] = originalStatus;

      AppLogger.error('いいね切り替えエラー', error: e, tag: 'CommunityService');
      rethrow;
    }
  }

    /// 写真をダウンロード
  Future<void> downloadPhoto(Photo photo) async {
    AppLogger.info('写真ダウンロード開始: ${photo.id}', tag: 'CommunityService');

    try {
      await PhotoService.downloadPhoto(photo, _currentUserId);
      AppLogger.success('写真ダウンロード完了: ${photo.id}', tag: 'CommunityService');
    } catch (e) {
      AppLogger.error('写真ダウンロードエラー', error: e, tag: 'CommunityService');
      rethrow;
    }
  }

  /// 写真を削除
  Future<void> deletePhoto(String photoId) async {
    AppLogger.info('写真削除開始: $photoId', tag: 'CommunityService');

    try {
      await PhotoService.deletePhoto(photoId, _currentUserId);

      // キャッシュからも削除
      _likeStatusCache.remove(photoId);

      AppLogger.success('写真削除完了: $photoId', tag: 'CommunityService');
    } catch (e) {
      AppLogger.error('写真削除エラー', error: e, tag: 'CommunityService');
      rethrow;
    }
  }

  /// ユーザー情報を取得（キャッシュ付き）
  Future<Map<String, dynamic>> getUserInfo(String userId) async {
    if (_userInfoCache.containsKey(userId)) {
      return _userInfoCache[userId]!;
    }

    try {
      final userInfo = await UserService.getUserInfo(userId);
      _userInfoCache[userId] = userInfo;
      return userInfo;
    } catch (e) {
      AppLogger.error('ユーザー情報取得エラー: $userId', error: e, tag: 'CommunityService');

      // デフォルト情報を返す
      final defaultInfo = {
        'userId': userId,
        'userName': 'ユーザー',
        'avatarUrl': '',
      };
      _userInfoCache[userId] = defaultInfo;
      return defaultInfo;
    }
  }

  /// いいね状態を取得
  bool getLikeStatus(String photoId) {
    return _likeStatusCache[photoId] ?? false;
  }

  /// キャッシュをクリア
  void clearCache() {
    _userInfoCache.clear();
    _likeStatusCache.clear();
    AppLogger.info('キャッシュクリア完了', tag: 'CommunityService');
  }

  // ===== プライベートメソッド =====

  /// ユーザー情報を事前読み込み
  Future<void> _preloadUserInfos(List<String> userIds) async {
    if (userIds.isEmpty) return;

    final uncachedUserIds = userIds.where((id) => !_userInfoCache.containsKey(id)).toList();
    if (uncachedUserIds.isEmpty) return;

    AppLogger.info('ユーザー情報事前読み込み: ${uncachedUserIds.length}件', tag: 'CommunityService');

    try {
      await Future.wait(
        uncachedUserIds.map((userId) => getUserInfo(userId)),
      );
      AppLogger.success('ユーザー情報事前読み込み完了', tag: 'CommunityService');
    } catch (e) {
      AppLogger.error('ユーザー情報事前読み込みエラー', error: e, tag: 'CommunityService');
    }
  }

  /// いいね状態を事前読み込み
  Future<void> _preloadLikeStatus(List<String> photoIds) async {
    if (photoIds.isEmpty) return;

    final uncachedPhotoIds = photoIds.where((id) => !_likeStatusCache.containsKey(id)).toList();
    if (uncachedPhotoIds.isEmpty) return;

    AppLogger.info('いいね状態事前読み込み: ${uncachedPhotoIds.length}件', tag: 'CommunityService');

    try {
      final likeStatus = await PhotoService.getPhotosLikeStatus(
        uncachedPhotoIds,
        _currentUserId,
      );

      _likeStatusCache.addAll(likeStatus);
      AppLogger.success('いいね状態事前読み込み完了: ${likeStatus.length}件', tag: 'CommunityService');
    } catch (e) {
      AppLogger.error('いいね状態事前読み込みエラー', error: e, tag: 'CommunityService');
    }
  }
}