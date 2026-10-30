import 'package:flutter/material.dart';

import '../models/finder_target.dart';
import '../screens/finder/finder_screen.dart';
import '../screens/intro/intro_screen.dart';
import '../screens/plus/plus_screen.dart';
import '../screens/record/record_screen.dart';
import '../screens/settings/data_source_screen.dart';
import '../screens/settings/places_screen.dart';
import '../screens/settings/settings_screen.dart';

/// 画面の行き来
///
/// ホームを起点に、方角ガイド・設定・記録へ進む。下のタブは使わない。
/// 通知から開いたときは方角ガイドを直接開く。
class AppRoutes {
  AppRoutes._();

  static Future<void> openFinder(BuildContext context, FinderTarget target) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => FinderScreen(target: target)));

  static Future<void> openSettings(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  static Future<void> openRecord(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecordScreen()));

  static Future<void> openPlaces(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlacesScreen()));

  static Future<void> openPlus(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlusScreen()));

  static Future<void> openIntro(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IntroScreen(fromSettings: true)));

  static Future<void> openDataSource(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DataSourceScreen()));

  /// ホームまで戻る（写真を保存したあとなど）
  static void backToHome(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);
}
