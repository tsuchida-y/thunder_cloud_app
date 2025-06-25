// lib/screens/weather_screen.dart - リファクタリング版
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunder_cloud_app/services/notification/notification_service.dart';
import 'package:thunder_cloud_app/services/notification/push_notification_service.dart';
import 'package:thunder_cloud_app/widgets/cloud/cloud_status_overlay.dart';

import '../constants/app_constants.dart';
import '../services/location/location_service.dart';
import '../services/weather/weather_cache_service.dart';
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
  bool _isInitialized = false;

  // ===== タイマー管理 =====
  Timer? _locationWaitTimer;
  Timer? _weatherDataTimer;

  // ===== サービス =====
  final WeatherCacheService _weatherService = WeatherCacheService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => _initializeScreen());
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
    // 気象データを更新
    if (_currentLocation != null) {
      _updateWeatherData();
    }
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

      await _initializeServices();
      _loadLocationData();

      _isInitialized = true;
      AppLogger.success('WeatherScreen初期化完了', tag: 'WeatherScreen');
    } catch (e) {
      AppLogger.error('WeatherScreen初期化エラー', error: e, tag: 'WeatherScreen');
    }
  }

  Future<void> _initializeServices() async {
    try {
      _setupCallbacks();
      await _initializeNotifications();
      _startWeatherDataMonitoring();
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

  // ===== 気象データ監視機能 =====

  /// 気象データの定期監視を開始
  void _startWeatherDataMonitoring() {
    AppLogger.info('気象データ監視開始', tag: 'WeatherScreen');

    // 30秒間隔で気象データをチェック
    _weatherDataTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentLocation != null) {
        _updateWeatherData();
      }
    });
  }

  /// 気象データを更新してマッチング都市を更新
  Future<void> _updateWeatherData() async {
    if (_currentLocation == null) return;

    try {
      final weatherData = await _weatherService.getWeatherDataWithCache(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      if (weatherData != null) {
        _updateMatchingCitiesFromWeatherData(weatherData);
      }
    } catch (e) {
      AppLogger.error('気象データ更新エラー', error: e, tag: 'WeatherScreen');
    }
  }

  /// 気象データからマッチング都市を更新
  void _updateMatchingCitiesFromWeatherData(Map<String, dynamic> weatherData) {
    final newMatchingCities = <String>[];

    // 各方向をチェック
    for (final direction in ['north', 'south', 'east', 'west']) {
      if (weatherData.containsKey(direction)) {
        final directionData = weatherData[direction] as Map<String, dynamic>?;

        if (directionData != null) {
          // 距離別データから最適なデータを選択
          final bestData = _selectBestDistanceData(direction, directionData);

          if (bestData != null && bestData.containsKey('analysis')) {
            final analysis = bestData['analysis'] as Map<String, dynamic>?;

            if (analysis != null && analysis['isLikely'] == true) {
              // 英語のキーをそのまま使用（CloudStatusOverlayと一致させる）
              newMatchingCities.add(direction);
            }
          }
        }
      }
    }

    // UIを更新（変更があった場合のみ）
    if (_hasMatchingCitiesChanged(newMatchingCities)) {
      if (mounted) {
        setState(() {
          _matchingCities.clear();
          _matchingCities.addAll(newMatchingCities);
        });
      }
    }
  }

  /// 各方向のデータから最適な距離のデータを選択
  Map<String, dynamic>? _selectBestDistanceData(String direction, Map<String, dynamic> directionData) {
    // 距離キー（50km、160km、250km）を探す
    final distanceKeys = directionData.keys
        .where((key) => key.contains('km'))
        .toList();

    if (distanceKeys.isEmpty) {
      // 距離キーがない場合は、そのまま返す（既に正しい形式）
      return directionData;
    }

    // 各距離のデータから最高スコアを選択
    Map<String, dynamic>? bestData;
    double bestScore = -1;

    for (final distanceKey in distanceKeys) {
      final distanceData = directionData[distanceKey] as Map<String, dynamic>?;
      if (distanceData != null && distanceData.containsKey('analysis')) {
        final analysis = distanceData['analysis'] as Map<String, dynamic>?;
        if (analysis != null && analysis.containsKey('totalScore')) {
          final score = (analysis['totalScore'] as num?)?.toDouble() ?? 0.0;

          if (score > bestScore) {
            bestScore = score;
            bestData = distanceData;
          }
        }
      }
    }

    if (bestData != null) {
      return bestData;
    }

    // フォールバック: 最初のデータを返す
    final firstKey = distanceKeys.first;
    return directionData[firstKey] as Map<String, dynamic>?;
  }

  /// マッチング都市が変更されたかチェック
  bool _hasMatchingCitiesChanged(List<String> newMatchingCities) {
    if (_matchingCities.length != newMatchingCities.length) return true;

    for (final city in newMatchingCities) {
      if (!_matchingCities.contains(city)) return true;
    }

    return false;
  }

  // ===== 位置情報管理 =====

  void _loadLocationData() {
    final cachedLocation = LocationService.cachedLocation;

    if (cachedLocation != null) {
      _useCachedLocation(cachedLocation);
    } else {
      _loadLocationFast();
    }
  }

  void _useCachedLocation(LatLng location) {
    AppLogger.info('キャッシュされた位置情報を使用: $location', tag: 'WeatherScreen');

    if (mounted) {
      setState(() => _currentLocation = location);
    }

    // 初期化時に気象データも取得
    _updateWeatherData();
  }

  /// 高速な位置情報取得（並列処理）
  Future<void> _loadLocationFast() async {
    try {
      AppLogger.info('高速位置情報取得開始', tag: 'WeatherScreen');

      final location = await LocationService.getLocationFast();

      if (location != null && mounted) {
        setState(() => _currentLocation = location);
        AppLogger.success('高速位置情報取得成功: $location', tag: 'WeatherScreen');

        // 初期化時に気象データも取得
        _updateWeatherData();
      } else {
        AppLogger.warning('高速位置情報取得失敗 - フォールバック実行', tag: 'WeatherScreen');
        _fallbackLocationRetrieval();
      }
    } catch (e) {
      AppLogger.error('高速位置情報取得エラー', error: e, tag: 'WeatherScreen');
      _fallbackLocationRetrieval();
    }
  }

  Future<void> _fallbackLocationRetrieval() async {
    try {
      AppLogger.info('フォールバック位置情報取得開始', tag: 'WeatherScreen');

      final location = await LocationService.getCurrentLocationAsLatLng(forceRefresh: true)
          .timeout(AppConstants.locationTimeout);

      if (location != null && mounted) {
        setState(() => _currentLocation = location);
        AppLogger.success('フォールバック位置情報取得成功: $location', tag: 'WeatherScreen');

        // 初期化時に気象データも取得
        _updateWeatherData();
      }
    } catch (e) {
      AppLogger.error('フォールバック位置情報取得エラー', error: e, tag: 'WeatherScreen');
    }
  }

  // ===== イベントハンドラー =====

  void _handleThunderCloudDetection(List<String> directions) {
    // 日本語から英語のキーに変換
    final englishDirections = directions.map((direction) {
      switch (direction) {
        case '北':
          return 'north';
        case '南':
          return 'south';
        case '東':
          return 'east';
        case '西':
          return 'west';
        default:
          return direction; // 既に英語の場合はそのまま
      }
    }).toList();

    if (mounted) {
      setState(() {
        _matchingCities.clear();
        _matchingCities.addAll(englishDirections);
      });
    }
  }

  void _handleLocationUpdate(LatLng newLocation) {
    AppLogger.info('位置情報更新: $newLocation', tag: 'WeatherScreen');

    if (mounted) {
      setState(() => _currentLocation = newLocation);
      // 位置情報が更新されたら気象データも更新
      _updateWeatherData();
    }
  }

  // ===== ユーティリティメソッド =====

  void _cleanupResources() {
    _locationWaitTimer?.cancel();
    _weatherDataTimer?.cancel();
    LocationService.onLocationChanged = null;
    PushNotificationService.onThunderCloudDetected = null;
    AppLogger.info('WeatherScreen リソースクリーンアップ完了', tag: 'WeatherScreen');
  }

  /// MainScreen用に現在位置を提供
  LatLng? getCurrentLocationForAppBar() {
    return _currentLocation;
  }

  @override
  Widget build(BuildContext context) {
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
          // 地図は常に表示
          BackgroundMapWidget(currentLocation: _currentLocation),

          // 雲状態オーバーレイは位置情報取得後にのみ表示
          if (_currentLocation != null)
            CloudStatusOverlay(matchingCities: _matchingCities),
        ],
      ),
    );
  }
}



