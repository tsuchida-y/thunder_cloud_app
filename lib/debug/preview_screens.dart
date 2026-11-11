// ignore_for_file: prefer_const_constructors
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/finder_target.dart';
import '../models/lat_lng.dart';
import '../models/sky_cloud.dart';
import '../models/sky_now.dart';
import '../screens/finder/calibrate_sheet.dart';
import '../screens/finder/finder_screen.dart';
import '../screens/home/always_allow_sheet.dart';
import '../screens/home/home_controller.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/whats_new_sheet.dart';
import '../screens/home/widgets/nationwide_sheet.dart';
import '../screens/intro/intro_screen.dart';
import '../screens/plus/plus_screen.dart';
import '../screens/record/record_screen.dart';
import '../screens/settings/add_place_sheet.dart';
import '../screens/settings/data_source_screen.dart';
import '../screens/settings/places_screen.dart';
import '../screens/settings/quiet_hours_sheet.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/welcome/welcome_screen.dart';
import '../services/compass/compass_service.dart';
import '../services/member/member_service.dart';
import '../services/sky/sky_repository.dart';
import '../widgets/common/loading_view.dart';

/// 開発中の確かめ用。デバッグ版で --dart-define=START_SCREEN=<名前> を付けると、起動したらその画面を出す。
///
/// 画面ごとの文言（日本語と英語）を、画面を順にたどらなくても見て回るために使う。
/// リリース版には入らない（main.dart で kDebugMode のときだけ呼ぶ）。
class PreviewScreens {
  PreviewScreens._();

  static const List<String> names = [
    'welcome', 'intro', 'intro2', 'intro3', 'plus', 'loading', 'settings', 'places', 'data_source', 'record', 'finder',
    'home_clouds', 'home_plus', 'home_empty', 'home_night', 'home_offline', 'home_nopermission',
    'sheet_whatsnew', 'sheet_always', 'sheet_quiet', 'sheet_addplace', 'sheet_nationwide', 'sheet_calibrate',
  ];

  static const LatLng _takizawa = LatLng(39.73, 141.07);
  static const WatchSpot _now = WatchSpot(id: 'now', label: '現在地', placeName: '滝沢市', point: _takizawa, isCurrent: true);
  static const WatchSpot _home =
      WatchSpot(id: 'place0', label: '家', placeName: '盛岡市', point: LatLng(39.70, 141.15), isCurrent: false);

  static CloudView _cloud(String id, LatLng center, LatLng from) => CloudView(
        SkyCloud(
          id: id,
          center: center,
          firstSeenAt: DateTime.now().subtract(const Duration(minutes: 20)),
          lastSeenAt: DateTime.now(),
          isVisible: true,
          topHeightKm: 12,
        ),
        from,
      );

  static HomeState _state(String name) {
    final near = _cloud('c1', const LatLng(39.50, 141.40), _takizawa);
    final far = _cloud('c2', const LatLng(39.15, 141.75), _takizawa);
    final other = _cloud('c3', const LatLng(40.30, 141.15), _home.point);
    final observed = DateTime.now().subtract(const Duration(minutes: 3));
    final sky = SkyNow(observedAt: observed, tempC: 27, sun1h: 0.9, visibilityKm: 20);
    final chips = [SpotChip(_now, true), SpotChip(_home, true)];
    final nationwide = NationwideCloud(
        id: 'n1', center: const LatLng(26.2, 127.7), directionName: '南西', distanceKm: 1900, placeName: '那覇市のあたり');
    switch (name) {
      case 'home_plus':
        return HomeState(
          mode: HomeMode.clouds,
          placeName: '滝沢市',
          spots: chips,
          selectedSpotId: 'now',
          otherSpotClouds: [OtherSpotCloud(_home, other)],
          isPlus: true,
          placeCount: 2,
          clouds: [near, far],
          rangeKm: 90,
          observedAt: observed,
          skyNow: sky,
          nearestCloud: nationwide,
          nationwideCount: 4,
          nationwideViews: [near, far, other],
        );
      case 'home_empty':
        return HomeState(
          mode: HomeMode.empty,
          placeName: '滝沢市',
          spots: [SpotChip(_now, false)],
          selectedSpotId: 'now',
          observedAt: observed,
          skyNow: sky,
          nearestCloud: nationwide,
          nationwideCount: 4,
          nationwideViews: [near, far, other],
        );
      case 'home_night':
        return HomeState(
          mode: HomeMode.night,
          placeName: '滝沢市',
          spots: [SpotChip(_now, false)],
          selectedSpotId: 'now',
          nextSunrise: DateTime.now().add(const Duration(hours: 7)),
          todaysCloud: TodaysCloud(
              from: DateTime.now().subtract(const Duration(hours: 6)),
              to: DateTime.now().subtract(const Duration(hours: 5)),
              directionName: '南東',
              distanceKm: 42),
        );
      case 'home_offline':
        return HomeState(
          mode: HomeMode.offline,
          placeName: '滝沢市',
          lastSky: LastSky(checkedAt: observed, directionName: '南東', distanceKm: 42),
        );
      case 'home_nopermission':
        return const HomeState(mode: HomeMode.noPermission, locationOff: true, notificationsOff: true);
      default:
        return HomeState(
          mode: HomeMode.clouds,
          placeName: '滝沢市',
          spots: [SpotChip(_now, true)],
          selectedSpotId: 'now',
          clouds: [near],
          observedAt: observed,
          skyNow: sky,
          nearestCloud: nationwide,
          nationwideCount: 4,
          nationwideViews: [near, far],
        );
    }
  }

  /// 名前に合う画面。知らない名前なら null
  static Widget? build(String name) {
    if (!names.contains(name)) return null;
    if (name.startsWith('home_')) return HomeScreen(previewState: _state(name));
    if (name.startsWith('sheet_')) return _SheetLauncher(name);
    return switch (name) {
      'welcome' => const WelcomeScreen(),
      'intro' => const IntroScreen(fromSettings: true),
      'intro2' => const IntroScreen(fromSettings: true, initialPage: 1),
      'intro3' => const IntroScreen(fromSettings: true, initialPage: 2),
      'plus' => const PlusScreen(),
      'loading' => const LoadingView(),
      'finder' => FinderScreen(
          target: const FinderTarget(
              cloudId: null, bearingDeg: 135, distanceKm: 42, elevationDeg: 14, fists: 1.5, source: FinderSource.home)),
      _ => _SignedIn(name),
    };
  }
}

/// 設定・場所・記録など、ログインしたあとに中身を読む画面。先に匿名ログインしておく
class _SignedIn extends StatelessWidget {
  final String name;
  const _SignedIn(this.name);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: FirebaseAuth.instance.currentUser != null ? Future.value() : MemberService.ensureSignedIn(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        return switch (name) {
          'settings' => const SettingsScreen(),
          'places' => const PlacesScreen(),
          'data_source' => const DataSourceScreen(),
          _ => const RecordScreen(),
        };
      },
    );
  }
}

/// 下から出るシートを、画面の準備ができたらすぐ開く
class _SheetLauncher extends StatefulWidget {
  final String name;
  const _SheetLauncher(this.name);

  @override
  State<_SheetLauncher> createState() => _SheetLauncherState();
}

class _SheetLauncherState extends State<_SheetLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      switch (widget.name) {
        case 'sheet_whatsnew':
          await WhatsNewSheet.show(context);
        case 'sheet_always':
          await AlwaysAllowSheet.show(context, placeName: '滝沢市', onAllow: () async {});
        case 'sheet_quiet':
          await QuietHoursSheet.show(context, MemberSettings.defaultQuietHours);
        case 'sheet_addplace':
          await AddPlaceSheet.show(context, places: const [], maxPlaces: 1);
        case 'sheet_nationwide':
          await NationwideSheet.show(context, [
            PreviewScreens._cloud('n1', const LatLng(39.50, 141.40), PreviewScreens._takizawa),
            PreviewScreens._cloud('n2', const LatLng(38.10, 141.60), PreviewScreens._takizawa),
          ]);
        case 'sheet_calibrate':
          await CalibrateSheet.show(context, Stream.value(const Heading(10, 40)));
      }
    });
  }

  @override
  Widget build(BuildContext context) => const LoadingView();
}
