import '../../constants/app_constants.dart';
import '../../models/photo.dart';
import '../../services/photo/local_photo_service.dart';
import '../../utils/logger.dart';

/// ギャラリー画面のビジネスロジックを管理するサービス
class GalleryService {
  // ===== キャッシュ =====
  List<Photo> _photos = [];
  bool _isLoading = false;

  // ===== ゲッター =====
  List<Photo> get photos => List.unmodifiable(_photos);
  bool get isLoading => _isLoading;

  // ===== 写真管理 =====

  /// ローカル写真を読み込み
  Future<List<Photo>> loadLocalPhotos() async {
    if (_isLoading) return _photos;

    _isLoading = true;
    AppLogger.info('ローカル写真読み込み開始', tag: 'GalleryService');

    try {
      _photos = await LocalPhotoService.getUserLocalPhotos(AppConstants.currentUserId);
      AppLogger.success('ローカル写真読み込み完了: ${_photos.length}件', tag: 'GalleryService');
      return _photos;
    } catch (e) {
      AppLogger.error('ローカル写真読み込みエラー', error: e, tag: 'GalleryService');
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// 写真を削除
  Future<void> deletePhoto(String photoId) async {
    AppLogger.info('写真削除開始: $photoId', tag: 'GalleryService');

    try {
      await LocalPhotoService.deleteLocalPhoto(photoId, AppConstants.currentUserId);
      _photos.removeWhere((photo) => photo.id == photoId);
      AppLogger.success('写真削除完了: $photoId', tag: 'GalleryService');
    } catch (e) {
      AppLogger.error('写真削除エラー', error: e, tag: 'GalleryService');
      rethrow;
    }
  }

  /// キャッシュをクリア
  void clearCache() {
    _photos.clear();
    AppLogger.info('ギャラリーキャッシュクリア', tag: 'GalleryService');
  }

  /// データを再読み込み
  Future<List<Photo>> refreshPhotos() async {
    clearCache();
    return await loadLocalPhotos();
  }
}
