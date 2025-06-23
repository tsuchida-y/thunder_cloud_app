// lib/screens/weather_screen.dart - リファクタリング版
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunder_cloud_app/services/notification/notification_service.dart';
import 'package:thunder_cloud_app/services/notification/push_notification_service.dart';
import 'package:thunder_cloud_app/widgets/cloud/cloud_status_overlay.dart';

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
  bool _isInitialized = false;

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
    if (_isInitialized) {
      AppLogger.info('WeatherScreen は既に初期化済み', tag: 'WeatherScreen');
      return;
    }

    try {
      AppLogger.info('WeatherScreen初期化開始', tag: 'WeatherScreen');

      setState(() => _isLoading = true);

      await _initializeServices();
      _loadLocationData();

      _isInitialized = true;
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
          .doc(AppConstants.currentUserId)
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
          .doc(AppConstants.currentUserId)
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





  void _cleanupResources() {
    _locationWaitTimer?.cancel();
    LocationService.onLocationChanged = null;
    PushNotificationService.onThunderCloudDetected = null;
    AppLogger.info('WeatherScreen リソースクリーンアップ完了', tag: 'WeatherScreen');
  }

  // ===== UI 構築メソッド =====

  /// MainScreen用に現在位置を提供
  LatLng? getCurrentLocationForAppBar() {
    return _currentLocation;
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppConstants.primarySkyBlue,
            Colors.white,
          ],
        ),
      ),
      child: Stack(
        children: [
          // 背景地図
          BackgroundMapWidget(currentLocation: _currentLocation),

          // 雲状態オーバーレイ
          if (_currentLocation != null)
            CloudStatusOverlay(matchingCities: _matchingCities),

          // ローディングオーバーレイ
          if (_isLoading)
            _buildLoadingOverlay(),

          // OpenMeteoクレジット
          _buildOpenMeteoCredit(),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: AppConstants.opacityLow),
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
          color: Colors.black.withValues(alpha: AppConstants.opacityMedium),
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



