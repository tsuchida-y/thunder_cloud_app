import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_constants.dart';
import '../models/photo.dart';
import '../services/photo/local_photo_service.dart';
import '../services/photo/photo_service.dart';
import '../services/photo/user_service.dart';
import '../utils/logger.dart';
import 'gallery/gallery_downloaded_detail_screen.dart';
import 'gallery/gallery_photo_detail_screen.dart';

/// 写真アイテムの抽象インターface
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
  String get displayTitle => 'ローカル写真';

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
    await LocalPhotoService.deleteLocalPhoto(photo.id, AppConstants.defaultUserId);
    onRefresh();
  }

  @override
  Future<void> share() async {
    if (photo.imageUrl.startsWith('/')) {
      await Share.shareXFiles([XFile(photo.imageUrl)], text: '入道雲の写真をシェアします！');
    } else {
      await Share.share(photo.imageUrl, subject: '入道雲の写真');
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

/// ダウンロード済み写真アイテム
class DownloadedPhotoItem extends PhotoItem {
  final Map<String, dynamic> photoData;
  final VoidCallback onRefresh;

  DownloadedPhotoItem(this.photoData, this.onRefresh);

  @override
  String get id => photoData['id'];

  @override
  String get imageUrl => photoData['imageUrl'];

  @override
  DateTime get timestamp => (photoData['timestamp'] as Timestamp).toDate();

  @override
  String get displayTitle => 'ダウンロード済み';

  @override
  Widget buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDateTime(timestamp),
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          '投稿者: ${photoData['userName'] ?? '不明'}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        if (photoData['locationName'] != null)
          Text(
            photoData['locationName'],
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
      ],
    );
  }

  @override
  Future<void> delete() async {
    await PhotoService.deleteDownloadedPhoto(photoData['id'], AppConstants.defaultUserId);
    onRefresh();
  }

  @override
  Future<void> share() async {
    await Share.share(photoData['imageUrl'], subject: 'ダウンロードした入道雲の写真');
  }

  @override
  void openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GalleryDownloadedDetailScreen(photoData: photoData),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// ギャラリー画面 - ローカル写真とダウンロード済み写真を管理
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with SingleTickerProviderStateMixin {
  // データ管理
  List<Photo> _photos = [];
  List<Map<String, dynamic>> _downloadedPhotos = [];
  Map<String, dynamic> _userInfo = {};

  // UI状態管理
  bool _isLoading = true;
  bool _isLoadingDownloaded = true;
  bool _isLoadingUserInfo = true;
  bool _isGridView = true;
  bool _isSelectionMode = false;

  // 選択状態管理
  final Set<String> _selectedPhotos = {};
  final Set<String> _selectedDownloaded = {};

  // タブ管理
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ===== 初期化メソッド =====

  void _initializeTabController() {
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _loadAllData() {
    _loadUserInfo();
    _loadPhotos();
    _loadDownloadedPhotos();
  }

  /// 外部から呼び出し可能なデータ再読み込みメソッド
  void refreshData() {
    AppLogger.info('ギャラリーデータ再読み込み開始', tag: 'GalleryScreen');
    _loadAllData();
  }

  // ===== データ読み込みメソッド =====

  Future<void> _loadUserInfo() async {
    try {
      AppLogger.info('ユーザー情報読み込み開始', tag: 'GalleryScreen');
      final Map<String, dynamic> userInfo = await UserService.getUserInfo(AppConstants.defaultUserId);

      if (mounted) {
        setState(() {
          _userInfo = userInfo;
          _isLoadingUserInfo = false;
        });
      }

      AppLogger.success('ユーザー情報読み込み完了: ${userInfo['userName']}', tag: 'GalleryScreen');
    } catch (e) {
      AppLogger.error('ユーザー情報読み込みエラー', error: e, tag: 'GalleryScreen');
      if (mounted) {
        setState(() => _isLoadingUserInfo = false);
      }
    }
  }

  Future<void> _loadPhotos() async {
    try {
      AppLogger.info('ローカル写真読み込み開始', tag: 'GalleryScreen');
      if (mounted) setState(() => _isLoading = true);

      final List<Photo> photos = await LocalPhotoService.getUserLocalPhotos(AppConstants.defaultUserId);

      if (mounted) {
        setState(() {
          _photos = photos;
          _isLoading = false;
        });
      }

      AppLogger.success('ローカル写真読み込み完了: ${photos.length}件', tag: 'GalleryScreen');
    } catch (e) {
      AppLogger.error('ローカル写真読み込みエラー', error: e, tag: 'GalleryScreen');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDownloadedPhotos() async {
    try {
      AppLogger.info('ダウンロード済み写真読み込み開始', tag: 'GalleryScreen');
      if (mounted) setState(() => _isLoadingDownloaded = true);

      final List<Map<String, dynamic>> downloadedPhotos = await PhotoService.getDownloadedPhotos(AppConstants.defaultUserId);

      if (mounted) {
        setState(() {
          _downloadedPhotos = downloadedPhotos;
          _isLoadingDownloaded = false;
        });
      }

      AppLogger.success('ダウンロード済み写真読み込み完了: ${downloadedPhotos.length}件', tag: 'GalleryScreen');
    } catch (e) {
      AppLogger.error('ダウンロード済み写真読み込みエラー', error: e, tag: 'GalleryScreen');
      if (mounted) setState(() => _isLoadingDownloaded = false);
    }
  }

  // ===== イベントハンドラー =====

  void _onTabChanged() {
    if (mounted) {
      setState(() {
        _currentTabIndex = _tabController.index;
        _clearSelectionMode();
      });
    }
  }

  void _clearSelectionMode() {
    _isSelectionMode = false;
    _selectedPhotos.clear();
    _selectedDownloaded.clear();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPhotos.clear();
        _selectedDownloaded.clear();
      }
    });
  }

  void _toggleViewMode() {
    setState(() => _isGridView = !_isGridView);
  }

  // ===== 統合された削除処理メソッド =====

  Future<void> _deleteSelectedItems() async {
    final Set<String> selectedItems = _currentTabIndex == 0 ? _selectedPhotos : _selectedDownloaded;
    if (selectedItems.isEmpty) return;

    try {
      AppLogger.info('選択アイテム削除開始: ${selectedItems.length}件', tag: 'GalleryScreen');

      if (_currentTabIndex == 0) {
        // ローカル写真の削除
        for (final String photoId in selectedItems) {
          await LocalPhotoService.deleteLocalPhoto(photoId, AppConstants.defaultUserId);
        }
        if (mounted) {
          setState(() {
            _photos.removeWhere((Photo photo) => selectedItems.contains(photo.id));
            _clearSelectionMode();
          });
        }
      } else {
        // ダウンロード済み写真の削除
        for (final String photoId in selectedItems) {
          await PhotoService.deleteDownloadedPhoto(photoId, AppConstants.defaultUserId);
        }
        if (mounted) {
          setState(() {
            _downloadedPhotos.removeWhere((Map<String, dynamic> photo) => selectedItems.contains(photo['id']));
            _clearSelectionMode();
          });
        }
      }

      _showSuccessMessage('選択したアイテムを削除しました');
      AppLogger.success('アイテム削除完了', tag: 'GalleryScreen');
    } catch (e) {
      AppLogger.error('アイテム削除エラー', error: e, tag: 'GalleryScreen');
      _showErrorMessage('削除に失敗しました: $e');
    }
  }

  // ===== 統合された写真アイテム処理メソッド =====

  List<PhotoItem> _getCurrentPhotoItems() {
    if (_currentTabIndex == 0) {
      return _photos.map((Photo photo) => LocalPhotoItem(photo, () => setState(() {}))).toList();
    } else {
      return _downloadedPhotos.map((Map<String, dynamic> photoData) => DownloadedPhotoItem(photoData, () => setState(() {}))).toList();
    }
  }

  Set<String> _getCurrentSelectedItems() {
    return _currentTabIndex == 0 ? _selectedPhotos : _selectedDownloaded;
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      final Set<String> selectedItems = _getCurrentSelectedItems();
      if (selectedItems.contains(itemId)) {
        selectedItems.remove(itemId);
      } else {
        selectedItems.add(itemId);
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

  Widget _buildLocalFileImage(String imagePath) {
    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => _buildErrorPlaceholder(),
    );
  }

  Widget _buildNetworkImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (BuildContext context, String url) => _buildLoadingPlaceholder(),
      errorWidget: (BuildContext context, String url, Object error) => _buildErrorPlaceholder(),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.error, color: Colors.red, size: 50),
      ),
    );
  }

  // ===== UI構築メソッド =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColorLight,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('ギャラリー'),
      backgroundColor: AppConstants.primarySkyBlue,
      bottom: _buildTabBar(),
      actions: _buildAppBarActions(),
    );
  }

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'マイフォト', icon: Icon(Icons.photo_library)),
        Tab(text: 'ダウンロード', icon: Icon(Icons.download)),
      ],
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      IconButton(
        icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
        onPressed: _toggleViewMode,
        tooltip: _isGridView ? 'リスト表示' : 'グリッド表示',
      ),
      IconButton(
        icon: Icon(_isSelectionMode ? Icons.close : Icons.select_all),
        onPressed: _toggleSelectionMode,
        tooltip: _isSelectionMode ? '選択解除' : '選択モード',
      ),
      if (_isSelectionMode && _getCurrentSelectedItems().isNotEmpty)
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: _deleteSelectedItems,
          tooltip: '選択項目を削除',
        ),
    ];
  }

  Widget _buildBody() {
    if (_isLoadingUserInfo) {
      return _buildUserInfoLoading();
    }

    return Column(
      children: [
        _buildUserInfo(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPhotoTab(isLoading: _isLoading, isEmpty: _photos.isEmpty),
              _buildPhotoTab(isLoading: _isLoadingDownloaded, isEmpty: _downloadedPhotos.isEmpty),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('ユーザー情報を読み込み中...'),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppConstants.primarySkyBlue,
            child: Text(
              (_userInfo['userName'] as String? ?? 'U').substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userInfo['userName'] as String? ?? 'ユーザー',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'マイフォト: ${_photos.length}枚 | ダウンロード: ${_downloadedPhotos.length}枚',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTab({required bool isLoading, required bool isEmpty}) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isEmpty) {
      final message = _currentTabIndex == 0 ? 'まだ写真がありません' : 'ダウンロードした写真がありません';
      final icon = _currentTabIndex == 0 ? Icons.photo_library : Icons.download;
      return _buildEmptyState(message, icon);
    }

    return _isGridView ? _buildUnifiedGridView() : _buildUnifiedListView();
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'カメラで写真を撮影してみましょう！',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // ===== 統合されたビュー構築メソッド =====

  Widget _buildUnifiedGridView() {
    final items = _getCurrentPhotoItems();
    final selectedItems = _getCurrentSelectedItems();

    return GridView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildGridItem(
          imageWidget: _buildItemImage(item),
          isSelected: selectedItems.contains(item.id),
          onTap: () => _onItemTap(item),
        );
      },
    );
  }

  Widget _buildUnifiedListView() {
    final items = _getCurrentPhotoItems();
    final selectedItems = _getCurrentSelectedItems();

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildListItem(
          imageWidget: _buildItemImage(item),
          title: item.displayTitle,
          subtitle: item.buildSubtitle(),
          isSelected: selectedItems.contains(item.id),
          onTap: () => _onItemTap(item),
        );
      },
    );
  }

  Widget _buildGridItem({
    required Widget imageWidget,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageWidget,
            ),
          ),
          if (_isSelectionMode) _buildSelectionIndicator(isSelected),
        ],
      ),
    );
  }

  Widget _buildSelectionIndicator(bool isSelected) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primarySkyBlue : Colors.white.withOpacity(0.8),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppConstants.primarySkyBlue,
            width: 2,
          ),
        ),
        child: Icon(
          isSelected ? Icons.check : null,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildListItem({
    required Widget imageWidget,
    required String title,
    required Widget subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      child: ListTile(
        leading: Stack(
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageWidget,
              ),
            ),
            if (_isSelectionMode) _buildSelectionIndicator(isSelected),
          ],
        ),
        title: Text(title),
        subtitle: subtitle,
        onTap: onTap,
      ),
    );
  }

  // ===== メッセージ表示メソッド =====

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}