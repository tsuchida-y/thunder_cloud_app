import 'dart:async';
import 'dart:io';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/app_constants.dart';
import '../../services/location/location_service.dart';
// import '../../services/photo/user_service.dart'; // サービスが削除されたため無効化
import '../../services/weather/weather_cache_service.dart';
import '../../utils/logger.dart';

/// 設定画面のビジネスロジックを管理するサービス
class SettingsService {
  // ===== サービス =====
  final WeatherCacheService _cacheService = WeatherCacheService();

  // ===== タイマー・監視 =====
  Timer? _updateTimer;
  StreamSubscription? _realtimeSubscription;

  // ===== 状態 =====
  LatLng? _currentLocation;
  Map<String, dynamic> _weatherData = {};
  Map<String, dynamic> _userInfo = {};
  DateTime? _lastUpdateTime;

  // ===== ゲッター =====
  LatLng? get currentLocation => _currentLocation;
  Map<String, dynamic> get weatherData => _weatherData;
  Map<String, dynamic> get userInfo => _userInfo;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  // ===== 初期化・終了処理 =====

  /// サービスを初期化
  Future<void> initialize(LatLng? initialLocation) async {
    AppLogger.info('設定サービス初期化開始', tag: 'SettingsService');

    try {
      await Future.wait([
        _initializeLocation(initialLocation),
        _loadUserInfo(),
      ]);

      if (_currentLocation != null) {
        await _fetchWeatherData();
        _startRealtimeMonitoring();
      }

      _startPeriodicMonitoring();
      AppLogger.success('設定サービス初期化完了', tag: 'SettingsService');
    } catch (e) {
      AppLogger.error('設定サービス初期化エラー', error: e, tag: 'SettingsService');
      rethrow;
    }
  }

  /// サービスを終了
  void dispose() {
    _updateTimer?.cancel();
    _realtimeSubscription?.cancel();
    AppLogger.info('設定サービス終了', tag: 'SettingsService');
  }

  // ===== 位置情報管理 =====

  /// 位置情報を初期化
  Future<void> _initializeLocation(LatLng? initialLocation) async {
    try {
      if (initialLocation != null) {
        _currentLocation = initialLocation;
        AppLogger.info('初期位置を設定: $initialLocation', tag: 'SettingsService');
      } else {
        final location = await LocationService.getCurrentLocationAsLatLng();
        if (location != null) {
          _currentLocation = location;
          AppLogger.info('現在位置を取得: $location', tag: 'SettingsService');
        }
      }
    } catch (e) {
      AppLogger.error('位置情報初期化エラー', error: e, tag: 'SettingsService');
    }
  }

  /// 位置情報を更新
  Future<void> updateLocation() async {
    try {
      final location = await LocationService.getCurrentLocationAsLatLng();
      if (location != null) {
        _currentLocation = location;
        await _fetchWeatherData();
        _restartRealtimeMonitoring();
        AppLogger.info('位置情報更新完了: $location', tag: 'SettingsService');
      }
    } catch (e) {
      AppLogger.error('位置情報更新エラー', error: e, tag: 'SettingsService');
      rethrow;
    }
  }

  // ===== ユーザー情報管理 =====

  /// ユーザー情報を読み込み
  Future<void> _loadUserInfo() async {
    AppLogger.info('ユーザー情報読み込み開始', tag: 'SettingsService');

    // UserServiceが削除されたため、デフォルト情報を設定
    _userInfo = {
      'userId': AppConstants.currentUserId,
      'userName': 'ユーザー',
      'avatarUrl': '',
    };

    AppLogger.success('ユーザー情報読み込み完了（デフォルト）', tag: 'SettingsService');
  }

  /// ユーザー情報を更新
  Future<void> updateUserInfo(Map<String, dynamic> newUserInfo) async {
    AppLogger.info('ユーザー情報更新開始', tag: 'SettingsService');

    // UserServiceが削除されたため、ローカルのみ更新
    _userInfo = {..._userInfo, ...newUserInfo};

    AppLogger.success('ユーザー情報更新完了（ローカルのみ）', tag: 'SettingsService');
  }

  // ===== 気象データ管理 =====

  /// 気象データを取得
  Future<Map<String, dynamic>?> fetchWeatherData({bool isPeriodicCheck = false}) async {
    if (_currentLocation == null) return null;

    try {
      if (isPeriodicCheck) {
        AppLogger.info('定期チェック: 気象データ取得', tag: 'SettingsService');
      } else {
        AppLogger.info('気象データ取得開始', tag: 'SettingsService');
      }

      final weatherData = await _cacheService.getWeatherDataWithCache(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      if (weatherData != null) {
        _weatherData = weatherData;
        _lastUpdateTime = DateTime.now();
        AppLogger.success('気象データ取得成功', tag: 'SettingsService');
        return weatherData;
      } else {
        AppLogger.warning('Firestoreにデータなし。新規取得をリクエスト', tag: 'SettingsService');
        await _requestNewDataFromFunctions();
        return null;
      }
    } catch (e) {
      AppLogger.error('気象データ取得エラー', error: e, tag: 'SettingsService');
      rethrow;
    }
  }

  /// 内部用気象データ取得
  Future<void> _fetchWeatherData({bool isPeriodicCheck = false}) async {
    await fetchWeatherData(isPeriodicCheck: isPeriodicCheck);
  }

  /// Firebase Functionsに新しいデータをリクエスト
  Future<void> _requestNewDataFromFunctions() async {
    if (_currentLocation == null) return;

    try {
      AppLogger.info('Firebase Functionsに新規データリクエスト', tag: 'SettingsService');

      final uri = Uri.parse(
        'https://us-central1-thunder-cloud-app-292e6.cloudfunctions.net/getWeatherData'
        '?latitude=${_currentLocation!.latitude}&longitude=${_currentLocation!.longitude}'
      );

      final response = await HttpClient().getUrl(uri).then((request) => request.close());

      if (response.statusCode == 200) {
        AppLogger.success('Firebase Functions呼び出し成功', tag: 'SettingsService');

        // 少し待ってから再度Firestoreをチェック
        await Future.delayed(AppConstants.settingsUpdateDelay);

        final weatherData = await _cacheService.getWeatherDataWithCache(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );

        if (weatherData != null) {
          _weatherData = weatherData;
          _lastUpdateTime = DateTime.now();
          AppLogger.success('新規データをFirestoreから取得完了', tag: 'SettingsService');
        }
      } else {
        AppLogger.error('Firebase Functions呼び出し失敗: ${response.statusCode}', tag: 'SettingsService');
      }
    } catch (e) {
      AppLogger.error('Firebase Functions呼び出しエラー', error: e, tag: 'SettingsService');
    }
  }

  // ===== 監視機能 =====

  /// 定期監視を開始
  void _startPeriodicMonitoring() {
    AppLogger.info('定期監視開始 (${AppConstants.periodicUpdateInterval.inSeconds}秒間隔)', tag: 'SettingsService');

    _updateTimer = Timer.periodic(AppConstants.periodicUpdateInterval, (timer) {
      if (_currentLocation != null) {
        _fetchWeatherData(isPeriodicCheck: true);
      }
    });
  }

  /// リアルタイム監視を開始
  void _startRealtimeMonitoring() {
    if (_currentLocation == null) return;

    AppLogger.info('リアルタイム監視開始', tag: 'SettingsService');

    _realtimeSubscription = _cacheService.startRealtimeWeatherDataListener(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
    ).listen(
      (weatherData) {
        if (weatherData != null) {
          _weatherData = weatherData;
          _lastUpdateTime = DateTime.now();
          AppLogger.info('リアルタイム更新: データ受信', tag: 'SettingsService');
        }
      },
      onError: (error) {
        AppLogger.error('リアルタイム監視エラー', error: error, tag: 'SettingsService');
      },
    );
  }

  /// リアルタイム監視を再開
  void _restartRealtimeMonitoring() {
    _realtimeSubscription?.cancel();
    _startRealtimeMonitoring();
  }

  // ===== キャッシュ管理 =====

  /// キャッシュ統計を取得
  Future<Map<String, dynamic>> getCacheStatistics() async {
    try {
      return await _cacheService.getCacheStats();
    } catch (e) {
      AppLogger.error('キャッシュ統計取得エラー', error: e, tag: 'SettingsService');
      return {};
    }
  }

  /// キャッシュをクリア
  Future<void> clearCache() async {
    // WeatherCacheServiceにclearCacheメソッドが存在しないため、
    // ローカル変数のみクリア
    _weatherData.clear();
    _lastUpdateTime = null;
    AppLogger.success('キャッシュクリア完了（ローカルのみ）', tag: 'SettingsService');
  }

  // ===== データ更新コールバック =====

  /// データ更新時のコールバックを設定
  void setDataUpdateCallback(Function(Map<String, dynamic>, DateTime?) callback) {
    // 現在のデータでコールバックを実行
    if (_weatherData.isNotEmpty) {
      callback(_weatherData, _lastUpdateTime);
    }

    // リアルタイム更新時のコールバックを設定
    _realtimeSubscription?.cancel();
    if (_currentLocation != null) {
      _realtimeSubscription = _cacheService.startRealtimeWeatherDataListener(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      ).listen(
        (weatherData) {
          if (weatherData != null) {
            _weatherData = weatherData;
            _lastUpdateTime = DateTime.now();
            callback(_weatherData, _lastUpdateTime);
          }
        },
        onError: (error) {
          AppLogger.error('リアルタイム監視エラー', error: error, tag: 'SettingsService');
        },
      );
    }
  }
}
