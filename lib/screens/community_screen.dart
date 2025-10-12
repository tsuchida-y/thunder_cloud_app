import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../models/photo.dart';
import '../utils/logger.dart';
import 'community/community_photo_card.dart';
// import 'community/community_profile_dialog.dart'; // ファイルが存在しないためコメントアウト
import 'community/community_service.dart';

/// コミュニティ画面 - ユーザーが投稿した写真を閲覧・管理
class CommunityScreen extends StatefulWidget {
  final VoidCallback? onPhotoDownloaded;

  const CommunityScreen({
    super.key,
    this.onPhotoDownloaded,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  /*
  ================================================================================
                                    状態管理
                        コミュニティ画面の状態を管理する変数群
  ================================================================================
  */
  List<Photo> _photos = [];
  bool _isLoading = true;
  bool _hasMore = true;
  String? _currentUserId; // 現在のユーザーIDを保持

  /*
  ================================================================================
                                    サービス
                           コミュニティ機能で使用するサービス
  ================================================================================
  */
  late final CommunityService _communityService;

  /*
  ================================================================================
                                 コントローラー
                         スクロール制御とリフレッシュ制御用コントローラー
  ================================================================================
  */
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService();
    _initializeScreen();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _communityService.dispose(); // CommunityServiceのリソースを解放
    super.dispose();
  }

  /*
  ================================================================================
                                    初期化
                        サービス初期化とデータ読み込みの開始処理
  ================================================================================
  */

  /// 画面の初期化
  Future<void> _initializeScreen() async {
    AppLogger.info('コミュニティ画面初期化開始', tag: 'CommunityScreen');

    // ユーザーIDを取得
    _currentUserId = await AppConstants.getCurrentUserId();

    // CommunityServiceを初期化
    await _communityService.initialize();

    // 写真を読み込み
    await _loadPhotos();

    AppLogger.success('コミュニティ画面初期化完了', tag: 'CommunityScreen');
  }

  /*
  ================================================================================
                               データ読み込み
                        コミュニティ写真データの取得と状態更新処理
  ================================================================================
  */

  /// 写真一覧を読み込み
  Future<void> _loadPhotos({bool isRefresh = false}) async {
    // 初期読み込み以外で既に読み込み中の場合はスキップ
    if (!isRefresh && _isLoading && _photos.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      if (isRefresh) {
        _photos.clear();
        _hasMore = true;
      }
    });

    try {
      final result = await _communityService.loadPhotos(
        isInitialLoad: isRefresh || _photos.isEmpty,
      );

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _photos = result.photos;
          } else {
            _photos.addAll(result.photos);
          }
          _hasMore = result.hasMore;
          _isLoading = false;
        });
      }

      AppLogger.success('写真読み込み完了: ${result.photos.length}件', tag: 'CommunityScreen');
    } catch (e) {
      AppLogger.error('写真読み込みエラー', error: e, tag: 'CommunityScreen');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('写真の読み込みに失敗しました');
      }
    }
  }

  /// 追加の写真を読み込み
  Future<void> _loadMorePhotos() async {
    if (!_hasMore || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _communityService.loadMorePhotos(_photos);

      if (mounted) {
        setState(() {
          _photos.addAll(result.photos);
          _hasMore = result.hasMore;
          _isLoading = false;
        });
      }

      AppLogger.info('追加写真読み込み完了: ${result.photos.length}件', tag: 'CommunityScreen');
    } catch (e) {
      AppLogger.error('追加写真読み込みエラー', error: e, tag: 'CommunityScreen');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /*
  ================================================================================
                               イベントハンドラー
                        ユーザー操作（ダウンロード・いいね）への応答処理
  ================================================================================
  */

  /// スクロールイベント処理
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - AppConstants.scrollThreshold &&
        _hasMore && !_isLoading) {
      _loadMorePhotos();
    }
  }

  /// データ再読み込み（外部から呼び出し可能）
  void refreshData() {
    AppLogger.info('コミュニティデータ再読み込み', tag: 'CommunityScreen');
    _communityService.clearCache();
    _loadPhotos(isRefresh: true);
  }

  /// いいねの切り替え
  Future<void> _onLikeToggle(Photo photo) async {
    try {
      // いいね操作を実行し、更新された写真データを取得
      final updatedPhoto = await _communityService.toggleLike(photo);

      if (updatedPhoto != null && mounted) {
        // 写真リスト内の該当写真を更新
        setState(() {
          final index = _photos.indexWhere((p) => p.id == photo.id);
          if (index != -1) {
            _photos[index] = updatedPhoto;
          }
        });

        AppLogger.info('いいね切り替え完了: ${photo.id} (いいね数: ${updatedPhoto.likes})', tag: 'CommunityScreen');
      }
    } catch (e) {
      AppLogger.error('いいね切り替えエラー', error: e, tag: 'CommunityScreen');
      _showErrorSnackBar('いいねの更新に失敗しました');
    }
  }

  /// 写真のダウンロード
  Future<void> _onPhotoDownload(Photo photo) async {
    try {
      AppLogger.info('写真ダウンロード開始: ${photo.id}', tag: 'CommunityScreen');

      await _communityService.downloadPhoto(photo);

      if (mounted) {
        _showSuccessSnackBar('写真をギャラリーに保存しました');

        AppLogger.info('ギャラリー更新コールバック呼び出し', tag: 'CommunityScreen');
        widget.onPhotoDownloaded?.call();
      }

      AppLogger.success('写真ダウンロード完了: ${photo.id}', tag: 'CommunityScreen');
    } catch (e) {
      AppLogger.error('写真ダウンロードエラー', error: e, tag: 'CommunityScreen');
      _showErrorSnackBar('写真のダウンロードに失敗しました');
    }
  }

  /// 写真の削除
  Future<void> _onPhotoDelete(Photo photo) async {
    final confirmed = await _showDeleteConfirmDialog(photo);
    if (!confirmed) return;

    try {
      await _communityService.deletePhoto(photo.id);

      if (mounted) {
        setState(() {
          _photos.removeWhere((p) => p.id == photo.id);
        });
        _showSuccessSnackBar('写真を削除しました');
      }

      AppLogger.success('写真削除完了: ${photo.id}', tag: 'CommunityScreen');
    } catch (e) {
      AppLogger.error('写真削除エラー', error: e, tag: 'CommunityScreen');
      _showErrorSnackBar('写真の削除に失敗しました');
    }
  }

  /*
  ================================================================================
                                   UI構築
                          画面レイアウトとウィジェット構築処理
  ================================================================================
  */

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppConstants.backgroundColorLight,
      child: _buildBody(),
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

    return RefreshIndicator(
      onRefresh: () => _loadPhotos(isRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        itemCount: _photos.length + (_hasMore ? 1 : 0),
        itemBuilder: _buildPhotoItem,
      ),
    );
  }

  /// 写真アイテムを構築
  Widget _buildPhotoItem(BuildContext context, int index) {
    if (index >= _photos.length) {
      return _buildLoadingIndicator();
    }

    final photo = _photos[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      child: CommunityPhotoCard(
        photo: photo,
        currentUserId: _currentUserId ?? '',
        onLikeToggle: () => _onLikeToggle(photo),
        onDownload: () => _onPhotoDownload(photo),
        onDelete: () => _onPhotoDelete(photo),
        communityService: _communityService,
      ),
    );
  }

  /// ローディングインジケーターを構築
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.paddingLarge),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primarySkyBlue),
        ),
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
            '2週間以内に投稿された写真はありません',
            style: TextStyle(
              fontSize: AppConstants.fontSizeLarge,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          Text(
            'カメラボタンから写真を投稿してみましょう！',
            style: TextStyle(
              fontSize: AppConstants.fontSizeMedium,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /*
  ================================================================================
                             ダイアログ・スナックバー
                         確認ダイアログとメッセージ表示の処理
  ================================================================================
  */

  /// 削除確認ダイアログを表示
  Future<bool> _showDeleteConfirmDialog(Photo photo) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('写真を削除'),
        content: const Text('この写真を削除しますか？\nこの操作は取り消せません。'),
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
    ) ?? false;
  }

  /// エラースナックバーを表示
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: AppConstants.snackBarDurationSeconds),
      ),
    );
  }

  /// 成功スナックバーを表示
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: AppConstants.snackBarDurationSeconds),
      ),
    );
  }
}
