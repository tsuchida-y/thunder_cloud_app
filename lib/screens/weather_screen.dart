// lib/screens/weather_screen.dart - リファクタリング版
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunder_cloud_app/services/notification/notification_service.dart';
import 'package:thunder_cloud_app/services/notification/push_notification_service.dart';
import 'package:thunder_cloud_app/services/weather/weather_debug_service.dart';
import 'package:thunder_cloud_app/widgets/cloud/cloud_status_overlay.dart';
import 'package:thunder_cloud_app/widgets/common/app_bar.dart';

import '../constants/app_constants.dart';
import '../services/location/location_service.dart';
import '../utils/logger.dart';
import '../widgets/map/background.dart';

/// 天気画面 - 入道雲の監視と表示を行うメイン画面
class WeatherScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const WeatherScreen({super.key, this.onProfileUpdated});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen> with WidgetsBindingObserver {
  // ===== 状態管理 =====
  LatLng? _currentLocation;
  final List<String> _matchingCities = [];
  bool _isLoading = false;
  String _lastUpdateTime = '';
  bool _showInfoPanel = false;

  // ===== タイマー管理 =====
  Timer? _locationWaitTimer;

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

  // ===== ライフサイクル管理 =====

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

  void _handleAppResumed() {
    AppLogger.info('アプリが再開されました', tag: 'WeatherScreen');
    // 必要に応じて位置情報を更新
  }

  void _handleAppPaused() {
    AppLogger.info('アプリが一時停止されました', tag: 'WeatherScreen');
  }

  // ===== 初期化メソッド =====

  Future<void> _initializeScreen() async {
    try {
      AppLogger.info('WeatherScreen初期化開始', tag: 'WeatherScreen');

      setState(() => _isLoading = true);

      await _initializeServices();
      _loadLocationData();
      _updateLastUpdateTime();

      AppLogger.success('WeatherScreen初期化完了', tag: 'WeatherScreen');
    } catch (e) {
      AppLogger.error('WeatherScreen初期化エラー', error: e, tag: 'WeatherScreen');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeServices() async {
    try {
      _setupCallbacks();
      await _initializeNotifications();
    } catch (e) {
      AppLogger.error('サービス初期化エラー', error: e, tag: 'WeatherScreen');
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.initialize();
      await PushNotificationService.initialize();
    } catch (e) {
      AppLogger.error('通知初期化エラー', error: e, tag: 'WeatherScreen');
    }
  }

  void _setupCallbacks() {
    LocationService.onLocationChanged = _handleLocationUpdate;
    PushNotificationService.onThunderCloudDetected = _handleThunderCloudDetection;
  }

  // ===== 位置情報管理 =====

  void _loadLocationData() {
    final cachedLocation = LocationService.cachedLocation;

    if (cachedLocation != null) {
      _useCachedLocation(cachedLocation);
    } else {
      _loadLocationFromFirestore();
    }
  }

  void _useCachedLocation(LatLng location) {
    AppLogger.info('キャッシュされた位置情報を使用: $location', tag: 'WeatherScreen');

    if (mounted) {
      setState(() => _currentLocation = location);
    }

    _saveLocationAsync();
  }

  Future<void> _loadLocationFromFirestore() async {
    try {
      AppLogger.info('Firestoreからユーザー位置情報を取得中', tag: 'WeatherScreen');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(AppConstants.defaultUserId)
          .get()
          .timeout(AppConstants.weatherDataTimeout);

      if (userDoc.exists && mounted) {
        final location = _extractLocationFromDoc(userDoc);
        if (location != null) {
          setState(() => _currentLocation = location);
          AppLogger.success('Firestoreからユーザー位置取得成功: $location', tag: 'WeatherScreen');
          _saveLocationAsync();
          return;
        }
      }

      _waitForLocationInBackground();
    } catch (e) {
      AppLogger.error('Firestoreからの位置取得エラー', error: e, tag: 'WeatherScreen');
      _waitForLocationInBackground();
    }
  }

  LatLng? _extractLocationFromDoc(DocumentSnapshot userDoc) {
    final userData = userDoc.data() as Map<String, dynamic>?;

    if (userData == null ||
        !userData.containsKey('latitude') ||
        !userData.containsKey('longitude')) {
      return null;
    }

    final latitude = userData['latitude']?.toDouble();
    final longitude = userData['longitude']?.toDouble();

    if (latitude == null || longitude == null) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  void _waitForLocationInBackground() {
    AppLogger.info('バックグラウンドで位置情報取得を待機', tag: 'WeatherScreen');

    int attempts = 0;
    _locationWaitTimer = Timer.periodic(AppConstants.realtimeUpdateInterval, (timer) {
      attempts++;

      final location = LocationService.cachedLocation;
      if (location != null && mounted) {
        setState(() => _currentLocation = location);
        AppLogger.info('バックグラウンドで位置情報取得完了: $location', tag: 'WeatherScreen');
        _saveLocationAsync();
        timer.cancel();
        return;
      }

      if (attempts >= AppConstants.maxLocationAttempts) {
        AppLogger.warning('位置情報取得タイムアウト', tag: 'WeatherScreen');
        timer.cancel();
        _fallbackLocationRetrieval();
      }
    });
  }

  Future<void> _fallbackLocationRetrieval() async {
    try {
      AppLogger.info('フォールバック位置情報取得開始', tag: 'WeatherScreen');

      if (mounted) setState(() => _isLoading = true);

      final location = await LocationService.getCurrentLocationAsLatLng(forceRefresh: true)
          .timeout(AppConstants.locationTimeout);

      if (location != null && mounted) {
        setState(() => _currentLocation = location);
        AppLogger.success('フォールバック位置情報取得成功: $location', tag: 'WeatherScreen');
        _saveLocationAsync();
      }
    } catch (e) {
      AppLogger.error('フォールバック位置情報取得エラー', error: e, tag: 'WeatherScreen');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLocationAsync() async {
    if (_currentLocation == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(AppConstants.defaultUserId)
          .set({
        'latitude': _currentLocation!.latitude,
        'longitude': _currentLocation!.longitude,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AppLogger.info('位置情報をFirestoreに保存完了', tag: 'WeatherScreen');
    } catch (e) {
      AppLogger.error('位置情報保存エラー', error: e, tag: 'WeatherScreen');
    }
  }

  // ===== イベントハンドラー =====

  void _handleThunderCloudDetection(List<String> directions) {
    AppLogger.info('入道雲検出: $directions', tag: 'WeatherScreen');

    if (mounted) {
      setState(() {
        _matchingCities.clear();
        _matchingCities.addAll(directions);
      });
    }
  }

  void _handleLocationUpdate(LatLng newLocation) {
    AppLogger.info('位置情報更新: $newLocation', tag: 'WeatherScreen');

    if (mounted) {
      setState(() => _currentLocation = newLocation);
      _saveLocationAsync();
    }
  }

  // ===== ユーティリティメソッド =====

  void _updateLastUpdateTime() {
    final now = DateTime.now();
    _lastUpdateTime = '${now.hour.toString().padLeft(2, '0')}:'
                     '${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _debugWeatherData() async {
    if (_currentLocation == null) {
      _showMessage('位置情報が取得できていません', isError: true);
      return;
    }

    try {
      AppLogger.info('デバッグ気象データ取得開始', tag: 'WeatherScreen');

      if (mounted) setState(() => _isLoading = true);

      final weatherDebugService = WeatherDebugService();
      final result = await weatherDebugService.debugWeatherData(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      ).timeout(AppConstants.weatherDataTimeout);

      if (mounted) {
        final message = result != null
            ? 'デバッグ完了: 気象データを取得しました'
            : 'デバッグ完了: データが見つかりませんでした';
        _showMessage(message);
      }
    } catch (e) {
      AppLogger.error('デバッグ気象データ取得エラー', error: e, tag: 'WeatherScreen');
      _showMessage('デバッグエラー: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _cleanupResources() {
    _locationWaitTimer?.cancel();
    LocationService.onLocationChanged = null;
    PushNotificationService.onThunderCloudDetected = null;
    AppLogger.info('WeatherScreen リソースクリーンアップ完了', tag: 'WeatherScreen');
  }

  // ===== UI 構築メソッド =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WeatherAppBar(
        currentLocation: _currentLocation,
        onProfileUpdated: widget.onProfileUpdated,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        // 背景地図
        BackgroundMapWidget(currentLocation: _currentLocation),

        // 雲状態オーバーレイ
        if (_currentLocation != null)
          CloudStatusOverlay(matchingCities: _matchingCities),

        // 情報パネル
        if (_showInfoPanel)
          _buildInfoPanel(),

        // ローディングオーバーレイ
        if (_isLoading)
          _buildLoadingOverlay(),

        // OpenMeteoクレジット
        _buildOpenMeteoCredit(),

        // 情報パネルトグルボタン
        _buildInfoToggleButton(),

        // デバッグボタン（開発時のみ）
        _buildDebugButton(),
      ],
    );
  }

  Widget _buildDebugButton() {
    return Positioned(
      top: AppConstants.isTablet(MediaQuery.of(context).size)
          ? AppConstants.paddingXXLarge
          : AppConstants.paddingLarge,
      left: AppConstants.isTablet(MediaQuery.of(context).size)
          ? AppConstants.paddingXXLarge
          : AppConstants.paddingLarge,
      child: FloatingActionButton(
        mini: true,
        onPressed: _debugWeatherData,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.bug_report, color: Colors.white),
      ),
    );
  }

  Widget _buildInfoToggleButton() {
    return Positioned(
      top: AppConstants.isTablet(MediaQuery.of(context).size)
          ? AppConstants.paddingXXLarge
          : AppConstants.paddingLarge,
      right: AppConstants.isTablet(MediaQuery.of(context).size)
          ? AppConstants.paddingXXLarge
          : AppConstants.paddingLarge,
      child: GestureDetector(
        onTap: () => setState(() => _showInfoPanel = !_showInfoPanel),
        child: Container(
          padding: EdgeInsets.all(
            AppConstants.isTablet(MediaQuery.of(context).size)
                ? AppConstants.paddingMedium
                : AppConstants.paddingSmall
          ),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(AppConstants.opacityHigh),
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(AppConstants.opacityLow),
                blurRadius: AppConstants.elevationHigh,
                offset: AppConstants.shadowOffsetSmall,
              ),
            ],
          ),
          child: Icon(
            _showInfoPanel ? Icons.close : Icons.info,
            color: Colors.white,
            size: AppConstants.iconSizeMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Positioned(
      top: AppConstants.isTablet(MediaQuery.of(context).size)
          ? 80
          : 60,
      right: AppConstants.paddingLarge,
      child: Container(
        width: AppConstants.isTablet(MediaQuery.of(context).size) ? 350 : 280,
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(AppConstants.opacityHigh),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(AppConstants.opacityLow),
              blurRadius: AppConstants.elevationHigh,
              offset: AppConstants.shadowOffsetSmall,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoHeader(),
            const SizedBox(height: AppConstants.paddingMedium),
            _buildLocationInfo(),
            const SizedBox(height: AppConstants.paddingMedium),
            _buildMonitoringInfo(),
            const SizedBox(height: AppConstants.paddingMedium),
            _buildStatusInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoHeader() {
    return const Row(
      children: [
        Icon(
          Icons.cloud,
          color: Colors.blue,
          size: AppConstants.iconSizeLarge,
        ),
        SizedBox(width: AppConstants.paddingSmall),
        Expanded(
          child: Text(
            '入道雲監視システム',
            style: TextStyle(
              fontSize: AppConstants.fontSizeLarge,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '現在位置',
          style: TextStyle(
            fontSize: AppConstants.fontSizeMedium,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: AppConstants.paddingXSmall),
        if (_currentLocation != null) ...[
          Text(
            '緯度: ${AppConstants.formatCoordinate(_currentLocation!.latitude)}',
            style: const TextStyle(fontSize: AppConstants.fontSizeSmall),
          ),
          Text(
            '経度: ${AppConstants.formatCoordinate(_currentLocation!.longitude)}',
            style: const TextStyle(fontSize: AppConstants.fontSizeSmall),
          ),
        ] else ...[
          const Text(
            '位置情報を取得中...',
            style: TextStyle(
              fontSize: AppConstants.fontSizeSmall,
              color: Colors.orange,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMonitoringInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '監視設定',
          style: TextStyle(
            fontSize: AppConstants.fontSizeMedium,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: AppConstants.paddingXSmall),
        Text(
          '監視方向: ${AppConstants.checkDirections.join(', ')}',
          style: const TextStyle(fontSize: AppConstants.fontSizeSmall),
        ),
        Text(
          '監視距離: ${AppConstants.checkDistances.join(', ')}km',
          style: const TextStyle(fontSize: AppConstants.fontSizeSmall),
        ),
        const Text(
          AppConstants.monitoringMessage,
          style: TextStyle(fontSize: AppConstants.fontSizeSmall),
        ),
      ],
    );
  }

  Widget _buildStatusInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '検出状況',
          style: TextStyle(
            fontSize: AppConstants.fontSizeMedium,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: AppConstants.paddingXSmall),
        if (_matchingCities.isNotEmpty) ...[
          Text(
            '入道雲検出: ${_matchingCities.join(', ')}',
            style: const TextStyle(
              fontSize: AppConstants.fontSizeSmall,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ] else ...[
          const Text(
            '入道雲は検出されていません',
            style: TextStyle(
              fontSize: AppConstants.fontSizeSmall,
              color: Colors.green,
            ),
          ),
        ],
        if (_lastUpdateTime.isNotEmpty) ...[
          const SizedBox(height: AppConstants.paddingXSmall),
          Text(
            '最終更新: $_lastUpdateTime',
            style: TextStyle(
              fontSize: AppConstants.fontSizeXSmall,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(AppConstants.opacityLow),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppConstants.paddingMedium),
              Text(
                '処理中...',
                style: TextStyle(fontSize: AppConstants.fontSizeMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenMeteoCredit() {
    return Positioned(
      bottom: AppConstants.paddingSmall,
      left: AppConstants.paddingSmall,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingSmall,
          vertical: AppConstants.paddingXSmall,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(AppConstants.opacityMedium),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
        child: const Text(
          'Weather data by Open-Meteo.com',
          style: TextStyle(
            color: Colors.white,
            fontSize: AppConstants.fontSizeXXSmall,
          ),
        ),
      ),
    );
  }
}



