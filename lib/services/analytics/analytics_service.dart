import 'dart:async';
import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../utils/logger.dart';

/// 計測の送り先。Firebase のほかに変えたいときは、これを実装したクラスを [AnalyticsService.init] に渡す
abstract class AnalyticsBackend {
  Future<void> logEvent(String name, Map<String, Object>? parameters);
  Future<void> logScreenView(String screenName);
  Future<void> setUserProperty(String name, String? value);
  Future<void> setCrashKey(String key, String value);
}

/// Firebase Analytics と Crashlytics に送る
class FirebaseAnalyticsBackend implements AnalyticsBackend {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) =>
      _analytics.logEvent(name: name, parameters: parameters);

  @override
  Future<void> logScreenView(String screenName) =>
      _analytics.logScreenView(screenName: screenName, screenClass: screenName);

  @override
  Future<void> setUserProperty(String name, String? value) => _analytics.setUserProperty(name: name, value: value);

  @override
  Future<void> setCrashKey(String key, String value) => _crashlytics.setCustomKey(key, value);
}

/// 計測（利用状況）の入口。イベント名とパラメータは、ここだけに書く（docs/計測プラン.md と同じにする）
///
/// - 送るのは、決まった値（選択肢）と数字だけ。地名・場所の名前・入力した文・正確な位置は送らない。
/// - Firebase のユーザー ID は設定しない（端末ごとの匿名の ID だけになる）。
/// - デバッグ版は送らない（ネイティブの設定で最初から止めてあり、[init] でリリース版だけオンにする）。
/// - 送るのに失敗しても、例外は外に出さない（アプリの動きを止めない）。
/// - [init] の前と、テストのときは何もしない。
class AnalyticsService {
  AnalyticsService._();

  static AnalyticsBackend? _backend;
  static String _lastScreen = 'none';
  static String _lastAction = 'none';
  static DateTime _foregroundSince = DateTime.now();
  static _LifecycleWatcher? _watcher;

  static const MethodChannel _buildChannel = MethodChannel('thunder_cloud/build_channel');

  /// 最後に出した画面と、最後に送ったイベント（離脱の分析用。テストからも見る）
  static String get lastScreen => _lastScreen;
  static String get lastAction => _lastAction;

  /// アプリの起動時に1回呼ぶ（Firebase の初期化のあと）。リリース版だけ送信をオンにする
  static Future<void> init() async {
    if (kDebugMode) return;
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      // 落ちたときの記録（Dart の例外と、Flutter の描画の例外）
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      attach(FirebaseAnalyticsBackend());
      await _backend?.setUserProperty('channel', await _channel());
    } catch (e) {
      AppLogger.warning('計測を始められませんでした: $e', tag: 'AnalyticsService');
    }
  }

  /// 送り先をつなぐ（テストでは、記録するだけの送り先を渡す）
  @visibleForTesting
  static void attach(AnalyticsBackend? backend) {
    _backend = backend;
    _lastScreen = 'none';
    _lastAction = 'none';
    _foregroundSince = DateTime.now();
    if (backend != null && _watcher == null) {
      _watcher = _LifecycleWatcher();
      WidgetsBinding.instance.addObserver(_watcher!);
    }
  }

  /// TestFlight の版か、ストアの版か（Android はストアの版として扱う）
  static Future<String> _channel() async {
    if (!Platform.isIOS) return 'production';
    try {
      return await _buildChannel.invokeMethod<String>('channel') ?? 'production';
    } catch (_) {
      return 'production';
    }
  }

  // ---- 画面 ----

  /// 最初の画面（MaterialApp の home）の名前（intro_1 / welcome / home）。起動のときに MyApp が入れる
  static String rootScreen = 'home';

  /// 画面やシートが出た。名前は docs/計測プラン.md の一覧から選ぶ
  static void screen(String name) {
    _lastScreen = name;
    _run(() async {
      await _backend!.logScreenView(name);
      await _backend!.setCrashKey('last_screen', name);
    });
  }

  /// ホームの状態が決まった（clouds / empty / night / offline / no_permission）
  static void homeStateShown(String state) => _event('home_state_shown', {'state': state});

  // ---- 初回起動から主な機能まで ----

  static void onboardingCompleted() => _event('onboarding_completed');

  /// kind: location / notification / location_always
  static void permissionPromptShown(String kind) => _event('permission_prompt_shown', {'kind': kind});

  /// result: granted / denied
  static void permissionResult(String kind, {required bool granted}) =>
      _event('permission_result', {'kind': kind, 'result': granted ? 'granted' : 'denied'});

  /// via: tap / seen_button / not_seen_button
  static void notificationOpened(String via) => _event('notification_opened', {'via': via});

  /// source: home / notification / list
  static void finderOpened(String source) => _event('finder_opened', {'source': source});

  /// 方角ガイドを開いてから向きが合うまでの秒数
  static void finderAligned(int seconds) => _event('finder_aligned', {'seconds': seconds});

  /// answer: seen / not_seen、source: どこから答えたか（reports と同じ値）
  static void cloudReport({required bool seen, required String source}) =>
      _event('cloud_report', {'answer': seen ? 'seen' : 'not_seen', 'source': source});

  // ---- 設定と場所 ----

  static void notifyToggled(bool enabled) => _event('notify_toggled', {'enabled': enabled ? 1 : 0});
  static void rangeChanged(int km) => _event('range_changed', {'km': km});
  static void quietHoursChanged() => _event('quiet_hours_changed');
  static void placeAdded(int placeCount) => _event('place_added', {'place_count': placeCount});
  static void placeRemoved(int placeCount) => _event('place_removed', {'place_count': placeCount});
  static void nationwideOpened(int count) => _event('nationwide_opened', {'count': count});

  // ---- Plus ----

  /// source: settings / home / places / range など、どこから開いたか
  static void plusViewed(String source) => _event('plus_viewed', {'source': source});

  /// product: monthly / lifetime
  static void purchaseStarted(String product) => _event('purchase_started', {'product': product});

  /// result: success / cancelled / failed / pending
  static void purchaseResult(String product, String result) =>
      _event('purchase_result', {'product': product, 'result': result});

  /// result: success / not_found / failed
  static void restoreResult(String result) => _event('restore_result', {'result': result});

  // ---- つまずき ----

  /// kind: location_unavailable / network / sky_load_failed / geocode_failed / compass_unavailable / purchase_failed
  /// エラーの文章は送らない（種類だけ）
  static void errorShown(String kind) => _event('error_shown', {'kind': kind});

  static void calibrateShown() => _event('calibrate_shown');

  /// 雲の一覧を読み込むのにかかった時間
  static void skyLoaded(Duration took, {required bool ok}) =>
      _event('sky_loaded', {'duration_ms': took.inMilliseconds, 'result': ok ? 'ok' : 'failed'});

  // ---- 利用者の属性 ----

  static void setUserState({bool? isPlus, String? lang, int? placeCount}) {
    _run(() async {
      if (isPlus != null) await _backend!.setUserProperty('is_plus', isPlus ? 'yes' : 'no');
      if (lang != null) await _backend!.setUserProperty('lang', lang);
      if (placeCount != null) await _backend!.setUserProperty('place_count', '$placeCount');
    });
  }

  // ---- 離脱 ----

  /// アプリが裏に回った（最後の画面と、直前の操作）
  static void appBackground() {
    final seconds = DateTime.now().difference(_foregroundSince).inSeconds;
    final params = <String, Object>{'last_screen': _lastScreen, 'last_action': _lastAction, 'session_seconds': seconds};
    _run(() => _backend!.logEvent('app_background', params));
  }

  static void appForeground() => _foregroundSince = DateTime.now();

  // ---- 中身 ----

  static void _event(String name, [Map<String, Object>? parameters]) {
    _lastAction = name;
    _run(() => _backend!.logEvent(name, parameters));
  }

  static void _run(Future<void> Function() send) {
    if (_backend == null) return;
    unawaited(send().catchError((Object e) {
      AppLogger.warning('計測を送れませんでした: $e', tag: 'AnalyticsService');
    }));
  }
}

class _LifecycleWatcher with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) AnalyticsService.appBackground();
    if (state == AppLifecycleState.resumed) AnalyticsService.appForeground();
  }
}
