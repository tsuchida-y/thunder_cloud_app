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
  // ユーザー情報の動的取得を削除（写真データのuserNameを直接使用）

  @override
  void initState() {
    super.initState();
    // ユーザー情報の読み込みを削除
  }

  @override
  void didUpdateWidget(CommunityPhotoCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 写真データが更新された場合はUIを再構築
    if (oldWidget.photo.id != widget.photo.id ||
        oldWidget.photo.likes != widget.photo.likes ||
        oldWidget.photo.likedBy.length != widget.photo.likedBy.length) {
      // setState は不要（build メソッドが自動的に呼ばれる）
      AppLogger.info('写真データ更新を検知: ${widget.photo.id} (いいね数: ${widget.photo.likes})', tag: 'CommunityPhotoCard');
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
    // ユーザー情報の動的取得を削除（写真データのuserNameを直接使用）
    final userName = widget.photo.userName;

    if (userName.isNotEmpty) {
      return CircleAvatar(
        radius: AppConstants.avatarRadiusSmall,
        backgroundColor: AppConstants.primarySkyBlue,
        child: Text(
          userName.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return const CircleAvatar(
      radius: AppConstants.avatarRadiusSmall,
      backgroundColor: Colors.grey,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  /// ユーザー名と日付を構築
  Widget _buildUserNameAndDate() {
    final userName = widget.photo.userName;
    final timestamp = widget.photo.timestamp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          userName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppConstants.fontSizeMedium,
          ),
        ),
        const SizedBox(height: AppConstants.paddingXSmall),
        Text(
          _formatDateTime(timestamp),
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
    final likeCount = widget.photo.likes; // 写真オブジェクトから直接取得

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
