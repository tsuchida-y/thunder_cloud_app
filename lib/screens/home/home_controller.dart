import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/lat_lng.dart';
import '../../models/sky_cloud.dart';
import '../../models/sky_now.dart';
import '../../services/location/current_place.dart';
import '../../services/member/member_service.dart';
import '../../services/notification/cloud_notifications.dart';
import '../../services/plus/plus_service.dart';
import '../../services/sky/report_service.dart';
import '../../services/sky/sky_repository.dart';
import '../../services/widget/sky_widget.dart';
import '../../utils/logger.dart';
import '../../utils/sun_times.dart';

/// ホームに出す画面の種類
enum HomeMode {
  /// はじめの読み込み中
  loading,

  /// 入道雲が見えている（Main.html）
  clouds,

  /// 雲がない（Empty.html）
  empty,

  /// 夜（Night.html）
  night,

  /// 通信できない（Offline.html）
  offline,

  /// 場所が分からない（NoPermission.html）
  noPermission,
}

/// 夜の画面の「きょう見えた入道雲」
class TodaysCloud {
  final DateTime from;
  final DateTime to;
  final String directionName;
  final int distanceKm;

  const TodaysCloud({required this.from, required this.to, required this.directionName, required this.distanceKm});
}

/// ホームの上のチップで切り替える、見張っている場所（場所の見せ方_画面一覧.png）
class WatchSpot {
  /// 'now'（いまいる場所）か 'place0'〜'place2'（登録した場所）
  final String id;

  /// チップの文字（「現在地」「家」）
  final String label;

  /// 地名（「滝沢市」「盛岡市」）。分からなければ null
  final String? placeName;
  final LatLng point;
  final bool isCurrent;

  const WatchSpot({
    required this.id,
    required this.label,
    required this.placeName,
    required this.point,
    required this.isCurrent,
  });

  /// 見出しの上の札に出す名前（「滝沢市」「家（盛岡市）」）
  String get badgeName {
    if (isCurrent) return placeName ?? 'いまいる場所';
    return placeName == null || placeName == label ? label : '$label（$placeName）';
  }
}

/// チップ1つ分（その場所に雲があるか）
class SpotChip {
  final WatchSpot spot;
  final bool hasCloud;

  const SpotChip(this.spot, this.hasCloud);
}

/// いま選んでいない場所に出ている雲（ホームの一覧の「家 ・ 北 ・ 55km」の行）
class OtherSpotCloud {
  final WatchSpot spot;
  final CloudView view;

  const OtherSpotCloud(this.spot, this.view);
}

class HomeState {
  final HomeMode mode;

  /// 見出しの上の札に出す、いま選んでいる場所の名前（「滝沢市」「家（盛岡市）」）。分からなければ null
  final String? placeName;

  /// ホームの上のチップ（見張っている場所）と、いま選んでいる場所
  final List<SpotChip> spots;
  final String? selectedSpotId;

  /// いま選んでいない場所に出ている雲
  final List<OtherSpotCloud> otherSpotClouds;

  final bool isPlus;

  /// 登録した場所の数（Plus の「＋」を出すか決める）
  final int placeCount;

  /// 見える範囲の雲（近い順）
  final List<CloudView> clouds;

  /// 範囲（無料 30km、Plus は設定の範囲）
  final double rangeKm;

  /// 最後に空を見た時刻（気象庁のデータの時刻）
  final DateTime? observedAt;

  final DateTime? nextSunrise;
  final TodaysCloud? todaysCloud;
  final LastSky? lastSky;

  /// 近くのアメダスのいまの観測（「日が差しています・気温18℃・見通し20km以上」）。分からなければ null
  final SkyNow? skyNow;

  /// 全国で見えている入道雲のうち、いちばん近いもの（なければ null）と、全国の数
  final NationwideCloud? nearestCloud;
  final int nationwideCount;

  /// 朝や夕方（太陽が低い）か。ホームの空の色を変える
  final bool lowSun;

  /// 許可がないときの画面で、どのカードを出すか
  final bool locationOff;
  final bool notificationsOff;

  const HomeState({
    required this.mode,
    this.placeName,
    this.spots = const [],
    this.selectedSpotId,
    this.otherSpotClouds = const [],
    this.isPlus = false,
    this.placeCount = 0,
    this.clouds = const [],
    this.rangeKm = SkyRules.freeRangeKm,
    this.observedAt,
    this.nextSunrise,
    this.todaysCloud,
    this.lastSky,
    this.skyNow,
    this.nearestCloud,
    this.nationwideCount = 0,
    this.lowSun = false,
    this.locationOff = false,
    this.notificationsOff = false,
  });
}

/// ホームの中身を決める
///
/// 優先する順: 場所が分からない → 夜 → 通信できない → 雲がある / ない。
/// 夜は通信できなくても出せるので、通信できないときより先にする。
class HomeController extends ChangeNotifier with WidgetsBindingObserver {
  HomeState _state = const HomeState(mode: HomeMode.loading);
  HomeState get state => _state;

  /// サーバーから返事がないまま、この時間がたったら「通信できない」にする
  static const Duration offlineAfter = Duration(seconds: 10);

  /// 開発中の確かめ用。デバッグ版で --dart-define=FORCE_DAYTIME=true を付けると、夜でも昼として扱う
  static const bool _forceDaytime = kDebugMode && bool.fromEnvironment('FORCE_DAYTIME');

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cloudSub;
  StreamSubscription<DateTime?>? _observedSub;
  StreamSubscription<Map<String, dynamic>?>? _amedasSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _memberSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _serverSub;
  Timer? _offlineTimer;
  Timer? _minuteTimer;

  bool _signInFailed = false;
  bool _refreshing = false;
  bool _disposed = false;

  LocationAccess? _access;
  bool _isAlways = false;
  static const String _alwaysAskedKey = 'always_allow_asked';
  LatLng? _gps;
  String? _gpsName;
  bool _notificationsOff = false;

  Map<String, dynamic>? _member;
  Map<String, dynamic>? _server;

  List<SkyCloud>? _activeClouds;
  bool _offline = false;
  DateTime? _observedAt;
  Map<String, dynamic>? _amedas;

  /// 全国の入道雲の場所の名前（雲の ID ごとに1回だけ調べる）
  final Map<String, String?> _cloudNames = {};
  LastSky? _lastSky;
  String? _savedSkyKey;

  List<SkyCloud>? _todaysClouds;
  String? _todaysKey;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    // ストアで Plus になったら（買った・復元した）、サーバーに届くのを待たずに描き直す
    PlusService.activeInStore.addListener(_recompute);
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) => _recompute());
    LastSky.load().then((sky) {
      _lastSky = sky;
      _recompute();
    });
    refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    PlusService.activeInStore.removeListener(_recompute);
    _cancelSky();
    _memberSub?.cancel();
    _serverSub?.cancel();
    _minuteTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 設定アプリで許可を変えて戻ってきたときなどに、もう一度確かめる
    if (state == AppLifecycleState.resumed) refresh();
  }

  /// 「もう一度読み込む」
  Future<void> retry() async {
    _cancelSky();
    _offline = false;
    _state = HomeState(mode: HomeMode.loading, placeName: _state.placeName);
    notifyListeners();
    await refresh();
  }

  /// 許可・位置・ログインを確かめ直す
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final String uid;
      try {
        uid = await MemberService.ensureSignedIn();
        _signInFailed = false;
      } catch (e) {
        AppLogger.warning('匿名ログインに失敗: $e', tag: 'HomeController');
        _signInFailed = true;
        _recompute();
        return;
      }
      _listenMember(uid);
      PlusService.configure(uid);
      // 通知のボタンで答えたものを送り、通知の宛先を新しくしておく
      ReportService.flushPending();
      CloudNotifications.registerToken();

      // 許可のお願いは、はじめての起動の画面（Welcome）と、許可がないときの画面のボタンでだけ行う
      final access = await CurrentPlace.access();
      _access = access;
      _notificationsOff = !await CloudNotifications.allowed();

      if (access == LocationAccess.granted) {
        final gps = await CurrentPlace.position();
        if (gps != null) {
          _gps = gps;
          CurrentPlace.placeName(gps).then((name) {
            _gpsName = name;
            _recompute();
          });
        }
        _isAlways = await CurrentPlace.isAlways();
        CurrentPlace.syncBackground();
      } else {
        _gps = null;
      }
      MemberService.recordOpened(location: _gps, clearLocation: access != LocationAccess.granted);

      _listenSky();
      _recompute();
    } finally {
      _refreshing = false;
    }
  }

  /// 「通知をオンにする」
  Future<void> enableNotifications() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      await CloudNotifications.request();
    } else {
      // 一度断った人には、OS の画面からもう一度聞けないので設定アプリを開く
      await CurrentPlace.openAppSettings();
    }
    _notificationsOff = !await CloudNotifications.allowed();
    _recompute();
  }

  /// 「設定アプリを開く」（まだ聞いていなければ、ここで「使用中」をお願いする）
  Future<void> openLocationSettings() async {
    if (_access == LocationAccess.notAsked) {
      _access = await CurrentPlace.request();
      await refresh();
      return;
    }
    if (!await CurrentPlace.openAppSettings()) {
      await CurrentPlace.openLocationSettings();
    }
  }

  String? _selectedSpotId;

  /// 登録した場所（「場所を追加」に渡す）
  List<WatchPlace> get places => MemberService.placesOf(_member);

  /// ホームの上のチップで場所を切り替える
  void selectSpot(String id) {
    _selectedSpotId = id;
    _recompute();
  }

  /// 移動先も見張るお願い（AlwaysAllow.html）を出すときに呼ばれる（ホームが下から出す）
  VoidCallback? onAskAlways;
  bool _checkingAlways = false;

  /// 最初の入道雲の通知が届いたあと（member_server.firstNotifiedAt）、「使用中」の人に1回だけ出す
  Future<void> _maybeAskAlways() async {
    if (_checkingAlways || _server?['firstNotifiedAt'] == null || _access != LocationAccess.granted || _isAlways) {
      return;
    }
    _checkingAlways = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_alwaysAskedKey) == true) return;
      await prefs.setBool(_alwaysAskedKey, true);
      onAskAlways?.call();
    } finally {
      _checkingAlways = false;
    }
  }

  /// 「「常に」にする」
  Future<void> requestAlways() async {
    _isAlways = await CurrentPlace.requestAlways();
    _recompute();
  }

  void _listenMember(String uid) {
    _memberSub ??= MemberService.watchMember(uid).listen((doc) {
      _member = doc.data();
      if (!doc.metadata.isFromCache) MemberService.ensureDefaultSettings(_member);
      _recompute();
    }, onError: (Object e) => AppLogger.warning('members を読めません: $e', tag: 'HomeController'));
    _serverSub ??= MemberService.watchServer(uid).listen((doc) {
      _server = doc.data();
      _recompute();
    }, onError: (Object e) => AppLogger.warning('member_server を読めません: $e', tag: 'HomeController'));
  }

  void _listenSky() {
    _cloudSub ??= SkyRepository.watchActiveClouds().listen((snap) {
      _activeClouds = snap.docs.map(SkyCloud.fromDoc).whereType<SkyCloud>().toList();
      if (snap.metadata.isFromCache) {
        // つながっていないと、端末に残っている分だけが届く。しばらく待ってもサーバーから来なければ通信できない
        _offlineTimer ??= Timer(offlineAfter, () {
          _offline = true;
          _recompute();
        });
      } else {
        _offlineTimer?.cancel();
        _offlineTimer = null;
        _offline = false;
      }
      _recompute();
    }, onError: (Object e) {
      AppLogger.warning('雲の一覧を読めません: $e', tag: 'HomeController');
      _offline = true;
      _recompute();
    });
    _observedSub ??= SkyRepository.watchObservedAt().listen((time) {
      _observedAt = time;
      _recompute();
    }, onError: (Object e) => AppLogger.warning('system/jma_nowcast を読めません: $e', tag: 'HomeController'));
    _amedasSub ??= SkyRepository.watchAmedasLatest().listen((data) {
      _amedas = data;
      _recompute();
    }, onError: (Object e) => AppLogger.warning('system/amedas_latest を読めません: $e', tag: 'HomeController'));
  }

  void _cancelSky() {
    _cloudSub?.cancel();
    _cloudSub = null;
    _observedSub?.cancel();
    _observedSub = null;
    _amedasSub?.cancel();
    _amedasSub = null;
    _offlineTimer?.cancel();
    _offlineTimer = null;
  }

  /// 見張る場所: いまいる場所。分からなければ登録した1か所目（サーバーの watchPointsOf と同じ）
  /// 見張っている場所の一覧（サーバーの watchPointsOf と同じ決まり）
  ///
  /// いまいる場所が分かればそれ。登録した場所を、無料は1か所、Plus は3か所まで足す（2026-10-27、無料でも1か所）。
  List<WatchSpot> _spots(bool isPlus) {
    final spots = <WatchSpot>[];
    if (_gps != null) {
      spots.add(WatchSpot(id: 'now', label: '現在地', placeName: _gpsName, point: _gps!, isCurrent: true));
    }
    final places = MemberService.placesOf(_member);
    final watched = places.take(SkyRules.maxPlaces(isPlus: isPlus));
    for (final place in watched) {
      spots.add(WatchSpot(
        id: placeSpotId(place),
        label: place.label,
        placeName: place.name,
        point: place.location,
        isCurrent: false,
      ));
    }
    return spots;
  }

  /// 登録した場所の ID。並び順ではなく位置から作るので、ほかの場所を消してもずれない（ウィジェットが覚えておく）
  static String placeSpotId(WatchPlace place) {
    final map = place.toMap();
    return 'place_${map['latitude']}_${map['longitude']}';
  }

  /// ある場所から見える範囲の雲（近い順）
  List<CloudView> _viewsAt(LatLng point, double rangeKm) => (_activeClouds ?? const <SkyCloud>[])
      .where((c) => c.isVisible)
      .map((c) => c.viewFrom(point))
      .where((v) => v.distanceKm <= rangeKm)
      .toList()
    ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

  /// 全国で見えている入道雲のうち、いちばん近いもの。名前がまだなら調べに行き、分かったら描き直す
  NationwideCloud? _nearestCloud(List<SkyCloud> visible, LatLng point) {
    if (visible.isEmpty) return null;
    final nearest = visible.map((c) => c.viewFrom(point)).reduce((a, b) => a.distanceKm <= b.distanceKm ? a : b);
    return NationwideCloud(
      id: nearest.cloud.id,
      center: nearest.cloud.center,
      directionName: nearest.directionName,
      distanceKm: nearest.roundedKm,
      placeName: _nameOf(nearest.cloud),
    );
  }

  String? _nameOf(SkyCloud cloud) {
    if (_cloudNames.containsKey(cloud.id)) return _cloudNames[cloud.id];
    _cloudNames[cloud.id] = null;
    CurrentPlace.placeName(cloud.center).then((name) {
      if (name == null || _disposed) return;
      _cloudNames[cloud.id] = name;
      _recompute();
    });
    return null;
  }

  void _recompute() {
    if (_disposed) return;
    final now = DateTime.now();
    final isPlus = MemberService.isPlusActive(_server, now);
    final rangeKm = SkyRules.rangeKm(
      isPlus: isPlus,
      settingKm: (_member?['settings'] as Map?)?['rangeKm'] as num?,
    );
    final spots = _spots(isPlus);
    final selected = spots.isEmpty
        ? null
        : spots.firstWhere((s) => s.id == _selectedSpotId, orElse: () => spots.first);
    final watch = selected == null ? null : (point: selected.point, name: selected.badgeName);
    final chips = [for (final s in spots) SpotChip(s, _viewsAt(s.point, rangeKm).isNotEmpty)];
    final others = [
      for (final s in spots)
        if (s.id != selected?.id && _viewsAt(s.point, rangeKm).isNotEmpty) OtherSpotCloud(s, _viewsAt(s.point, rangeKm).first),
    ];
    final placeCount = MemberService.placesOf(_member).length;

    HomeState next;
    if (_signInFailed) {
      next = HomeState(mode: HomeMode.offline, placeName: watch?.name, lastSky: _lastSky);
    } else if (watch == null) {
      next = _access == null
          ? const HomeState(mode: HomeMode.loading)
          : HomeState(mode: HomeMode.noPermission, locationOff: true, notificationsOff: _notificationsOff);
    } else if (!_forceDaytime && !SunTimes.isDaytime(now, watch.point.latitude, watch.point.longitude)) {
      _loadTodaysClouds(now, watch.point);
      next = HomeState(
        mode: HomeMode.night,
        placeName: watch.name,
        spots: chips,
        selectedSpotId: selected!.id,
        isPlus: isPlus,
        placeCount: placeCount,
        nextSunrise: SunTimes.nextSunrise(now, watch.point.latitude, watch.point.longitude),
        todaysCloud: _todaysCloud(now, watch.point, rangeKm),
      );
    } else if (_offline) {
      next = HomeState(mode: HomeMode.offline, placeName: watch.name, lastSky: _lastSky);
    } else if (_activeClouds == null) {
      next = HomeState(mode: HomeMode.loading, placeName: watch.name);
    } else {
      final views = _viewsAt(watch.point, rangeKm);
      final visibleClouds = _activeClouds!.where((c) => c.isVisible).toList();
      final lowSun = !SunTimes.isDaytime(now, watch.point.latitude, watch.point.longitude, altitudeDeg: SunTimes.lowSunDeg);
      final observedAt = _observedAt ??
          (_activeClouds!.isEmpty
              ? null
              : _activeClouds!.map((c) => c.lastSeenAt).reduce((a, b) => a.isAfter(b) ? a : b));
      next = HomeState(
        mode: views.isEmpty ? HomeMode.empty : HomeMode.clouds,
        placeName: watch.name,
        spots: chips,
        selectedSpotId: selected!.id,
        otherSpotClouds: others,
        isPlus: isPlus,
        placeCount: placeCount,
        clouds: views,
        rangeKm: rangeKm,
        observedAt: observedAt,
        skyNow: SkyNow.near(_amedas, watch.point, now),
        nearestCloud: _nearestCloud(visibleClouds, watch.point),
        nationwideCount: visibleClouds.length,
        lowSun: lowSun,
      );
      // 「最後に見た空」とウィジェットは、いまいる場所（なければ1つ目の場所）のもの
      if (selected.id == spots.first.id) _rememberSky(views, observedAt ?? now);
    }

    _state = next;
    notifyListeners();
    _updateWidget(next, spots, isPlus, rangeKm, now);
    if (next.mode != HomeMode.loading && next.mode != HomeMode.noPermission) _maybeAskAlways();
  }

  /// ウィジェットに、見張っているすべての場所の空を渡す（ウィジェットごとに見る場所を選べる）
  void _updateWidget(HomeState state, List<WatchSpot> spots, bool isPlus, double rangeKm, DateTime now) {
    if (state.mode == HomeMode.loading || state.mode == HomeMode.noPermission) return;
    final offline = state.mode == HomeMode.offline;
    SkyWidget.update(
      isPlus: isPlus,
      observedAt: state.observedAt,
      spots: [
        for (final spot in spots)
          () {
            final daytime = _forceDaytime || SunTimes.isDaytime(now, spot.point.latitude, spot.point.longitude);
            final views = daytime && !offline ? _viewsAt(spot.point, rangeKm) : const <CloudView>[];
            final nearest = views.isEmpty ? null : views.first;
            return WidgetSpot(
              id: spot.id,
              label: spot.label,
              placeName: spot.placeName,
              mode: !daytime
                  ? 'night'
                  : offline
                      ? 'offline'
                      : _activeClouds == null
                          ? 'none'
                          : (nearest == null ? 'empty' : 'clouds'),
              direction: nearest?.directionName,
              bearingDeg: nearest?.bearingDeg,
              km: nearest?.roundedKm,
              fists: nearest?.fistsLabel,
            );
          }(),
      ],
    );
  }

  void _rememberSky(List<CloudView> views, DateTime checkedAt) {
    final nearest = views.isEmpty ? null : views.first;
    final key = nearest == null ? 'none' : '${nearest.directionName}_${nearest.roundedKm}_${checkedAt.millisecondsSinceEpoch}';
    if (key == _savedSkyKey) return;
    _savedSkyKey = key;
    _lastSky = nearest == null
        ? null
        : LastSky(checkedAt: checkedAt, directionName: nearest.directionName, distanceKm: nearest.roundedKm);
    LastSky.save(_lastSky);
  }

  void _loadTodaysClouds(DateTime now, LatLng point) {
    final key = '${now.year}-${now.month}-${now.day}_${point.latitude}_${point.longitude}';
    if (key == _todaysKey) return;
    _todaysKey = key;
    _todaysClouds = null;
    SkyRepository.cloudsSeenSince(DateTime(now.year, now.month, now.day)).then((clouds) {
      _todaysClouds = clouds;
      _recompute();
    }).catchError((Object e) {
      AppLogger.warning('きょうの雲を読めません: $e', tag: 'HomeController');
    });
  }

  /// きょうの空が明るいあいだ（市民薄明）に範囲にあった雲のうち、いちばん近いもの
  TodaysCloud? _todaysCloud(DateTime now, LatLng point, double rangeKm) {
    final day = SunTimes.forLocalDay(now, point.latitude, point.longitude);
    final clouds = _todaysClouds;
    if (clouds == null || day.sunrise == null || day.sunset == null) return null;

    CloudView? best;
    for (final cloud in clouds) {
      if (!cloud.firstSeenAt.isBefore(day.sunset!) || !cloud.lastSeenAt.isAfter(day.sunrise!)) continue;
      final view = cloud.viewFrom(point);
      if (view.distanceKm > rangeKm) continue;
      if (best == null || view.distanceKm < best.distanceKm) best = view;
    }
    if (best == null) return null;
    final from = best.cloud.firstSeenAt.isBefore(day.sunrise!) ? day.sunrise! : best.cloud.firstSeenAt;
    final to = best.cloud.lastSeenAt.isAfter(day.sunset!) ? day.sunset! : best.cloud.lastSeenAt;
    return TodaysCloud(
      from: from,
      to: DateTime.fromMillisecondsSinceEpoch(math.max(from.millisecondsSinceEpoch, to.millisecondsSinceEpoch)),
      directionName: best.directionName,
      distanceKm: best.roundedKm,
    );
  }
}
