import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/location/location_service.dart';
import '../services/photo/camera_service.dart';
import '../services/photo/local_photo_service.dart';
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
  bool _isSaving = false;

  /// 写真をローカルに保存
  Future<void> _savePhotoLocally() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // 簡易的なユーザーID（実際のアプリでは認証システムを使用）
      const userId = 'user_001';
      print('💾 写真ローカル保存開始 - ユーザーID: $userId');

      // 最新のユーザー情報を取得
      print('👤 ユーザー情報取得中...');
      final userInfo = await UserService.getUserInfo(userId);
      final userName = userInfo['userName'] ?? 'ユーザー';
      print('✅ ユーザー情報取得完了: $userName');

      // 現在の位置情報を取得
      final location = await LocationService.getCurrentLocationAsLatLng();

      // 現在の気象データを取得
      Map<String, dynamic>? weatherData;
      if (location != null) {
        final weatherDataService = WeatherDataService.instance;
        await weatherDataService.fetchAndStoreWeatherData(location);
        weatherData = weatherDataService.lastWeatherData;
      }

      print('📱 写真ローカル保存開始...');
      final success = await LocalPhotoService.savePhotoLocally(
        imageFile: widget.imageFile,
        userId: userId,
        userName: userName,
        latitude: location?.latitude,
        longitude: location?.longitude,
        locationName: '撮影地点',
        weatherData: weatherData,
      );

      print('💾 ローカル保存結果: ${success ? '成功' : '失敗'}');

      if (success) {
        print('✅ 写真ローカル保存成功');
        _showLocalSaveSuccessDialog();
      } else {
        print('❌ 写真ローカル保存失敗');
        _showErrorDialog('写真のローカル保存に失敗しました');
      }
    } catch (e) {
      print('❌ 写真ローカル保存エラー: $e');
      print('❌ エラータイプ: ${e.runtimeType}');
      AppLogger.error('写真ローカル保存エラー: $e', tag: 'PhotoPreviewScreen');
      _showErrorDialog('ローカル保存エラー: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
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

      // 現在の位置情報を取得
      final location = await LocationService.getCurrentLocationAsLatLng();

      // 現在の気象データを取得
      Map<String, dynamic>? weatherData;
      if (location != null) {
        final weatherDataService = WeatherDataService.instance;
        await weatherDataService.fetchAndStoreWeatherData(location);
        weatherData = weatherDataService.lastWeatherData;
      }

      print('📸 写真アップロード開始...');
      final success = await PhotoService.uploadPhoto(
        imageFile: widget.imageFile,
        userId: userId,
        userName: userName,
        caption: '', // キャプションなし
      );

      print('📤 アップロード結果: ${success ? '成功' : '失敗'}');

      if (success) {
        print('✅ 写真共有成功');

        // コミュニティ共有成功時、ローカルにも保存
        print('💾 ローカル保存も実行中...');
        try {
          final localSaveSuccess = await LocalPhotoService.savePhotoLocally(
            imageFile: widget.imageFile,
            userId: userId,
            userName: userName,
            latitude: location?.latitude,
            longitude: location?.longitude,
            locationName: '撮影地点',
            weatherData: weatherData,
          );

          if (localSaveSuccess) {
            print('✅ ローカル保存も成功');
            _showShareAndSaveSuccessDialog();
          } else {
            print('⚠️ ローカル保存は失敗、コミュニティ共有は成功');
            _showSuccessDialog();
          }
        } catch (e) {
          print('❌ ローカル保存エラー: $e');
          print('⚠️ コミュニティ共有は成功、ローカル保存のみ失敗');
          _showSuccessDialog();
        }
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

  /// ローカル保存成功ダイアログを表示
  void _showLocalSaveSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存完了'),
        content: const Text('写真をギャラリーに保存しました！'),
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

  /// 共有・保存両方成功ダイアログを表示
  void _showShareAndSaveSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('共有・保存完了'),
        content: const Text('写真をコミュニティに共有し、ギャラリーにも保存しました！'),
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

          // ボタンエリア
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey[900]!,
                  Colors.grey[800]!,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // 保存・共有ボタン
                Row(
                  children: [
                    // ローカル保存ボタン
                    Expanded(
                      child: Container(
                        height: 56,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.5),
                            width: 2,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.green[700]!.withOpacity(0.8),
                              Colors.green[600]!.withOpacity(0.9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _savePhotoLocally,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.save_alt,
                                  color: Colors.white,
                                  size: 24,
                                ),
                          label: Text(
                            _isSaving ? '保存中...' : 'ギャラリーに保存',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // コミュニティ共有ボタン
                    Expanded(
                      child: Container(
                        height: 56,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.5),
                            width: 2,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue[700]!.withOpacity(0.8),
                              Colors.blue[600]!.withOpacity(0.9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _sharePhoto,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.share,
                                  color: Colors.white,
                                  size: 24,
                                ),
                          label: Text(
                            _isUploading ? 'アップロード中...' : 'コミュニティに共有',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 再撮影ボタン
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey[800]!.withOpacity(0.8),
                          Colors.grey[700]!.withOpacity(0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        '再撮影',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
