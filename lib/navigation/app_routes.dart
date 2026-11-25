import 'package:flutter/material.dart';

import '../models/finder_target.dart';
import '../screens/finder/finder_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/intro/intro_screen.dart';
import '../screens/plus/plus_screen.dart';
import '../screens/record/record_screen.dart';
import '../screens/settings/data_source_screen.dart';
import '../screens/settings/places_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../services/analytics/analytics_service.dart';

/// 画面の行き来
///
/// ホームを起点に、方角ガイド・設定・記録へ進む。下のタブは使わない。
/// 通知から開いたときは方角ガイドを直接開く。
class AppRoutes {
  AppRoutes._();

  static Future<void> openFinder(BuildContext context, FinderTarget target) {
    AnalyticsService.finderOpened(target.source.name);
    return Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'finder'), builder: (_) => FinderScreen(target: target)));
  }

  static Future<void> openSettings(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'settings'), builder: (_) => const SettingsScreen()));

  static Future<void> openRecord(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'record'), builder: (_) => const RecordScreen()));

  static Future<void> openPlaces(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'places'), builder: (_) => const PlacesScreen()));

  /// [source] はどこから開いたか（計測用。settings_manage / settings_banner / settings_range / home_add_place / places_note）
  static Future<void> openPlus(BuildContext context, {required String source}) {
    AnalyticsService.plusViewed(source);
    return Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'plus'), builder: (_) => const PlusScreen()));
  }

  static Future<void> openIntro(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'intro_from_settings'), builder: (_) => const IntroScreen(fromSettings: true)));

  static Future<void> openDataSource(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'data_source'), builder: (_) => const DataSourceScreen()));

  /// 画面を全部閉じて、ホームを新しく開く（データを削除したあとなど、新しい利用者として始め直すとき）
  static Future<void> restartAtHome(BuildContext context) =>
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(settings: const RouteSettings(name: 'home'), builder: (_) => const HomeScreen()), (route) => false);

  /// ホームまで戻る（写真を保存したあとなど）
  static void backToHome(BuildContext context) => Navigator.of(context).popUntil((route) => route.isFirst);
}
