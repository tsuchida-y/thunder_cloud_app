// lib/screens/weather_screen.dart - リファクタリング版
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunder_cloud_app/services/notification.dart';
import 'package:thunder_cloud_app/services/push_notification.dart';
import 'package:thunder_cloud_app/services/weather_data_service.dart';
import 'package:thunder_cloud_app/services/weather_debug.dart';
import 'package:thunder_cloud_app/widgets/cloud/cloud_status_overlay.dart';

import '../services/location.dart';
import '../widgets/common/app_bar.dart';
import '../widgets/map/background.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen> with WidgetsBindingObserver {
  LatLng? _currentLocation;
  final List<String> _matchingCities = [];
  bool _isLoading = false;
  String _lastUpdateTime = '';
  bool _showInfoPanel = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupResources();
    super.dispose();
  }

  /// アプリのライフサイクル変更時の処理
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      default:
        break;
    }
  }

  /// スクリーンの初期化
  Future<void> _initializeScreen() async {
    try {
      print("🚀 WeatherScreen初期化開始");

      setState(() {
        _isLoading = true;
      });

      // コールバック設定を先に実行
      _setupCallbacks();

      // 通知初期化（軽量）
      await _initializeNotifications();

      // 位置情報初期化（重い処理）
      await _initializeLocation();

      _updateLastUpdateTime();

      print("✅ WeatherScreen初期化完了");

    } catch (e) {
      print("❌ WeatherScreen初期化エラー: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 位置情報の初期化
  Future<void> _initializeLocation() async {
    try {
      _currentLocation = await LocationService.getCurrentLocationAsLatLng();

      if (_currentLocation != null) {
        print("📍 初期位置情報取得成功: $_currentLocation");

        // 位置情報監視開始
        LocationService.startLocationMonitoring();

        // 位置情報保存（非同期）
        _saveLocationAsync();

        // 気象データ取得・保存（非同期）
        _fetchWeatherDataAsync();

        setState(() {});
      }
    } catch (e) {
      print("❌ 位置情報初期化エラー: $e");
    }
  }

  /// 通知の初期化（権限は既に AppInitializationService で処理済み）
  Future<void> _initializeNotifications() async {
    try {
      // 権限確認のみ（リクエストは不要）
      print("✅ 通知権限確認完了（初期化済み）");
    } catch (e) {
      print("❌ 通知初期化エラー: $e");
    }
  }

  /// コールバックの設定
  void _setupCallbacks() {
    // 入道雲検出コールバック
    PushNotificationService.onThunderCloudDetected = _handleThunderCloudDetection;

    // 位置情報更新コールバック
    LocationService.onLocationChanged = _handleLocationUpdate;
  }

  /// 位置情報の非同期保存
  void _saveLocationAsync() async {
    if (_currentLocation == null) return;

    try {
      await PushNotificationService.saveUserLocation(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );
      print("✅ 位置情報保存完了");
    } catch (e) {
      print("❌ 位置情報保存エラー: $e");
    }
  }

  /// 気象データの非同期取得・保存
  void _fetchWeatherDataAsync() async {
    if (_currentLocation == null) return;

    try {
      await WeatherDataService.instance.fetchAndStoreWeatherData(_currentLocation!);
      print("✅ 気象データ取得・保存完了");
    } catch (e) {
      print("❌ 気象データ取得エラー: $e");
    }
  }

  /// 入道雲検出時の処理
  void _handleThunderCloudDetection(List<String> directions) {
    print("🌩️ 入道雲検出: $directions");

    setState(() {
      for (String direction in directions) {
        if (!_matchingCities.contains(direction)) {
          _matchingCities.add(direction);
        }
      }
    });

    // ローカル通知を表示
    NotificationService.showThunderCloudNotification(directions);
  }

  /// 位置情報更新時の処理
  void _handleLocationUpdate(LatLng newLocation) {
    print("📍 位置情報更新: $newLocation");

    setState(() {
      _currentLocation = newLocation;
    });

    // 位置情報保存（非同期）
    _saveLocationAsync();

    // 気象データ取得・保存（非同期）
    _fetchWeatherDataAsync();

    _updateLastUpdateTime();
  }

  /// アプリが前面に戻った時の処理
  void _handleAppResumed() {
    print("📱 アプリがアクティブになりました");
    PushNotificationService.updateUserActiveStatus(true);
  }

  /// アプリがバックグラウンドに移った時の処理
  void _handleAppPaused() {
    print("📱 アプリがバックグラウンドに移りました");
    PushNotificationService.updateUserActiveStatus(false);
  }

  /// 最終更新時刻を更新
  void _updateLastUpdateTime() {
    final now = DateTime.now();
    setState(() {
      _lastUpdateTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }



  /// 気象データのデバッグ実行
  Future<void> _debugWeatherData() async {
    if (_currentLocation == null) {
      print("❌ 位置情報が取得できていません");
      return;
    }

    try {
      await WeatherDebugService.debugWeatherData(_currentLocation!);
    } catch (e) {
      print("❌ 気象データデバッグエラー: $e");
    }
  }

  /// リソースのクリーンアップ
  void _cleanupResources() {
    // コールバック解除
    PushNotificationService.onThunderCloudDetected = null;
    LocationService.onLocationChanged = null;

    // サービスのクリーンアップ
    LocationService.dispose();
    PushNotificationService.dispose();

    print("🧹 WeatherScreen リソースクリーンアップ完了");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WeatherAppBar(currentLocation: _currentLocation),
      body: Stack(
        children: [
          // 背景地図
          BackgroundMapWidget(currentLocation: _currentLocation),

          // 入道雲方向表示オーバーレイ
          CloudStatusOverlay(matchingCities: _matchingCities),

          // 情報パネル
          _buildInfoPanel(context),

          // OpenMeteoクレジット表示（レスポンシブ対応）
          _buildOpenMeteoCredit(context),

          // ローディングインジケーター
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  /// 情報パネル
  Widget _buildInfoPanel(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Positioned(
      top: isTablet ? 24 : 16,
      right: isTablet ? 24 : 16,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showInfoPanel = !_showInfoPanel;
          });
        },
        child: Container(
          padding: EdgeInsets.all(isTablet ? 12 : 8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showInfoPanel ? Icons.keyboard_arrow_up : Icons.info_outline,
                color: Colors.white,
                size: isTablet ? 24 : 20,
              ),
              if (_showInfoPanel) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: screenSize.width * 0.7,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '入道雲サーチアプリ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '現在地: ${_currentLocation != null ? '取得済み' : '取得中...'}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 13 : 11,
                        ),
                      ),
                      if (_lastUpdateTime.isNotEmpty)
                        Text(
                          '最終更新: $_lastUpdateTime',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTablet ? 13 : 11,
                          ),
                        ),
                      Text(
                        '検出された方向: ${_matchingCities.isEmpty ? 'なし' : _matchingCities.join(', ')}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 13 : 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'タップして設定ボタンで詳細確認',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isTablet ? 12 : 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }



  /// ローディングオーバーレイ
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      ),
    );
  }

  /// OpenMeteoクレジット表示（レスポンシブ対応）
  Widget _buildOpenMeteoCredit(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Positioned(
      bottom: isTablet ? 24 : 16,
      left: isTablet ? 24 : 16,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 12 : 8,
          vertical: isTablet ? 6 : 4,
        ),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          "Weather data by Open-Meteo.com",
          style: TextStyle(
            color: Colors.white,
            fontSize: isTablet ? 13 : 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}