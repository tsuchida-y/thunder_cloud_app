import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// ダウンロード済み写真の詳細表示画面
class GalleryDownloadedDetailScreen extends StatelessWidget {
  final Map<String, dynamic> photoData;

  const GalleryDownloadedDetailScreen({
    super.key,
    required this.photoData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('写真詳細'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showPhotoInfo(context),
            tooltip: '詳細情報',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: _buildPhotoImage(),
        ),
      ),
    );
  }

  /// 写真画像を構築
  Widget _buildPhotoImage() {
    final imageUrl = photoData['imageUrl'] as String? ?? '';

    if (imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildLoadingWidget(),
        errorWidget: (context, url, error) {
          AppLogger.error('ネットワーク画像読み込みエラー: $url', error: error, tag: 'GalleryDownloadedDetailScreen');
          return _buildErrorWidget();
        },
      );
    } else {
      AppLogger.warning('画像URLが空です', tag: 'GalleryDownloadedDetailScreen');
      return _buildErrorWidget();
    }
  }

  /// ローディング表示ウィジェット
  Widget _buildLoadingWidget() {
    return Container(
      width: 200,
      height: 200,
      color: Colors.grey[800],
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primarySkyBlue),
        ),
      ),
    );
  }

  /// エラー表示ウィジェット
  Widget _buildErrorWidget() {
    return Container(
      width: 200,
      height: 200,
      color: Colors.grey[800],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.white,
            size: AppConstants.iconSizeLarge,
          ),
          SizedBox(height: AppConstants.paddingMedium),
          Text(
            '画像を読み込めません',
            style: TextStyle(
              color: Colors.white,
              fontSize: AppConstants.fontSizeMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// 写真情報ダイアログを表示
  void _showPhotoInfo(BuildContext context) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      photoData['downloadedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('写真情報'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: _buildPhotoInfo(timestamp),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  /// 写真情報を構築
  List<Widget> _buildPhotoInfo(DateTime timestamp) {
    return [
      _buildInfoRow('ダウンロード日時', _formatDateTime(timestamp)),
      _buildInfoRow('投稿者', photoData['userName'] as String? ?? '不明'),
      _buildInfoRow('場所', photoData['locationName'] as String? ?? '不明'),
      if (photoData['latitude'] != null && photoData['longitude'] != null) ...[
        _buildInfoRow('緯度', (photoData['latitude'] as num).toStringAsFixed(6)),
        _buildInfoRow('経度', (photoData['longitude'] as num).toStringAsFixed(6)),
      ],
      if (photoData['likes'] != null)
        _buildInfoRow('いいね数', photoData['likes'].toString()),
      if (photoData['comments'] != null)
        _buildInfoRow('コメント数', photoData['comments'].toString()),
    ];
  }

  /// 情報行を構築
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingXSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppConstants.fontSizeSmall,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: AppConstants.fontSizeSmall),
            ),
          ),
        ],
      ),
    );
  }

  /// 日時をフォーマット
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/'
           '${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}