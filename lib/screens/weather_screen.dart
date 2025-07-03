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
  /*
  ================================================================================
                                    状態管理
                          画面の状態を保持する変数群
  ================================================================================
  */
  LatLng? _currentLocation;
  final List<String> _matchingCities = []; // 入道雲が検出された方向 ('north', 'south', 'east', 'west')
  bool _isInitialized = false;
  bool _servicesInitialized = false; // 重複初期化防止フラグ

  /*
  ================================================================================
                                   タイマー管理
                          定期実行処理のタイマー制御
  ================================================================================
  */
  Timer? _locationWaitTimer;
  Timer? _weatherDataTimer;

  /*
  ================================================================================
                                    サービス
                         外部処理を担当するサービスクラス
  ================================================================================
  */

  /// ウィジェット初期化処理
  /// initState() : Widgetが生成されたときに呼ばれる
  /// 画面ライフサイクル監視を開始し、非同期で画面初期化を実行
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);//監視の開始を登録
    // マイクロタスクで初期化を後回しにして、UIを先に実行させる
    Future.microtask(() => _initializeScreen());
  }

  /// ウィジェット破棄処理
  /// dispose() : Widgetが破棄されたときに呼ばれる
  /// 画面ライフサイクル監視を停止し、リソースをクリーンアップ
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);//監視の終了を登録
    _cleanupResources();//タイマー停止、電話解除、フラグリセット
    super.dispose();// Flutterフレームワークの後片付け
  }

  /*
  ================================================================================
                                ライフサイクル管理
                       アプリの状態変化（起動・停止）への対応
  ================================================================================
  */

  /// アプリケーションライフサイクル状態変更処理
  /// フォアグラウンド復帰時の気象データ更新などを管理
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed://アプリ復帰時
        _handleAppResumed();
        break;
      case AppLifecycleState.paused://アプリ一時停止時の処理
        _handleAppPaused();
        break;
      default:
        break;
    }
  }

  /// アプリ復帰時の処理
  /// 気象データの鮮度確保のため再取得を実行
  void _handleAppResumed() {
    AppLogger.info('アプリが再開されました', tag: 'WeatherScreen');
    // アプリ復帰時に気象データを再取得（データの鮮度確保）
    if (_currentLocation != null) {
      _updateWeatherData();
    }
  }

  /// アプリ一時停止時の処理
  /// 現在は主にログ出力のみ
  void _handleAppPaused() {
    AppLogger.info('アプリが一時停止されました', tag: 'WeatherScreen');
  }

  /*
  ================================================================================
                                 初期化メソッド
                          画面・サービス・通知の初期設定
  ================================================================================
  */

  /// 画面の初期化処理
  /// 既に初期化済みの場合は位置情報確認のみ、未初期化の場合は完全初期化を実行
  Future<void> _initializeScreen() async {
    if (_isInitialized) {
      AppLogger.info('WeatherScreen は既に初期化済み - 位置情報のみ確認', tag: 'WeatherScreen');
      // 初期化済みの場合は位置情報の確認のみ
      if (_currentLocation == null) {
        await _loadLocationDataOptimized();
      }
      return;
    }

    try {
      AppLogger.info('WeatherScreen初期化開始', tag: 'WeatherScreen');
      final initStartTime = DateTime.now();

      // パフォーマンス向上：サービス初期化と位置情報取得を並列実行
      await Future.wait([
        _initializeServices(),
        _loadLocationDataOptimized(),
      ]);

      _isInitialized = true;
      final initDuration = DateTime.now().difference(initStartTime);
      AppLogger.success('WeatherScreen初期化完了 (${initDuration.inMilliseconds}ms)', tag: 'WeatherScreen');
    } catch (e) {
      AppLogger.error('WeatherScreen初期化エラー', error: e, tag: 'WeatherScreen');
    }
  }

  /// 必要なサービスの初期化
  /// 一度初期化されたサービスは再初期化をスキップ
  Future<void> _initializeServices() async {
    if (_servicesInitialized) {
      AppLogger.info('サービスは既に初期化済み', tag: 'WeatherScreen');
      return;
    }

    try {
      _setupCallbacks();
      await _initializeNotifications();
      _startWeatherDataMonitoring();
      _servicesInitialized = true;
      AppLogger.success('サービス初期化完了', tag: 'WeatherScreen');
    } catch (e) {
      AppLogger.error('サービス初期化エラー', error: e, tag: 'WeatherScreen');
    }
  }

  /// 通知サービスの初期化
  /// 通知許可取得とプッシュ通知サービスの設定を実行
  Future<void> _initializeNotifications() async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      await PushNotificationService.initialize();
    } catch (e) {
      AppLogger.error('通知初期化エラー', error: e, tag: 'WeatherScreen');
    }
  }

  /// コールバック関数の設定
  /// 位置変更と入道雲検出時の処理をリスナーとして登録
  void _setupCallbacks() {
    // 位置変更とプッシュ通知のコールバックを設定
    LocationService.onLocationChanged = _handleLocationUpdate;
    PushNotificationService.onThunderCloudDetected = _handleThunderCloudDetection;
  }

  /*
  ================================================================================
                              気象データ監視機能
                       入道雲発生条件の監視とデータ更新処理
  ================================================================================
  */
  final WeatherCacheService _weatherService = WeatherCacheService();

  /// 気象データ監視の開始
  /// 30秒間隔で気象データを取得し、入道雲発生条件を監視
  void _startWeatherDataMonitoring() {
    // 既にタイマーが動作している場合はスキップ
    if (_weatherDataTimer != null && _weatherDataTimer!.isActive) {
      AppLogger.info('気象データ監視は既に実行中', tag: 'WeatherScreen');
      return;
    }

    AppLogger.info('気象データ監視開始', tag: 'WeatherScreen');

    // 入道雲検知のため30秒間隔で気象データを監視
    _weatherDataTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentLocation != null) {
        _updateWeatherData();
      }
    });
  }

  /// 気象データの更新とマッチング都市の更新
  /// 現在位置の気象データを取得し、関連する都市を検索
  Future<void> _updateWeatherData() async {
    if (_currentLocation == null) return;

    try {
      //現在地の天気データをFirestoreのキャッシュから取得している
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

  /// 気象データからマッチング都市の更新
  /// 4方向の気象データを解析し、入道雲発生可能性をチェック
  void _updateMatchingCitiesFromWeatherData(Map<String, dynamic> weatherData) {
    final newMatchingCities = <String>[];

    // 4方向（北・南・東・西）で入道雲の可能性が高い方向を抽出
    for (final direction in AppConstants.checkDirections) {
      if (!weatherData.containsKey(direction)) continue;

      final directionData = weatherData[direction] as Map<String, dynamic>?;
      if (directionData == null) continue;

      final bestData = _selectBestDistanceData(direction, directionData);
      if (bestData == null || !bestData.containsKey('analysis')) continue;

      final analysis = bestData['analysis'] as Map<String, dynamic>?;
      if (analysis != null && analysis['isLikely'] == true) {
        newMatchingCities.add(direction);
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
  /// 複数距離（50km, 160km, 250km）の解析結果から最高スコアを選ぶ
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

  /// マッチング都市変更の検知
  /// 現在のマッチング都市リストと新しいリストを比較
  bool _hasMatchingCitiesChanged(List<String> newMatchingCities) {
    if (_matchingCities.length != newMatchingCities.length) return true;

    for (final city in newMatchingCities) {
      if (!_matchingCities.contains(city)) return true;
    }

    return false;
  }

  /*
  ================================================================================
                                 位置情報管理
                          GPS取得・キャッシュ・最適化処理
  ================================================================================
  */

  /// 最適化された位置情報取得（画面遷移用）
  /// キャッシュ優先で高速表示を実現
  Future<void> _loadLocationDataOptimized() async {
    final startTime = DateTime.now();
    AppLogger.info('最適化された位置情報取得開始', tag: 'WeatherScreen');

    // 1. まず画面遷移用の高速取得を試行（キャッシュ利用）
    final fastLocation = LocationService.getLocationForScreenTransition();

    if (fastLocation != null) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      AppLogger.success('キャッシュされた位置情報を即座に使用: $fastLocation (${elapsed}ms)', tag: 'WeatherScreen');

      if (mounted) {
        setState(() => _currentLocation = fastLocation);
      }

      // 軽量な天気データ更新
      _updateWeatherDataIfNeeded();
      return;
    }

    // 2. キャッシュがない場合は通常の位置情報取得を実行
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    AppLogger.warning('キャッシュなし - 通常の位置情報取得を実行 (${elapsed}ms)', tag: 'WeatherScreen');
    await _loadLocationFast();
  }

  /// 気象データ更新の必要性チェック
  /// キャッシュがあれば即座に利用、なければ新規取得
  void _updateWeatherDataIfNeeded() {
    if (_currentLocation != null) {
      final latitude = _currentLocation!.latitude;
      final longitude = _currentLocation!.longitude;

      // キャッシュされた天気データがあるかチェック
      _weatherService.getWeatherDataWithCache(latitude, longitude).then((weatherData) {
        if (weatherData != null) {
          // キャッシュされた天気データがある場合
          _updateMatchingCitiesFromWeatherData(weatherData);
          AppLogger.info('キャッシュされた天気データを使用', tag: 'WeatherScreen');
        } else {
          // キャッシュがない場合は新規取得
          _updateWeatherData();
        }
      }).catchError((e) {
        AppLogger.error('天気データキャッシュチェックエラー', error: e, tag: 'WeatherScreen');
        _updateWeatherData();
      });
    }
  }

  /// 高速位置情報取得処理
  /// LocationService.getLocationFast()を使用してキャッシュ優先で取得
  Future<void> _loadLocationFast() async {
    final startTime = DateTime.now();
    try {
      AppLogger.info('高速位置情報取得開始', tag: 'WeatherScreen');

      final location = await LocationService.getLocationFast();
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      if (location != null && mounted) {
        setState(() => _currentLocation = location);
        AppLogger.success('高速位置情報取得成功: $location (${elapsed}ms)', tag: 'WeatherScreen');

        // 位置情報取得後、気象データも自動取得
        _updateWeatherData();
      } else {
        AppLogger.warning('高速位置情報取得失敗 - フォールバック実行 (${elapsed}ms)', tag: 'WeatherScreen');
        _fallbackLocationRetrieval();
      }
    } catch (e) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      AppLogger.error('高速位置情報取得エラー (${elapsed}ms)', error: e, tag: 'WeatherScreen');
      _fallbackLocationRetrieval();
    }
  }

  /// フォールバック位置情報取得処理
  /// 高速取得に失敗した場合の通常のGPS取得
  Future<void> _fallbackLocationRetrieval() async {
    try {
      AppLogger.info('フォールバック位置情報取得開始', tag: 'WeatherScreen');

      final location = await LocationService.getCurrentLocationAsLatLng(forceRefresh: true)
          .timeout(AppConstants.locationTimeout);

      if (location != null && mounted) {
        setState(() => _currentLocation = location);
        AppLogger.success('フォールバック位置情報取得成功: $location', tag: 'WeatherScreen');

        // 位置情報取得後、気象データも自動取得
        _updateWeatherData();
      }
    } catch (e) {
      AppLogger.error('フォールバック位置情報取得エラー', error: e, tag: 'WeatherScreen');
    }
  }

  /*
  ================================================================================
                               イベントハンドラー
                      ユーザー操作・通知・位置変更への応答処理
  ================================================================================
  */

  /// 入道雲検出通知の処理
  /// プッシュ通知からの日本語方向を英語キーに変換してマッチング都市を更新
  void _handleThunderCloudDetection(List<String> directions) {
    // プッシュ通知からの日本語方向を英語キーに変換
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

  /// 位置変更時の処理
  /// 新しい位置で気象データを更新して最新の入道雲情報を取得
  void _handleLocationUpdate(LatLng newLocation) {
    AppLogger.info('位置情報更新: $newLocation', tag: 'WeatherScreen');

    if (mounted) {
      setState(() => _currentLocation = newLocation);
      // 位置変更時は気象データも更新（新しいエリアの入道雲情報取得）
      _updateWeatherData();
    }
  }

  /*
  ================================================================================
                              ユーティリティメソッド
                        補助的な処理・リソース管理・状態取得
  ================================================================================
  */

  /// リソースクリーンアップ処理
  /// タイマーとコールバックを解除し、状態をリセット
  void _cleanupResources() {
    _locationWaitTimer?.cancel();
    _weatherDataTimer?.cancel();
    LocationService.onLocationChanged = null;
    PushNotificationService.onThunderCloudDetected = null;

    // 状態をリセット
    _servicesInitialized = false;

    AppLogger.info('WeatherScreen リソースクリーンアップ完了', tag: 'WeatherScreen');
  }

  /// MainScreen用の現在位置提供
  /// AppBarで表示する位置情報を返す
  LatLng? getCurrentLocationForAppBar() {
    return _currentLocation;
  }

  /// ウィジェット構築処理
  /// グラデーション背景、地図、雲状態オーバーレイを組み合わせたUI
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
          // 背景地図（常時表示）
          BackgroundMapWidget(currentLocation: _currentLocation),

          // 雲状態オーバーレイ（位置情報取得後のみ表示）
          if (_currentLocation != null)
            CloudStatusOverlay(matchingCities: _matchingCities),
        ],
      ),
    );
  }
}



