import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../services/photo/camera_service.dart';
import '../utils/logger.dart';
import 'camera/photo_preview_screen.dart';

/// カメラ画面 - 入道雲の撮影機能を提供
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // ===== 状態管理 =====
  bool _isLoading = true;
  bool _isInitialized = false;
  bool _isTakingPhoto = false;
  String? _errorMessage;

  // ===== カメラ設定 =====
  FlashMode _flashMode = FlashMode.off;
  double _zoomLevel = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    CameraService.dispose();
    super.dispose();
  }

  // ===== カメラ初期化 =====

  /// カメラを初期化
  Future<void> _initializeCamera() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      AppLogger.info('カメラ初期化開始', tag: 'CameraScreen');

      final success = await CameraService.initialize();

      if (success) {
        // ズーム範囲を取得
        await _initializeZoomRange();

        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        AppLogger.success('カメラ初期化成功', tag: 'CameraScreen');
      } else {
        setState(() {
          _isInitialized = false;
          _isLoading = false;
          _errorMessage = 'カメラの初期化に失敗しました。\n設定でカメラへのアクセスを許可してください。';
        });
        AppLogger.error('カメラ初期化失敗', tag: 'CameraScreen');
      }
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _isLoading = false;
        _errorMessage = 'カメラの初期化中にエラーが発生しました：\n$e';
      });
      AppLogger.error('カメラ初期化エラー', error: e, tag: 'CameraScreen');
    }
  }

  /// ズーム範囲を初期化
  Future<void> _initializeZoomRange() async {
    final controller = CameraService.controller;
    if (controller != null && controller.value.isInitialized) {
      try {
        _maxZoom = await controller.getMaxZoomLevel();
        _minZoom = await controller.getMinZoomLevel();
        AppLogger.info('ズーム範囲: ${_minZoom.toStringAsFixed(1)}x - ${_maxZoom.toStringAsFixed(1)}x', tag: 'CameraScreen');
      } catch (e) {
        AppLogger.error('ズーム範囲取得エラー', error: e, tag: 'CameraScreen');
        _maxZoom = 1.0;
        _minZoom = 1.0;
      }
    }
  }

  // ===== カメラ操作 =====

  /// 写真を撮影
  Future<void> _takePicture() async {
    if (!_isInitialized || _isTakingPhoto) return;

    setState(() {
      _isTakingPhoto = true;
    });

    try {
      AppLogger.info('写真撮影開始', tag: 'CameraScreen');

      final File? imageFile = await CameraService.takePicture();

      if (imageFile != null) {
        AppLogger.success('写真撮影成功: ${imageFile.path}', tag: 'CameraScreen');

        // プレビュー画面に遷移
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PhotoPreviewScreen(
                imageFile: imageFile,
              ),
            ),
          );
        }
      } else {
        AppLogger.error('写真撮影失敗', tag: 'CameraScreen');
        if (mounted) {
          _showErrorSnackBar('写真の撮影に失敗しました');
        }
      }
    } catch (e) {
      AppLogger.error('写真撮影エラー', error: e, tag: 'CameraScreen');
      if (mounted) {
        _showErrorSnackBar('写真撮影エラー: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPhoto = false;
        });
      }
    }
  }

  /// フラッシュモードを切り替え
  void _toggleFlash() {
    CameraService.toggleFlash();
    setState(() {
      _flashMode = _flashMode == FlashMode.off ? FlashMode.auto : FlashMode.off;
    });
  }

  /// ズームレベルを設定
  void _setZoomLevel(double zoom) {
    final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
    CameraService.setZoomLevel(clampedZoom);
    setState(() {
      _zoomLevel = clampedZoom;
    });
  }

  // ===== UI構築 =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// アプリバーを構築
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.camera_alt,
            color: Colors.white,
            size: AppConstants.iconSizeLarge,
          ),
          SizedBox(width: AppConstants.paddingSmall),
          Text(
            "入道雲を撮影",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      centerTitle: true,
      backgroundColor: AppConstants.primarySkyBlue,
      foregroundColor: Colors.white,
      elevation: AppConstants.elevationMedium,
      shadowColor: Colors.black54,
    );
  }

  /// メインボディを構築
  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (!_isInitialized) {
      return _buildNotInitializedState();
    }

    return Stack(
      children: [
        _buildCameraPreview(),
        _buildOverlayControls(),
      ],
    );
  }

  /// ローディング状態を構築
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primarySkyBlue),
          ),
          SizedBox(height: AppConstants.paddingLarge),
          Text(
            'カメラを初期化中...',
            style: TextStyle(
              color: Colors.white,
              fontSize: AppConstants.fontSizeLarge,
            ),
          ),
        ],
      ),
    );
  }

  /// エラー状態を構築
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: AppConstants.iconSizeXLarge,
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppConstants.fontSizeLarge,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            ElevatedButton(
              onPressed: _initializeCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primarySkyBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  /// 未初期化状態を構築
  Widget _buildNotInitializedState() {
    return const Center(
      child: Text(
        'カメラが利用できません',
        style: TextStyle(
          color: Colors.white,
          fontSize: AppConstants.fontSizeLarge,
        ),
      ),
    );
  }

  /// カメラプレビューを構築
  Widget _buildCameraPreview() {
    final controller = CameraService.controller;

    if (controller != null && controller.value.isInitialized) {
      return SizedBox.expand(
        child: GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: CameraPreview(controller),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'カメラプレビューが利用できません',
          style: TextStyle(
            color: Colors.white,
            fontSize: AppConstants.fontSizeMedium,
          ),
        ),
      ),
    );
  }

    // ピンチズーム用の変数
  double _baseZoomLevel = 1.0;

  /// ピンチズーム開始
  void _onScaleStart(ScaleStartDetails details) {
    _baseZoomLevel = _zoomLevel;
  }

  /// ピンチズーム更新
  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_isInitialized || _maxZoom <= 1.0) return;

    // スケール値からズームレベルを計算
    final newZoomLevel = (_baseZoomLevel * details.scale).clamp(_minZoom, _maxZoom);

    // ズームレベルが変更された場合のみ更新（スムーズな動作のため閾値を小さく）
    if ((newZoomLevel - _zoomLevel).abs() > 0.05) {
      _setZoomLevel(newZoomLevel);
    }
  }

  /// オーバーレイコントロールを構築
  Widget _buildOverlayControls() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopControls(),
          const Spacer(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  /// 上部コントロールを構築
  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildFlashButton(),
          _buildZoomIndicator(),
        ],
      ),
    );
  }

  /// フラッシュボタンを構築
  Widget _buildFlashButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
      ),
      child: IconButton(
        icon: Icon(
          _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_auto,
          color: Colors.white,
        ),
        onPressed: _toggleFlash,
        tooltip: 'フラッシュ切り替え',
      ),
    );
  }

  /// ズームインジケーターを構築
  Widget _buildZoomIndicator() {
    // ズーム範囲が1.0のみの場合は表示しない
    if (_maxZoom <= 1.0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.zoom_in, color: Colors.white, size: 16),
          const SizedBox(width: AppConstants.paddingSmall),
          Text(
            '${_zoomLevel.toStringAsFixed(1)}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppConstants.fontSizeSmall,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 下部コントロールを構築
  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: Column(
        children: [
          _buildShootingGuide(),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildCaptureButton(),
        ],
      ),
    );
  }

  /// 撮影ガイドを構築
  Widget _buildShootingGuide() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
      ),
      child: Column(
        children: [
          const Text(
            '入道雲を画面中央に配置して撮影してください',
            style: TextStyle(
              color: Colors.white,
              fontSize: AppConstants.fontSizeMedium,
            ),
            textAlign: TextAlign.center,
          ),
          if (_maxZoom > 1.0) ...[
            const SizedBox(height: AppConstants.paddingSmall),
            const Text(
              '二本指でピンチしてズーム調整できます',
              style: TextStyle(
                color: Colors.white70,
                fontSize: AppConstants.fontSizeSmall,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// 撮影ボタンを構築
  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isTakingPhoto ? null : _takePicture,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isTakingPhoto ? Colors.grey : Colors.white,
          border: Border.all(
            color: AppConstants.primarySkyBlue,
            width: 4,
          ),
        ),
        child: _isTakingPhoto
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primarySkyBlue),
              )
            : const Icon(
                Icons.camera_alt,
                color: AppConstants.primarySkyBlue,
                size: AppConstants.iconSizeLarge,
              ),
      ),
    );
  }

  // ===== ヘルパーメソッド =====

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
}
