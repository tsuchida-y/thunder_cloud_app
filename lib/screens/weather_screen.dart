// lib/screens/weather_screen.dart - リファクタリング版
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunder_cloud_app/services/notification/notification_service.dart';
import 'package:thunder_cloud_app/services/notification/push_notification_service.dart';
import 'package:thunder_cloud_app/services/weather/weather_data_service.dart';
import 'package:thunder_cloud_app/services/weather/weather_debug_service.dart';
import 'package:thunder_cloud_app/widgets/cloud/cloud_status_overlay.dart';

import '../constants/app_constants.dart';
import '../services/location/location_service.dart';
import '../widgets/common/app_bar.dart';
import '../widgets/map/background.dart';

class WeatherScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const WeatherScreen({super.key, this.onProfileUpdated});

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

      // 既にキャッシュされた位置情報を取得（新規取得は行わない）
      _loadCachedLocation();

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

  /// キャッシュされた位置情報を読み込み
  void _loadCachedLocation() {
    _currentLocation = LocationService.cachedLocation;

      if (_currentLocation != null) {
      print("📍 キャッシュされた位置情報を使用: $_currentLocation");

        // 位置情報保存（非同期）
        _saveLocationAsync();

        setState(() {});
    } else {
      print("⚠️ キャッシュされた位置情報がありません - Firestoreから取得を試行");
      print("🔍 LocationServiceの状態: ${LocationService.getLocationStatus()}");

      // Firestoreから位置情報を取得
      _loadLocationFromFirestore();
    }
  }

  /// Firestoreから位置情報を取得
  void _loadLocationFromFirestore() async {
    try {
      print("🔍 Firestoreからユーザー位置情報を取得中...");

      // 固定ユーザーIDから位置情報を取得
      const userId = AppConstants.defaultUserId;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null &&
            userData.containsKey('latitude') &&
            userData.containsKey('longitude')) {

          final latitude = userData['latitude']?.toDouble();
          final longitude = userData['longitude']?.toDouble();

          if (latitude != null && longitude != null) {
            final firestoreLocation = LatLng(latitude, longitude);

            setState(() {
              _currentLocation = firestoreLocation;
            });

            print("✅ Firestoreからユーザー位置取得成功: $firestoreLocation");
            _saveLocationAsync();
            return;
          }
        }
      }

      print("⚠️ Firestoreにユーザー位置情報が見つかりません - バックグラウンドで位置取得を開始");
      _waitForLocationInBackground();

    } catch (e) {
      print("❌ Firestoreからの位置取得エラー: $e - バックグラウンドで位置取得を開始");
      _waitForLocationInBackground();
    }
  }

  /// バックグラウンドで位置情報取得を待機
  void _waitForLocationInBackground() {
    int attempts = 0;
    const maxAttempts = AppConstants.maxLocationAttempts;

    Timer.periodic(AppConstants.realtimeUpdateInterval, (timer) {
      attempts++;

      final location = LocationService.cachedLocation;
      if (location != null) {
        setState(() {
          _currentLocation = location;
        });
        print("📍 バックグラウンドで位置情報取得完了: $location");
        _saveLocationAsync();
        timer.cancel();
        return;
      }

      // タイムアウト処理
      if (attempts >= maxAttempts) {
        print("⏰ 位置情報取得タイムアウト - 手動取得を試行");
        timer.cancel();
        _fallbackLocationRetrieval();
      }
    });
  }

  /// フォールバック位置情報取得
  void _fallbackLocationRetrieval() async {
    try {
      print("🔄 フォールバック位置情報取得開始");
      setState(() {
        _isLoading = true;
      });

      // 強制的に新しい位置情報を取得
      final location = await LocationService.getCurrentLocationAsLatLng(forceRefresh: true)
          .timeout(AppConstants.locationTimeout);

      if (location != null) {
        setState(() {
          _currentLocation = location;
        });
        print("✅ フォールバック位置情報取得成功: $location");
        _saveLocationAsync();
      } else {
        print("❌ フォールバック位置情報取得失敗");
      }
    } catch (e) {
      print("❌ フォールバック位置情報取得エラー: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 通知の初期化
  Future<void> _initializeNotifications() async {
    try {
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

      // 気象データのリアルタイム監視を開始
      print("📡 気象データのリアルタイム監視を開始");
      WeatherDataService.instance.startRealtimeWeatherDataListener(_currentLocation!);

    } catch (e) {
      print("❌ 位置情報保存エラー: $e");
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

    print("🔄 位置更新 - 気象データはFirebaseで自動管理中");
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
      print("🔍 気象データテスト開始");
      print("📍 現在位置: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}");

      // 複数方向をテスト
      const directions = AppConstants.checkDirections;
      const distances = AppConstants.checkDistances;

      for (String direction in directions) {
        print("\n🧭 $direction方向をテスト中...");

        for (double distance in distances) {
          print("📏 距離: ${distance}km");

          // 座標計算をテスト
          final testLat = _currentLocation!.latitude + (direction == 'north' ? distance / AppConstants.latitudePerDegreeKm :
                                                       direction == 'south' ? -distance / AppConstants.latitudePerDegreeKm : 0);
          final testLon = _currentLocation!.longitude + (direction == 'east' ? distance / AppConstants.latitudePerDegreeKm :
                                                        direction == 'west' ? -distance / AppConstants.latitudePerDegreeKm : 0);

          print("🎯 テスト座標: ($testLat, $testLon)");

          // 実際の気象データ取得をテスト
          await WeatherDebugService().debugWeatherData(testLat, testLon);

          // 少し待機
          await Future.delayed(AppConstants.debugTestDelay);
        }
      }

      print("\n✅ 気象データテスト完了");

      // 手動で入道雲検出をトリガー
      print("\n🧪 手動入道雲検出テスト");
      _handleThunderCloudDetection(['north', 'east']); // テスト用

    } catch (e) {
      print("❌ 気象データテストエラー: $e");
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

  /// 外部から呼び出し可能なデータ再読み込みメソッド
  void refreshData() {
    print('🔄 天気データ再読み込み開始');
    // 天気画面では特に再読み込み処理は不要（リアルタイムデータのため）
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WeatherAppBar(),
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
      bottomNavigationBar: _buildBottomNavigationBar(context),
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
                      // 位置情報の詳細状態を表示
                      Text(
                        '位置情報状態: ${_getLocationStatusText()}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isTablet ? 12 : 10,
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
                      // デバッグ情報セクション
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'デバッグ情報',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Firebase Functions: 5分間隔で監視中',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isTablet ? 11 : 9,
                              ),
                            ),
                            Text(
                              'Open-Meteo API: 気象データ取得中',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isTablet ? 11 : 9,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // テストボタン
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _debugWeatherData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: Text(
                                  '気象データテスト',
                                  style: TextStyle(
                                    fontSize: isTablet ? 12 : 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  /// 位置情報の状態テキストを取得
  String _getLocationStatusText() {
    if (_currentLocation != null) {
      return '取得済み';
    } else {
      return '取得中...';
    }
  }

  /// ボトムナビゲーションバー
  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(135, 206, 250, 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(
                icon: Icons.map,
                label: '地図',
                isActive: true,
                onTap: () {
                  // 現在の画面なので何もしない
                },
              ),
              _buildNavButton(
                icon: Icons.photo_library,
                label: 'ギャラリー',
                isActive: false,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/gallery');
                },
              ),
              _buildNavButton(
                icon: Icons.people,
                label: 'コミュニティ',
                isActive: false,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/community');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ナビゲーションボタン
  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// WeatherScreenのコンテンツ部分のみ（Scaffold不要版）
class WeatherScreenContent extends StatefulWidget {
  const WeatherScreenContent({super.key});

  @override
  WeatherScreenContentState createState() => WeatherScreenContentState();
}

class WeatherScreenContentState extends State<WeatherScreenContent> with WidgetsBindingObserver {
  LatLng? _currentLocation;
  final List<String> _matchingCities = [];
  bool _isLoading = false;
  String _lastUpdateTime = '';
  bool _showInfoPanel = false;
  bool _isInitialized = false; // 初期化状態を追跡

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

  /// スクリーンの初期化（一度だけ実行）
  Future<void> _initializeScreen() async {
    if (_isInitialized) {
      print("✅ WeatherScreenContent既に初期化済み - 軽量更新のみ実行");
      lightweightUpdate();
      return;
    }

    try {
      print("🚀 WeatherScreenContent初期化開始");

      setState(() {
        _isLoading = true;
      });

      // コールバック設定を先に実行
      _setupCallbacks();

      // 通知初期化（軽量）
      await _initializeNotifications();

      // 既にキャッシュされた位置情報を取得（新規取得は行わない）
      _loadCachedLocation();

      _updateLastUpdateTime();
      _isInitialized = true;

      print("✅ WeatherScreenContent初期化完了");

    } catch (e) {
      print("❌ WeatherScreenContent初期化エラー: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 軽量な更新処理（再表示時）
  void lightweightUpdate() {
    print("🔄 WeatherScreenContent軽量更新開始");

    // キャッシュされた位置情報を再確認
    final cachedLocation = LocationService.cachedLocation;
    if (cachedLocation != null && _currentLocation != cachedLocation) {
      setState(() {
        _currentLocation = cachedLocation;
      });
      print("📍 位置情報を更新: $cachedLocation");
    }

    // 最終更新時刻を更新
    _updateLastUpdateTime();

    print("✅ WeatherScreenContent軽量更新完了");
  }

  /// キャッシュされた位置情報を読み込み
  void _loadCachedLocation() {
    _currentLocation = LocationService.cachedLocation;

    if (_currentLocation != null) {
      print("📍 キャッシュされた位置情報を使用: $_currentLocation");

      // 位置情報保存（非同期）
      _saveLocationAsync();

      setState(() {});
    } else {
      print("⚠️ キャッシュされた位置情報がありません - Firestoreから取得を試行");
      print("🔍 LocationServiceの状態: ${LocationService.getLocationStatus()}");

      // Firestoreから位置情報を取得
      _loadLocationFromFirestore();
    }
  }

  /// Firestoreから位置情報を取得
  void _loadLocationFromFirestore() async {
    try {
      print("🔍 Firestoreからユーザー位置情報を取得中...");

      // 固定ユーザーIDから位置情報を取得
      const userId = AppConstants.defaultUserId;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null &&
            userData.containsKey('latitude') &&
            userData.containsKey('longitude')) {

          final latitude = userData['latitude']?.toDouble();
          final longitude = userData['longitude']?.toDouble();

          if (latitude != null && longitude != null) {
            final firestoreLocation = LatLng(latitude, longitude);

            setState(() {
              _currentLocation = firestoreLocation;
            });

            print("✅ Firestoreからユーザー位置取得成功: $firestoreLocation");
            _saveLocationAsync();
            return;
          }
        }
      }

      print("⚠️ Firestoreにユーザー位置情報が見つかりません - バックグラウンドで位置取得を開始");
      _waitForLocationInBackground();

    } catch (e) {
      print("❌ Firestoreからの位置取得エラー: $e - バックグラウンドで位置取得を開始");
      _waitForLocationInBackground();
    }
  }

  /// バックグラウンドで位置情報取得を待機
  void _waitForLocationInBackground() {
    int attempts = 0;
    const maxAttempts = AppConstants.maxLocationAttempts;

    Timer.periodic(AppConstants.realtimeUpdateInterval, (timer) {
      attempts++;

      final location = LocationService.cachedLocation;
      if (location != null) {
        setState(() {
          _currentLocation = location;
        });
        print("📍 バックグラウンドで位置情報取得完了: $location");
        _saveLocationAsync();
        timer.cancel();
        return;
      }

      // タイムアウト処理
      if (attempts >= maxAttempts) {
        print("⏰ 位置情報取得タイムアウト - 手動取得を試行");
        timer.cancel();
        _fallbackLocationRetrieval();
      }
    });
  }

  /// フォールバック位置情報取得
  void _fallbackLocationRetrieval() async {
    try {
      print("🔄 フォールバック位置情報取得開始");
      setState(() {
        _isLoading = true;
      });

      // 強制的に新しい位置情報を取得
      final location = await LocationService.getCurrentLocationAsLatLng(forceRefresh: true)
          .timeout(AppConstants.locationTimeout);

      if (location != null) {
        setState(() {
          _currentLocation = location;
        });
        print("✅ フォールバック位置情報取得成功: $location");
        _saveLocationAsync();
      } else {
        print("❌ フォールバック位置情報取得失敗");
      }
    } catch (e) {
      print("❌ フォールバック位置情報取得エラー: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 通知の初期化
  Future<void> _initializeNotifications() async {
    try {
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

      // 気象データのリアルタイム監視を開始
      print("📡 気象データのリアルタイム監視を開始");
      WeatherDataService.instance.startRealtimeWeatherDataListener(_currentLocation!);

    } catch (e) {
      print("❌ 位置情報保存エラー: $e");
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

    print("🔄 位置更新 - 気象データはFirebaseで自動管理中");
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
      print("🔍 気象データテスト開始");
      print("📍 現在位置: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}");

      // 複数方向をテスト
      final directions = ['north', 'south', 'east', 'west'];
      final distances = [50.0, 160.0, 250.0];

      for (String direction in directions) {
        print("\n🧭 $direction方向をテスト中...");

        for (double distance in distances) {
          print("📏 距離: ${distance}km");

          // 座標計算をテスト
          final testLat = _currentLocation!.latitude + (direction == 'north' ? distance / 111.0 :
                                                       direction == 'south' ? -distance / 111.0 : 0);
          final testLon = _currentLocation!.longitude + (direction == 'east' ? distance / 111.0 :
                                                        direction == 'west' ? -distance / 111.0 : 0);

          print("🎯 テスト座標: ($testLat, $testLon)");

          // 実際の気象データ取得をテスト
          await WeatherDebugService().debugWeatherData(testLat, testLon);

          // 少し待機
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      print("\n✅ 気象データテスト完了");

      // 手動で入道雲検出をトリガー
      print("\n🧪 手動入道雲検出テスト");
      _handleThunderCloudDetection(['north', 'east']); // テスト用

    } catch (e) {
      print("❌ 気象データテストエラー: $e");
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

    print("🧹 WeatherScreenContent リソースクリーンアップ完了");
  }

  /// 外部から呼び出し可能なデータ再読み込みメソッド
  void refreshData() {
    print('🔄 天気データ再読み込み開始');
    // 天気画面では特に再読み込み処理は不要（リアルタイムデータのため）
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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
                      // 位置情報の詳細状態を表示
                      Text(
                        '位置情報状態: ${_getLocationStatusText()}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isTablet ? 12 : 10,
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
                      // デバッグ情報セクション
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'デバッグ情報',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Firebase Functions: 5分間隔で監視中',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isTablet ? 11 : 9,
                              ),
                            ),
                            Text(
                              'Open-Meteo API: 気象データ取得中',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isTablet ? 11 : 9,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // テストボタン
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _debugWeatherData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: Text(
                                  '気象データテスト',
                                  style: TextStyle(
                                    fontSize: isTablet ? 12 : 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  /// 位置情報の状態テキストを取得
  String _getLocationStatusText() {
    if (_currentLocation != null) {
      return '取得済み';
    } else {
      return '取得中...';
    }
  }
}

