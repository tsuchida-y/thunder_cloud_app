import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../utils/logger.dart';

class CameraService {
  static CameraController? _controller;
  static List<CameraDescription>? _cameras;
  static bool _isInitialized = false;

  /// カメラサービスの初期化
  static Future<bool> initialize() async {
    try {
      AppLogger.info('=== カメラサービス初期化開始 ===', tag: 'CameraService');

      // 既に初期化済みの場合はそのまま返す
      if (_isInitialized && _controller != null && _controller!.value.isInitialized) {
        AppLogger.info('カメラは既に初期化済みです', tag: 'CameraService');
        return true;
      }

      // 既存のコントローラーを解放
      await dispose();

      // Step 1: 利用可能なカメラを取得（権限チェックも含む）
      AppLogger.info('Step 1: 利用可能なカメラを取得中...', tag: 'CameraService');
      try {
        _cameras = await availableCameras();
        AppLogger.info('availableCameras()実行完了', tag: 'CameraService');
      } catch (e) {
        AppLogger.error('カメラ一覧取得エラー: $e', tag: 'CameraService');
        AppLogger.error('エラータイプ: ${e.runtimeType}', tag: 'CameraService');

        // カメラアクセス権限エラーの場合
        if (e.toString().contains('camera') || e.toString().contains('permission')) {
          AppLogger.error('カメラ権限が拒否されている可能性があります', tag: 'CameraService');
        }
        return false;
      }

      if (_cameras == null || _cameras!.isEmpty) {
        AppLogger.error('利用可能なカメラが見つかりません', tag: 'CameraService');
        return false;
      }

      AppLogger.info('利用可能なカメラ数: ${_cameras!.length}', tag: 'CameraService');
      for (int i = 0; i < _cameras!.length; i++) {
        final camera = _cameras![i];
        AppLogger.info('カメラ $i: ${camera.name} (${camera.lensDirection})', tag: 'CameraService');
      }

      // Step 2: 背面カメラを選択
      AppLogger.info('Step 2: 背面カメラを選択中...', tag: 'CameraService');
      CameraDescription selectedCamera;
      try {
        selectedCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
        AppLogger.info('選択されたカメラ: ${selectedCamera.name}', tag: 'CameraService');
      } catch (e) {
        AppLogger.error('カメラ選択エラー: $e', tag: 'CameraService');
        return false;
      }

      // Step 3: カメラコントローラーを初期化
      AppLogger.info('Step 3: カメラコントローラーを初期化中...', tag: 'CameraService');
      try {
        _controller = CameraController(
          selectedCamera,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        AppLogger.info('CameraController作成完了', tag: 'CameraService');

        AppLogger.info('controller.initialize()実行中...', tag: 'CameraService');
        await _controller!.initialize();
        AppLogger.info('controller.initialize()実行完了', tag: 'CameraService');

        // 初期化の確認
        if (!_controller!.value.isInitialized) {
          AppLogger.error('カメラコントローラーの初期化に失敗しました', tag: 'CameraService');
          AppLogger.error('controller.value: ${_controller!.value}', tag: 'CameraService');
          return false;
        }

        _isInitialized = true;
        AppLogger.success('=== カメラサービス初期化完了 ===', tag: 'CameraService');
        return true;

      } catch (e) {
        AppLogger.error('カメラコントローラー初期化エラー: $e', tag: 'CameraService');
        AppLogger.error('エラータイプ: ${e.runtimeType}', tag: 'CameraService');

        // 権限関連のエラーメッセージを詳細に出力
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('permission') || errorMessage.contains('denied') || errorMessage.contains('authorized')) {
          AppLogger.error('カメラ権限エラーが発生しました', tag: 'CameraService');
          AppLogger.error('設定アプリでカメラ権限を確認してください', tag: 'CameraService');
        }

        return false;
      }

    } catch (e) {
      AppLogger.error('カメラ初期化の予期しないエラー: $e', tag: 'CameraService');
      AppLogger.error('エラータイプ: ${e.runtimeType}', tag: 'CameraService');
      return false;
    }
  }

  /// カメラコントローラーを取得
  static CameraController? get controller => _controller;

  /// 初期化状態を取得
  static bool get isInitialized => _isInitialized && _controller != null && _controller!.value.isInitialized;

  /// カメラ権限の詳細な状況を確認（簡易版）
  static Future<Map<String, dynamic>> checkPermissionStatus() async {
    try {
      // availableCameras()を呼び出してカメラアクセス可能かチェック
      final cameras = await availableCameras();

      return {
        'availableCameras': cameras.length,
        'cameraDetails': cameras.map((camera) => {
          'name': camera.name,
          'lensDirection': camera.lensDirection.toString(),
          'sensorOrientation': camera.sensorOrientation,
        }).toList(),
        'permissionStatus': 'カメラアクセス可能',
        'isAccessible': true,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'permissionStatus': 'カメラアクセス不可',
        'isAccessible': false,
        'availableCameras': 0,
        'errorType': e.runtimeType.toString(),
      };
    }
  }

  /// 写真を撮影
  static Future<File?> takePicture() async {
    if (!isInitialized) {
      AppLogger.error('カメラが初期化されていません', tag: 'CameraService');
      return null;
    }

    try {
      AppLogger.info('写真撮影開始', tag: 'CameraService');

      // 写真撮影
      final XFile image = await _controller!.takePicture();

      // ファイルサイズを確認・リサイズ
      final processedFile = await _processImage(File(image.path));

      AppLogger.success('写真撮影完了: ${processedFile?.path}', tag: 'CameraService');
      return processedFile;
    } catch (e) {
      AppLogger.error('写真撮影エラー: $e', tag: 'CameraService');
      return null;
    }
  }

  /// 画像処理（リサイズ・圧縮）
  static Future<File?> _processImage(File imageFile) async {
    try {
      AppLogger.info('画像処理開始: ${imageFile.path}', tag: 'CameraService');

      // 画像を読み込み
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        AppLogger.error('画像のデコードに失敗しました', tag: 'CameraService');
        return null;
      }

      AppLogger.info('元画像サイズ: ${image.width}x${image.height} (${imageBytes.length} bytes)', tag: 'CameraService');

      // 画像サイズを確認（最大2MB制限）
      const int maxSizeBytes = 2 * 1024 * 1024; // 2MB

      // 必要に応じてリサイズ
      if (imageBytes.length > maxSizeBytes || image.width > 1920 || image.height > 1920) {
        AppLogger.info('画像リサイズを実行中...', tag: 'CameraService');

        // 画像の長辺を1920pxに制限
        if (image.width > image.height) {
          image = img.copyResize(image, width: 1920);
        } else {
          image = img.copyResize(image, height: 1920);
        }

        AppLogger.info('リサイズ後サイズ: ${image.width}x${image.height}', tag: 'CameraService');
      }

      // JPEG形式で保存（品質80%）
      final Uint8List processedBytes = Uint8List.fromList(
        img.encodeJpg(image, quality: 80)
      );

      // 処理済み画像を保存
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'thunder_cloud_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File processedFile = File('${appDir.path}/$fileName');

      await processedFile.writeAsBytes(processedBytes);

      // 元の一時ファイルを削除
      if (await imageFile.exists()) {
        await imageFile.delete();
      }

      AppLogger.info('画像処理完了: ${processedFile.path} (${processedBytes.length} bytes)', tag: 'CameraService');
      return processedFile;
    } catch (e) {
      AppLogger.error('画像処理エラー: $e', tag: 'CameraService');
      return imageFile; // エラーの場合は元ファイルを返す
    }
  }

  /// フラッシュモードを切り替え
  static Future<void> toggleFlash() async {
    if (!isInitialized) return;

    try {
      final currentMode = _controller!.value.flashMode;
      final newMode = currentMode == FlashMode.off ? FlashMode.auto : FlashMode.off;
      await _controller!.setFlashMode(newMode);
      AppLogger.info('フラッシュモード変更: $newMode', tag: 'CameraService');
    } catch (e) {
      AppLogger.error('フラッシュモード変更エラー: $e', tag: 'CameraService');
    }
  }

  /// ズームレベルを設定
  static Future<void> setZoomLevel(double zoom) async {
    if (!isInitialized) return;

    try {
      await _controller!.setZoomLevel(zoom);
    } catch (e) {
      AppLogger.error('ズーム設定エラー: $e', tag: 'CameraService');
    }
  }

  /// カメラサービスを解放
  static Future<void> dispose() async {
    try {
      if (_controller != null) {
        if (_controller!.value.isInitialized) {
          await _controller!.dispose();
        }
        _controller = null;
      }
      _isInitialized = false;
      AppLogger.info('カメラサービス解放完了', tag: 'CameraService');
    } catch (e) {
      AppLogger.error('カメラサービス解放エラー: $e', tag: 'CameraService');
    }
  }
}