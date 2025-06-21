import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/photo/camera_service.dart';
import '../services/photo/photo_service.dart';
import '../services/photo/user_service.dart';
import '../services/weather/weather_data_service.dart';
import '../utils/logger.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  bool _isLoading = true;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isTakingPhoto = false;
  final bool _isTakingPicture = false;
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

  /// カメラを初期化
  Future<void> _initializeCamera() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      AppLogger.info('カメラ画面でカメラ初期化開始', tag: 'CameraScreen');

      final success = await CameraService.initialize();

      if (success) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        AppLogger.success('カメラ画面でカメラ初期化成功', tag: 'CameraScreen');
      } else {
        setState(() {
          _isInitialized = false;
          _isLoading = false;
          _errorMessage = 'カメラの初期化に失敗しました。\n設定でカメラへのアクセスを許可してください。';
        });
        AppLogger.error('カメラ画面でカメラ初期化失敗', tag: 'CameraScreen');
      }
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _isLoading = false;
        _errorMessage = 'カメラの初期化中にエラーが発生しました：\n$e';
      });
      AppLogger.error('カメラ画面で予期しないエラー: $e', tag: 'CameraScreen');
    }
  }

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('写真の撮影に失敗しました'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('写真撮影エラー: $e', tag: 'CameraScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('写真撮影エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

  /// エラーダイアログを表示
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.camera_alt,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 8),
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
        backgroundColor: const Color.fromARGB(255, 135, 206, 250),
        foregroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black54,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'カメラを初期化しています...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('戻る'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || CameraService.controller == null) {
      return const Center(
        child: Text(
          'カメラが利用できません',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        // カメラプレビュー
        Positioned.fill(
          child: CameraPreview(CameraService.controller!),
        ),

        // 撮影ガイド
        _buildShootingGuide(),

        // 気象情報パネル
        _buildWeatherPanel(),

        // 撮影ボタン
        _buildCaptureButton(),
      ],
    );
  }

  /// 撮影ガイドを構築
  Widget _buildShootingGuide() {
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📸 入道雲撮影のコツ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• 空の広い範囲を含めて撮影\n• 雲の立体感を意識\n• 明るい時間帯がおすすめ',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 気象情報パネルを構築
  Widget _buildWeatherPanel() {
    return Positioned(
      bottom: 120,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🌦️ 現在の気象状況',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: _getWeatherSummary(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    snapshot.data!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  );
                }
                return const Text(
                  '気象データを取得中...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ズームスライダーを構築
  Widget _buildZoomSlider() {
    return Positioned(
      right: 20,
      top: 150,
      bottom: 200,
      child: RotatedBox(
        quarterTurns: 3,
        child: Slider(
          value: _zoomLevel,
          min: _minZoom,
          max: _maxZoom,
          onChanged: _setZoomLevel,
          activeColor: Colors.white,
          inactiveColor: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }

  /// 撮影ボタンを構築
  Widget _buildCaptureButton() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _isTakingPhoto ? null : _takePicture,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isTakingPhoto ? Colors.grey : Colors.white,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: _isTakingPhoto
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 3,
                    ),
                  )
                : const Icon(
                    Icons.camera_alt,
                    color: Colors.black,
                    size: 40,
                  ),
          ),
        ),
      ),
    );
  }

  /// 気象データの要約を取得
  Future<String> _getWeatherSummary() async {
    try {
      final weatherService = WeatherDataService.instance;
      if (weatherService.hasData) {
        final data = weatherService.lastWeatherData;
        if (data.isNotEmpty) {
          // 最も入道雲の可能性が高い方向を取得
          String bestDirection = 'なし';
          double bestScore = 0.0;

          for (final entry in data.entries) {
            final analysis = entry.value['analysis'];
            if (analysis != null && analysis['totalScore'] > bestScore) {
              bestScore = analysis['totalScore'];
              bestDirection = entry.key;
            }
          }

          if (bestScore > 0.5) {
            return '$bestDirection方向に入道雲の可能性あり (${(bestScore * 100).toStringAsFixed(0)}%)';
          } else {
            return '現在、入道雲の可能性は低いです';
          }
        }
      }
      return '気象データを取得できません';
    } catch (e) {
      return '気象データエラー';
    }
  }
}

/// 写真プレビュー画面
class PhotoPreviewScreen extends StatefulWidget {
  final File imageFile;

  const PhotoPreviewScreen({
    super.key,
    required this.imageFile,
  });

  @override
  PhotoPreviewScreenState createState() => PhotoPreviewScreenState();
}

class PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  bool _isUploading = false;
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  /// 写真を共有
  Future<void> _sharePhoto() async {
    setState(() {
      _isUploading = true;
    });

    try {
      // 簡易的なユーザーID（実際のアプリでは認証システムを使用）
      const userId = 'user_001';
      print('📤 写真共有開始 - ユーザーID: $userId');

      // 最新のユーザー情報を取得
      print('👤 ユーザー情報取得中...');
      final userInfo = await UserService.getUserInfo(userId);
      final userName = userInfo['userName'] ?? 'ユーザー';
      print('✅ ユーザー情報取得完了: $userName');

      print('📸 写真アップロード開始...');
      final success = await PhotoService.uploadPhoto(
        imageFile: widget.imageFile,
        userId: userId,
        userName: userName,
        caption: _captionController.text.trim(),
      );

      print('📤 アップロード結果: ${success ? '成功' : '失敗'}');

      if (success) {
        print('✅ 写真共有成功');
        _showSuccessDialog();
      } else {
        print('❌ 写真共有失敗');
        _showErrorDialog('写真のアップロードに失敗しました');
      }
    } catch (e) {
      print('❌ 写真共有エラー: $e');
      print('❌ エラータイプ: ${e.runtimeType}');
      AppLogger.error('写真共有エラー: $e', tag: 'PhotoPreviewScreen');
      _showErrorDialog('共有エラー: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  /// 成功ダイアログを表示
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('共有完了'),
        content: const Text('写真をコミュニティに共有しました！'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ダイアログを閉じる
              Navigator.pop(context); // プレビュー画面を閉じる
              Navigator.pop(context, true); // カメラ画面を閉じて成功を返す
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
        title: const Text('エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.preview,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              "写真プレビュー",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 135, 206, 250),
        foregroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black54,
      ),
      body: Column(
        children: [
          // 写真表示
          Expanded(
            child: Center(
              child: Image.file(
                widget.imageFile,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // キャプション入力とボタン
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Column(
              children: [
                TextField(
                  controller: _captionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'キャプションを入力（任意）',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                        ),
                        child: const Text('再撮影'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _sharePhoto,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('共有'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}