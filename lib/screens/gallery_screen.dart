import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_constants.dart';
import '../models/photo.dart';
import '../services/photo/local_photo_service.dart';
import '../utils/logger.dart';
import 'gallery/gallery_photo_detail_screen.dart';

/// 写真アイテムの抽象クラス
abstract class PhotoItem {
  String get id;
  String get imageUrl;
  DateTime get timestamp;
  String get displayTitle;

  Widget buildSubtitle();
  Future<void> delete();
  Future<void> share();
  void openDetail(BuildContext context);
}

/// ローカル写真アイテム
class LocalPhotoItem extends PhotoItem {
  final Photo photo;
  final VoidCallback onRefresh;

  LocalPhotoItem(this.photo, this.onRefresh);

  @override
  String get id => photo.id;

  @override
  String get imageUrl => photo.imageUrl;

  @override
  DateTime get timestamp => photo.timestamp;

  @override
  String get displayTitle => photo.locationName.isNotEmpty ? photo.locationName : '撮影写真';

  @override
  Widget buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDateTime(timestamp),
          style: const TextStyle(fontSize: 12),
        ),
        if (photo.locationName.isNotEmpty)
          Text(
            photo.locationName,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
      ],
    );
  }

  @override
  Future<void> delete() async {
    final userId = await AppConstants.getCurrentUserId();
    await LocalPhotoService.deleteLocalPhoto(photo.id, userId);
    onRefresh();
  }

  @override
  Future<void> share() async {
    if (photo.imageUrl.startsWith('/')) {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(photo.imageUrl)],
        text: '入道雲の写真をシェアします！',
      ));
    } else {
      await SharePlus.instance.share(ShareParams(
        text: '入道雲の写真: ${photo.imageUrl}',
      ));
    }
  }

  @override
  void openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GalleryPhotoDetailScreen(photo: photo),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// ギャラリー画面 - マイフォト
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();

  /// 外部からギャラリーを更新するためのメソッド
  /// MainScreenから呼び出されて、コミュニティからダウンロードした写真を反映する
  static void refreshGallery(GlobalKey key) {
    try {
      final state = key.currentState as _GalleryScreenState?;
      if (state != null && state.mounted) {
        state.refreshData();
        AppLogger.success('ギャラリーの静的メソッド経由更新成功', tag: 'GalleryScreen');
      } else {
        AppLogger.warning('ギャラリー状態が無効またはアンマウント状態', tag: 'GalleryScreen');
      }
    } catch (e) {
      AppLogger.error('ギャラリー静的メソッド経由更新エラー', error: e, tag: 'GalleryScreen');
    }
  }
}

class _GalleryScreenState extends State<GalleryScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // データ管理
  List<Photo> _photos = [];

  // UI状態管理
  bool _isLoading = true;
  bool _isGridView = true;
  bool _isSelectionMode = false;

  // 選択状態管理
  final Set<String> _selectedPhotos = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ===== 初期化メソッド =====

  void _loadAllData() {
    _loadPhotos();
  }

  /// 外部から呼び出し可能なデータ再読み込みメソッド
  void refreshData() {
    AppLogger.info('ギャラリーデータ再読み込み開始: 外部からの要求', tag: 'GalleryScreen');
    if (mounted) {
      _loadAllData();
    } else {
      AppLogger.warning('ギャラリーがアンマウント状態のため更新をスキップ', tag: 'GalleryScreen');
    }
  }

  // ===== データ読み込みメソッド =====

  Future<void> _loadPhotos() async {
    try {
      AppLogger.info('マイフォト読み込み開始', tag: 'GalleryScreen');
      if (mounted) setState(() => _isLoading = true);

      final userId = await AppConstants.getCurrentUserId();
      final List<Photo> photos = await LocalPhotoService.getUserLocalPhotos(userId);

      if (mounted) {
        setState(() {
          _photos = photos;
          _isLoading = false;
        });
      }

      AppLogger.success('マイフォト読み込み完了: ${photos.length}件', tag: 'GalleryScreen');
    } catch (e) {
      AppLogger.error('マイフォト読み込みエラー', error: e, tag: 'GalleryScreen');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===== イベントハンドラー =====

  void _clearSelectionMode() {
    _isSelectionMode = false;
    _selectedPhotos.clear();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPhotos.clear();
      }
    });
  }

  void _toggleViewMode() {
    setState(() => _isGridView = !_isGridView);
  }

  // ===== 削除処理メソッド =====

  Future<void> _deleteSelectedItems() async {
    if (_selectedPhotos.isEmpty) return;

    try {
      AppLogger.info('選択アイテム削除開始: ${_selectedPhotos.length}件', tag: 'GalleryScreen');

      final userId = await AppConstants.getCurrentUserId();
      for (final String photoId in _selectedPhotos) {
        await LocalPhotoService.deleteLocalPhoto(photoId, userId);
      }

      if (mounted) {
        setState(() {
          _photos.removeWhere((Photo photo) => _selectedPhotos.contains(photo.id));
          _clearSelectionMode();
        });
      }

      _showSuccessMessage('選択したアイテムを削除しました');
      AppLogger.success('アイテム削除完了', tag: 'GalleryScreen');
    } catch (e) {
      AppLogger.error('アイテム削除エラー', error: e, tag: 'GalleryScreen');
      _showErrorMessage('削除に失敗しました: $e');
    }
  }

  // ===== 写真アイテム処理メソッド =====

  List<PhotoItem> _getCurrentPhotoItems() {
    return _photos.map((Photo photo) => LocalPhotoItem(photo, () => setState(() {}))).toList();
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedPhotos.contains(itemId)) {
        _selectedPhotos.remove(itemId);
      } else {
        _selectedPhotos.add(itemId);
      }
    });
  }

  void _onItemTap(PhotoItem item) {
    if (_isSelectionMode) {
      _toggleItemSelection(item.id);
    } else {
      item.openDetail(context);
    }
  }

  // ===== 画像表示ヘルパーメソッド =====

  Widget _buildItemImage(PhotoItem item) {
    final bool isLocalFile = item.imageUrl.startsWith('/');
    return isLocalFile ? _buildLocalFileImage(item.imageUrl) : _buildNetworkImage(item.imageUrl);
  }

  Widget _buildLocalFileImage(String filePath) {
    return AspectRatio(
      aspectRatio: 1.0, // 正方形を強制
      child: Image.file(
        File(filePath),
        fit: BoxFit.cover, // 正方形内に画像をフィットさせる
        errorBuilder: (context, error, stackTrace) {
          AppLogger.error('ローカル画像読み込みエラー: $filePath', error: error, tag: 'GalleryScreen');
          return _buildErrorImage();
        },
      ),
    );
  }

  Widget _buildNetworkImage(String imageUrl) {
    return AspectRatio(
      aspectRatio: 1.0, // 正方形を強制
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover, // 正方形内に画像をフィットさせる
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          AppLogger.error('ネットワーク画像読み込みエラー: $url', error: error, tag: 'GalleryScreen');
          return _buildErrorImage();
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return AspectRatio(
      aspectRatio: 1.0, // 正方形を強制
      child: Container(
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primarySkyBlue),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorImage() {
    return AspectRatio(
      aspectRatio: 1.0, // 正方形を強制
      child: Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(
            Icons.error_outline,
            color: Colors.red,
            size: AppConstants.iconSizeLarge,
          ),
        ),
      ),
    );
  }

  // ===== UI構築メソッド =====

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixinの要求
    return Container(
      color: AppConstants.backgroundColorLight,
      child: Column(
        children: [
          _buildActionBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// アクションバーを構築
  Widget _buildActionBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall, // 縦の余白を削減
      ),
      child: Row(
        children: [
          Text(
            'マイフォト (${_photos.length})',
            style: const TextStyle(
              fontSize: AppConstants.fontSizeLarge,
              fontWeight: FontWeight.bold,
              color: AppConstants.primarySkyBlue,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: _toggleViewMode,
            tooltip: _isGridView ? 'リスト表示' : 'グリッド表示',
            padding: const EdgeInsets.all(AppConstants.paddingSmall), // アイコンボタンの余白削減
          ),
          IconButton(
            icon: Icon(_isSelectionMode ? Icons.close : Icons.select_all),
            onPressed: _toggleSelectionMode,
            tooltip: _isSelectionMode ? '選択解除' : '選択モード',
            padding: const EdgeInsets.all(AppConstants.paddingSmall), // アイコンボタンの余白削減
          ),
          if (_isSelectionMode && _selectedPhotos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteSelectedItems,
              tooltip: '選択項目を削除',
              padding: const EdgeInsets.all(AppConstants.paddingSmall), // アイコンボタンの余白削減
            ),
        ],
      ),
    );
  }

  /// メインボディを構築
  Widget _buildBody() {
    if (_isLoading && _photos.isEmpty) {
      return _buildLoadingIndicator();
    }

    if (_photos.isEmpty) {
      return _buildEmptyState();
    }

    final photoItems = _getCurrentPhotoItems();

    return RefreshIndicator(
      onRefresh: () async => _loadPhotos(),
      child: _isGridView ? _buildGridView(photoItems) : _buildListView(photoItems),
    );
  }

  /// グリッドビューを構築
  Widget _buildGridView(List<PhotoItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingSmall), // 余白を削減
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 4列に変更
        crossAxisSpacing: AppConstants.paddingXSmall, // さらに間隔を削減
        mainAxisSpacing: AppConstants.paddingXSmall, // さらに間隔を削減
        childAspectRatio: 1.0, // 正方形比率
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildGridItem(items[index]),
    );
  }

  /// グリッドアイテムを構築
  Widget _buildGridItem(PhotoItem item) {
    final bool isSelected = _selectedPhotos.contains(item.id);

    return GestureDetector(
      onTap: () => _onItemTap(item),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              border: isSelected
                  ? Border.all(color: AppConstants.primarySkyBlue, width: 2)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              child: _buildItemImage(item),
            ),
          ),
          if (_isSelectionMode)
            Positioned(
              top: AppConstants.paddingXSmall,
              right: AppConstants.paddingXSmall,
              child: Container(
                width: 20, // 4列表示に合わせてサイズを小さく
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? AppConstants.primarySkyBlue : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppConstants.primarySkyBlue),
                ),
                child: Icon(
                  isSelected ? Icons.check : Icons.circle_outlined,
                  color: isSelected ? Colors.white : AppConstants.primarySkyBlue,
                  size: 14, // アイコンサイズも小さく
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// リストビューを構築
  Widget _buildListView(List<PhotoItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingSmall), // グリッドビューと統一
      itemCount: items.length,
      itemBuilder: (context, index) => _buildListItem(items[index]),
    );
  }

  /// リストアイテムを構築
  Widget _buildListItem(PhotoItem item) {
    final bool isSelected = _selectedPhotos.contains(item.id);

    return Card(
      elevation: AppConstants.elevationSmall,
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall), // 余白を削減
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall), // 角丸を小さく
        side: isSelected
            ? const BorderSide(color: AppConstants.primarySkyBlue, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppConstants.paddingSmall), // 内部余白を削減
        leading: SizedBox(
          width: AppConstants.thumbnailSize,
          height: AppConstants.thumbnailSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
            child: _buildItemImage(item),
          ),
        ),
        title: Text(
          item.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: item.buildSubtitle(),
        trailing: _isSelectionMode
            ? Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? AppConstants.primarySkyBlue : Colors.grey,
              )
            : PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'share':
                      await item.share();
                      break;
                    case 'delete':
                      await _showDeleteConfirmation(item);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.share),
                      title: Text('シェア'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('削除'),
                    ),
                  ),
                ],
              ),
        onTap: () => _onItemTap(item),
      ),
    );
  }

  /// 削除確認ダイアログを表示
  Future<void> _showDeleteConfirmation(PhotoItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('写真を削除'),
        content: Text('「${item.displayTitle}」を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await item.delete();
        _showSuccessMessage('写真を削除しました');
      } catch (e) {
        _showErrorMessage('削除に失敗しました: $e');
      }
    }
  }

  /// ローディングインジケーターを構築
  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primarySkyBlue),
      ),
    );
  }

  /// 空状態を構築
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: AppConstants.iconSizeXLarge,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Text(
            'まだ写真がありません',
            style: TextStyle(
              fontSize: AppConstants.fontSizeLarge,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          Text(
            'カメラボタンから写真を撮影するか、\nコミュニティから写真をダウンロードしてみましょう！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppConstants.fontSizeMedium,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // ===== メッセージ表示 =====

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: AppConstants.snackBarDurationSeconds),
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: AppConstants.snackBarDurationSeconds),
      ),
    );
  }
}