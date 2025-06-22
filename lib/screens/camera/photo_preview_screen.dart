import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/app_constants.dart';
import '../../services/location/location_service.dart';
import '../../services/photo/local_photo_service.dart';
import '../../services/photo/photo_service.dart';
import '../../services/weather/weather_data_service.dart';
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
            onPressed: _isSaving ? null : _savePhotoLocally,
          ),
          _buildActionButton(
            icon: Icons.share,
            label: 'シェア',
            onPressed: _isSaving ? null : _sharePhoto,
          ),
          _buildActionButton(
            icon: Icons.close,
            label: '戻る',
            onPressed: () => Navigator.of(context).pop(),
            color: Colors.grey,
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

  /// 写真をローカルに保存
  Future<void> _savePhotoLocally() async {
    setState(() {
      _isSaving = true;
    });

    try {
      AppLogger.info('ローカル保存開始', tag: 'PhotoPreviewScreen');

      // 位置情報を取得
      final location = await LocationService.getCurrentLocationAsLatLng();
      AppLogger.info('位置情報取得: $location', tag: 'PhotoPreviewScreen');

      // 気象データを取得
      Map<String, dynamic>? weatherData;
      if (location != null) {
        try {
          await WeatherDataService.instance.fetchAndStoreWeatherData(location);
          final lastWeatherData = WeatherDataService.instance.lastWeatherData;
          if (lastWeatherData.isNotEmpty) {
            weatherData = lastWeatherData;
          }
          AppLogger.info('気象データ取得成功', tag: 'PhotoPreviewScreen');
        } catch (e) {
          AppLogger.warning('気象データ取得失敗: $e', tag: 'PhotoPreviewScreen');
        }
      }

      // ローカルに保存
      await LocalPhotoService.savePhotoLocally(
        imageFile: widget.imageFile,
        userId: AppConstants.currentUserId,
        userName: 'ユーザー',
        latitude: location?.latitude,
        longitude: location?.longitude,
        locationName: '撮影地点',
        weatherData: weatherData,
      );

      if (mounted) {
        _showLocalSaveSuccessDialog();
      }

      AppLogger.success('ローカル保存完了', tag: 'PhotoPreviewScreen');
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

  /// 写真をシェア
  Future<void> _sharePhoto() async {
    setState(() {
      _isSaving = true;
    });

    try {
      AppLogger.info('シェア処理開始', tag: 'PhotoPreviewScreen');

      // 位置情報を取得
      final location = await LocationService.getCurrentLocationAsLatLng();
      AppLogger.info('位置情報取得: $location', tag: 'PhotoPreviewScreen');

      // 気象データを取得
      Map<String, dynamic>? weatherData;
      if (location != null) {
        try {
          await WeatherDataService.instance.fetchAndStoreWeatherData(location);
          final lastWeatherData = WeatherDataService.instance.lastWeatherData;
          if (lastWeatherData.isNotEmpty) {
            weatherData = lastWeatherData;
          }
          AppLogger.info('気象データ取得成功', tag: 'PhotoPreviewScreen');
        } catch (e) {
          AppLogger.warning('気象データ取得失敗: $e', tag: 'PhotoPreviewScreen');
        }
      }

      // Firestoreに保存
      await PhotoService.uploadPhoto(
        imageFile: widget.imageFile,
        userId: AppConstants.currentUserId,
        userName: 'ユーザー',
      );

      // ローカルにも保存
      await LocalPhotoService.savePhotoLocally(
        imageFile: widget.imageFile,
        userId: AppConstants.currentUserId,
        userName: 'ユーザー',
        latitude: location?.latitude,
        longitude: location?.longitude,
        locationName: '撮影地点',
        weatherData: weatherData,
      );

      // システムのシェア機能を使用
      await Share.shareXFiles(
        [XFile(widget.imageFile.path)],
        text: '入道雲の写真をシェアします！ #入道雲サーチ',
      );

      if (mounted) {
        _showShareAndSaveSuccessDialog();
      }

      AppLogger.success('シェア処理完了', tag: 'PhotoPreviewScreen');
    } catch (e) {
      AppLogger.error('シェア処理エラー', error: e, tag: 'PhotoPreviewScreen');

      if (mounted) {
        _showErrorDialog('シェアに失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ===== ダイアログ表示 =====

  /// ローカル保存成功ダイアログを表示
  void _showLocalSaveSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('保存完了'),
          ],
        ),
        content: const Text('写真をローカルに保存しました。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // ダイアログを閉じる
              Navigator.of(context).pop(); // プレビュー画面を閉じる
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// シェア・保存成功ダイアログを表示
  void _showShareAndSaveSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('シェア・保存完了'),
          ],
        ),
        content: const Text('写真をシェアし、コミュニティとローカルに保存しました。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // ダイアログを閉じる
              Navigator.of(context).pop(); // プレビュー画面を閉じる
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// エラーダイアログを表示
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
