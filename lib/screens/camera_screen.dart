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
  final double _maxZoom = 1.0;
  final double _minZoom = 1.0;

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
        child: CameraPreview(controller),
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
          _buildZoomSlider(),
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

  /// ズームスライダーを構築
  Widget _buildZoomSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.zoom_in, color: Colors.white),
          Slider(
            value: _zoomLevel,
            min: _minZoom,
            max: _maxZoom,
            onChanged: _setZoomLevel,
            activeColor: AppConstants.primarySkyBlue,
            inactiveColor: Colors.white54,
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
      child: const Text(
        '入道雲を画面中央に配置して撮影してください',
        style: TextStyle(
          color: Colors.white,
          fontSize: AppConstants.fontSizeMedium,
        ),
        textAlign: TextAlign.center,
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
