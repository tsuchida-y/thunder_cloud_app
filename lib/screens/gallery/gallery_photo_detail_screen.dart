import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../models/photo.dart';
import '../../utils/logger.dart';

/// ローカル写真の詳細表示画面
class GalleryPhotoDetailScreen extends StatelessWidget {
  final Photo photo;

  const GalleryPhotoDetailScreen({
    super.key,
    required this.photo,
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
    final imageFile = File(photo.imageUrl);

    if (imageFile.existsSync()) {
      return Image.file(
        imageFile,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          AppLogger.error('画像読み込みエラー: ${photo.imageUrl}', error: error, tag: 'GalleryPhotoDetailScreen');
          return _buildErrorWidget();
        },
      );
    } else {
      AppLogger.warning('画像ファイルが存在しません: ${photo.imageUrl}', tag: 'GalleryPhotoDetailScreen');
      return _buildErrorWidget();
    }
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('写真情報'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('撮影日時', _formatDateTime(photo.timestamp)),
              _buildInfoRow('ユーザー名', photo.userName),
              if (photo.weatherData.isNotEmpty) ...[
                const SizedBox(height: AppConstants.paddingMedium),
                const Text(
                  '気象データ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppConstants.fontSizeMedium,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                ..._buildWeatherInfo(),
              ],
            ],
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

  /// 情報行を構築
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingXSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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

  /// 気象情報を構築
  List<Widget> _buildWeatherInfo() {
    final weatherWidgets = <Widget>[];

    // 各方向の気象データを表示
    for (final direction in ['north', 'south', 'east', 'west']) {
      if (photo.weatherData.containsKey(direction)) {
        final directionData = photo.weatherData[direction] as Map<String, dynamic>?;
        if (directionData != null) {
          weatherWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_getDirectionName(direction)}方向',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppConstants.fontSizeSmall,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXSmall),
                  if (directionData['temperature'] != null)
                    _buildInfoRow('気温', '${directionData['temperature'].toStringAsFixed(1)}°C'),
                  if (directionData['cape'] != null)
                    _buildInfoRow('CAPE', '${directionData['cape'].toStringAsFixed(1)} J/kg'),
                  if (directionData['lifted_index'] != null)
                    _buildInfoRow('LI', directionData['lifted_index'].toStringAsFixed(1)),
                  if (directionData['cloud_cover'] != null)
                    _buildInfoRow('雲量', '${directionData['cloud_cover'].toStringAsFixed(1)}%'),
                ],
              ),
            ),
          );
        }
      }
    }

    return weatherWidgets;
  }

  /// 方向名を取得
  String _getDirectionName(String direction) {
    switch (direction) {
      case 'north': return '北';
      case 'south': return '南';
      case 'east': return '東';
      case 'west': return '西';
      default: return direction;
    }
  }

  /// 日時をフォーマット
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/'
           '${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}