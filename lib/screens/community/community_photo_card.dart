import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../models/photo.dart';
import '../../utils/logger.dart';
import 'community_service.dart';

/// コミュニティ画面で使用する写真カードウィジェット
class CommunityPhotoCard extends StatefulWidget {
  final Photo photo;
  final String currentUserId;
  final VoidCallback onLikeToggle;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final CommunityService communityService;

  const CommunityPhotoCard({
    super.key,
    required this.photo,
    required this.currentUserId,
    required this.onLikeToggle,
    required this.onDownload,
    required this.onDelete,
    required this.communityService,
  });

  @override
  State<CommunityPhotoCard> createState() => _CommunityPhotoCardState();
}

class _CommunityPhotoCardState extends State<CommunityPhotoCard> {
  /*
  ================================================================================
                                    状態管理
                         写真カードの状態を管理する変数群
  ================================================================================
  */
  Map<String, dynamic>? _userInfo;
  bool _isLoadingUserInfo = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// ユーザー情報を読み込み
  Future<void> _loadUserInfo() async {
    try {
      final userInfo = await widget.communityService.getUserInfo(widget.photo.userId);
      if (mounted) {
        setState(() {
          _userInfo = userInfo;
          _isLoadingUserInfo = false;
        });
      }
    } catch (e) {
      AppLogger.error('ユーザー情報読み込みエラー', error: e, tag: 'CommunityPhotoCard');
      if (mounted) {
        setState(() {
          _isLoadingUserInfo = false;
        });
      }
    }
  }

  /*
  ================================================================================
                                   UI構築
                          写真カードのレイアウトとウィジェット構築処理
  ================================================================================
  */
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppConstants.elevationMedium,
      margin: const EdgeInsets.symmetric(
        vertical: AppConstants.paddingSmall,
        horizontal: AppConstants.paddingXSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserHeader(),
          _buildPhotoImage(),
          _buildPhotoActions(),
          _buildPhotoInfo(),
        ],
      ),
    );
  }

  /// ユーザーヘッダーを構築
  Widget _buildUserHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Row(
        children: [
          _buildUserAvatar(),
          const SizedBox(width: AppConstants.paddingMedium),
          Expanded(child: _buildUserNameAndDate()),
          if (widget.photo.userId == widget.currentUserId) _buildDeleteButton(),
        ],
      ),
    );
  }

  /// ユーザーアバターを構築
  Widget _buildUserAvatar() {
    if (_isLoadingUserInfo) {
      return const CircleAvatar(
        radius: AppConstants.avatarRadiusSmall,
        backgroundColor: Colors.grey,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final avatarUrl = _userInfo?['avatarUrl'] as String?;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: AppConstants.avatarRadiusSmall,
        backgroundImage: CachedNetworkImageProvider(avatarUrl),
        onBackgroundImageError: (_, __) => AppLogger.warning(
          'アバター画像読み込みエラー: $avatarUrl',
          tag: 'CommunityPhotoCard',
        ),
      );
    }

    return CircleAvatar(
      radius: AppConstants.avatarRadiusSmall,
      backgroundColor: AppConstants.primarySkyBlue,
      child: Text(
        (_userInfo?['userName'] as String? ?? 'U').substring(0, 1).toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// ユーザー名と日付を構築
  Widget _buildUserNameAndDate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _userInfo?['userName'] as String? ?? 'ロード中...',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppConstants.fontSizeMedium,
          ),
        ),
        const SizedBox(height: AppConstants.paddingXSmall),
        Text(
          _formatDateTime(widget.photo.timestamp),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: AppConstants.fontSizeSmall,
          ),
        ),
      ],
    );
  }

  /// 削除ボタンを構築
  Widget _buildDeleteButton() {
    return IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      onPressed: widget.onDelete,
      tooltip: '写真を削除',
    );
  }

  /// 写真画像を構築
  Widget _buildPhotoImage() {
    return AspectRatio(
      aspectRatio: AppConstants.photoAspectRatio,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.borderRadiusSmall),
        ),
        child: CachedNetworkImage(
          imageUrl: widget.photo.imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) {
            AppLogger.error('写真読み込みエラー: $url', error: error, tag: 'CommunityPhotoCard');
            return Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: AppConstants.iconSizeLarge,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 写真アクションを構築
  Widget _buildPhotoActions() {
    final isLiked = widget.communityService.getLikeStatus(widget.photo.id);
    final likeCount = widget.communityService.getLikeCount(widget.photo.id, widget.photo.likes);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.grey,
            ),
            onPressed: widget.onLikeToggle,
            tooltip: isLiked ? 'いいねを取り消す' : 'いいね',
          ),
          Text(
            '$likeCount',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: AppConstants.fontSizeSmall,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.blue),
            onPressed: widget.onDownload,
            tooltip: '写真をダウンロード',
          ),
        ],
      ),
    );
  }

  /// 写真情報を構築
  Widget _buildPhotoInfo() {
    // 撮影地点情報を表示しないため、空のウィジェットを返す
    return const SizedBox.shrink();
  }

  /// 日時をフォーマット
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/'
           '${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
