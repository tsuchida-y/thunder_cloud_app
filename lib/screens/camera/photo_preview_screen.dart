import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../navigation/app_routes.dart';
import '../../services/location/location_service.dart';
import '../../services/photo/local_photo_service.dart';
import '../../utils/logger.dart';

/// 撮影した写真のプレビュー画面
class PhotoPreviewScreen extends StatefulWidget {
  final File imageFile;

  const PhotoPreviewScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  /*
  ================================================================================
                                    状態管理
                          写真保存処理の進行状態を管理する変数
  ================================================================================
  */
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  /// アプリバーを構築
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        '写真プレビュー',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: AppConstants.primarySkyBlue,
      foregroundColor: Colors.white,
      elevation: AppConstants.elevationMedium,
    );
  }

  /// メインボディを構築
  Widget _buildBody() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          child: Image.file(
            widget.imageFile,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  /// 下部アクションを構築
  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: const BoxDecoration(
        color: Colors.black87,
        border: Border(
          top: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.save_alt,
            label: 'ローカル保存',
            onPressed: _isSaving ? null : _saveLocally,
          ),
        ],
      ),
    );
  }

  /// アクションボタンを構築
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? AppConstants.primarySkyBlue,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
          ),
          child: Icon(icon, size: AppConstants.iconSizeLarge),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: AppConstants.fontSizeSmall,
          ),
        ),
      ],
    );
  }

  /// 写真のローカル保存処理
  /// 位置情報取得→ローカル保存→ギャラリー画面遷移の流れで実行
  /// 用途：個人的な記録保存（コミュニティ投稿なし）
  Future<void> _saveLocally() async {
    final startTime = DateTime.now();
    setState(() {
      _isSaving = true;
    });

    try {
      AppLogger.info('ローカル保存開始', tag: 'PhotoPreviewScreen');

      // 位置情報を取得
      final location = await LocationService.getCurrentLocationAsLatLng();
      AppLogger.info('位置情報取得: $location', tag: 'PhotoPreviewScreen');

      // ユーザーIDを動的に取得
      final userId = await AppConstants.getCurrentUserId();

      // ローカルに保存
      final saved = await LocalPhotoService.savePhotoLocally(
        imageFile: widget.imageFile,
        userId: userId,
        userName: 'ユーザー',
        latitude: location?.latitude,
        longitude: location?.longitude,
        locationName: '撮影地点',
      );
      if (!saved) {
        throw Exception('写真を保存できませんでした');
      }

      if (mounted) {
        _navigateToGallery();
      }

      final duration = DateTime.now().difference(startTime);
      AppLogger.success('ローカル保存完了 (${duration.inMilliseconds}ms)', tag: 'PhotoPreviewScreen');
    } catch (e) {
      AppLogger.error('ローカル保存エラー', error: e, tag: 'PhotoPreviewScreen');

      if (mounted) {
        _showErrorDialog('ローカル保存に失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /*
  ================================================================================
                                ダイアログ表示
                         エラー・成功メッセージのダイアログ表示処理
  ================================================================================
  */

  /// ローカル保存後の画面遷移処理
  /// プレビュー画面とカメラ画面を閉じてホームに戻る（記録画面への案内はステップ8で作る）
  void _navigateToGallery() {
    AppRoutes.backToHome(context);
  }

  /// エラーダイアログの表示処理
  /// アイコン付きのユーザーフレンドリーなエラー表示
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('エラー'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
