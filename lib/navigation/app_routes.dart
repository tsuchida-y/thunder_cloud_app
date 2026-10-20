import 'package:flutter/material.dart';

import '../screens/finder/finder_screen.dart';
import '../screens/record/record_screen.dart';
import '../screens/settings/settings_screen.dart';

/// 画面の行き来
///
/// ホームを起点に、方角ガイド・設定・記録へ進む。下のタブは使わない。
/// 通知から開いたときは方角ガイドを直接開く（ステップ5）。
class AppRoutes {
  AppRoutes._();

  static Future<void> openFinder(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FinderScreen()));

  static Future<void> openSettings(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  static Future<void> openRecord(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecordScreen()));

  /// ホームまで戻る（写真を保存したあとなど）
  static void backToHome(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);
}
