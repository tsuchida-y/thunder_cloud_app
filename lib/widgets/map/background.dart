import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// GoogleMapを背景として表示するウィジェット
/// 入道雲監視のための地図表示に特化した設計
class BackgroundMapWidget extends StatefulWidget {
  final LatLng? currentLocation;

  const BackgroundMapWidget({
    super.key,
    this.currentLocation,
  });

  @override
  State<BackgroundMapWidget> createState() => _BackgroundMapWidgetState();
}

class _BackgroundMapWidgetState extends State<BackgroundMapWidget> {
  bool _mapLoadError = false;
  String _errorMessage = "";
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    if (widget.currentLocation == null) {
      // 位置情報取得中の表示（ローディングインジケーターなし）
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_searching,
                size: AppConstants.iconSizeXLarge,
                color: Colors.grey,
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              const Text(
                '位置情報を取得中...',
                style: TextStyle(fontSize: AppConstants.fontSizeLarge),
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              Text(
                '位置情報の取得に時間がかかる場合があります',
                style: TextStyle(fontSize: AppConstants.fontSizeSmall, color: Colors.grey[600]),
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 地図読み込みエラーの場合
    if (_mapLoadError) {
      return Container(
        color: Colors.red[100],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('地図の読み込みに失敗しました', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(_errorMessage, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _retryMapLoad,
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    AppLogger.info('GoogleMap表示: ${widget.currentLocation}', tag: 'BackgroundMapWidget');

    return GoogleMap(
      key: const ValueKey('weather_map_view'),
      initialCameraPosition: CameraPosition(
        target: widget.currentLocation!,
        zoom: AppConstants.defaultMapZoom,
      ),
      //入道雲情報が主目的のため、現在地マーカ(青いやつ)を表示するだけで他の機能は無効化
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      scrollGesturesEnabled: false,
      zoomControlsEnabled: false,
      zoomGesturesEnabled: false,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,

      // パフォーマンス最適化設定を追加
      mapType: MapType.normal,
      buildingsEnabled: false,        // 建物3D表示を無効化（CPU負荷軽減）
      trafficEnabled: false,          // 交通情報を無効化（CPU負荷軽減）
      compassEnabled: false,          // コンパスを無効化
      mapToolbarEnabled: false,       // マップツールバーを無効化
      indoorViewEnabled: false,       // 屋内マップを無効化
      liteModeEnabled: true,          // Liteモードを有効化（CPU/メモリ最適化）

      onMapCreated: _onMapCreated,
      onCameraMove: _onCameraMove,
    );
  }

  /// 地図作成時のコールバック
  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    try {
      AppLogger.success('GoogleMap初期化完了', tag: 'BackgroundMapWidget');
      // コントローラーの設定も最適化
      // controller.setMapStyle(null); // デフォルトスタイル使用
    } catch (e) {
      AppLogger.error('GoogleMapコントローラー設定エラー', error: e, tag: 'BackgroundMapWidget');
      setState(() {
        _mapLoadError = true;
        _errorMessage = "コントローラー設定エラー: $e";
      });
    }
  }

  /// カメラ移動時のコールバック
  void _onCameraMove(CameraPosition position) {
    // カメラ移動時のログは最小限に（デバッグ時のみ）
    AppLogger.debug('カメラ位置: ${position.target}', tag: 'BackgroundMapWidget');
  }

  /// 地図読み込み再試行
  void _retryMapLoad() {
    AppLogger.info('地図読み込み再試行', tag: 'BackgroundMapWidget');
    setState(() {
      _mapLoadError = false;
      _errorMessage = "";
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
