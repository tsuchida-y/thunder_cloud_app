import 'dart:convert';
import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../../utils/logger.dart';
import '../../utils/time_text.dart';

/// ウィジェットに渡す、1つの場所の空
class WidgetSpot {
  /// ホームの WatchSpot と同じ ID（'now' か 'place_緯度_経度'）
  final String id;

  /// 「現在地」「家」
  final String label;

  /// 「滝沢市」「盛岡市」
  final String? placeName;

  /// clouds / empty / night / offline / none
  final String mode;
  final String? direction;
  final double? bearingDeg;
  final int? km;
  final String? fists;

  const WidgetSpot({
    required this.id,
    required this.label,
    required this.placeName,
    required this.mode,
    this.direction,
    this.bearingDeg,
    this.km,
    this.fists,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'placeName': placeName ?? '',
        'mode': mode,
        'direction': direction ?? '',
        'bearingDeg': bearingDeg ?? -1,
        'km': km ?? -1,
        'fists': fists ?? '',
      };
}

/// ホーム画面のウィジェット（docs/design/Widget.html と 場所の見せ方_画面一覧.png、Plus の機能）に渡す中身
///
/// ホームが空を計算するたびに、見張っているすべての場所の空を JSON（キー spots）で書き、ウィジェットを描き直してもらう。
/// ウィジェットは、置くときに選んだ場所（ID）の分だけを出す。タップすると thundercloud://spot?id=… でアプリを開く。
/// - Android: android/app/src/main/kotlin/.../CloudWidget.kt と CloudWidgetConfigureActivity.kt
/// - iOS: ios/CloudWidget/CloudWidget.swift（Xcode で Widget Extension のターゲットを足して使う。docs/お願いしたい作業の手順.md）
class SkyWidget {
  SkyWidget._();

  /// iOS のアプリとウィジェットでデータを分け合う App Group（Xcode で両方のターゲットに付ける）
  static const String appGroupId = 'group.com.tsuchida.thundercloud';
  static const String _iosName = 'CloudWidget';
  static const List<String> _androidNames = [
    'io.github.tsuchida.thunder_cloud_app.CloudWidgetSmall',
    'io.github.tsuchida.thunder_cloud_app.CloudWidgetMedium',
  ];

  static String? _lastKey;

  static Future<void> update({required bool isPlus, required List<WidgetSpot> spots, DateTime? observedAt}) async {
    final values = <String, String>{
      'plus': isPlus ? '1' : '0',
      'time': observedAt == null ? '' : TimeText.clock(observedAt),
      'spots': jsonEncode([for (final spot in spots) spot.toJson()]),
    };
    final key = values.values.join('|');
    if (key == _lastKey) return;
    _lastKey = key;
    try {
      if (Platform.isIOS) await HomeWidget.setAppGroupId(appGroupId);
      for (final entry in values.entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }
      if (Platform.isIOS) {
        await HomeWidget.updateWidget(iOSName: _iosName);
      } else {
        for (final name in _androidNames) {
          await HomeWidget.updateWidget(qualifiedAndroidName: name);
        }
      }
    } catch (e) {
      // iOS でウィジェットのターゲットをまだ足していないときなど。アプリの動きには関係ない
      AppLogger.warning('ウィジェットを更新できませんでした: $e', tag: 'SkyWidget');
    }
  }

  /// ウィジェットをタップして開いたときの場所の ID（thundercloud://spot?id=…）
  static String? spotIdFrom(Uri? uri) {
    if (uri == null || uri.host != 'spot') return null;
    final id = uri.queryParameters['id'];
    return id == null || id.isEmpty ? null : id;
  }

  /// アプリを開いたウィジェットの場所（閉じていたアプリをウィジェットから開いたとき）
  static Future<String?> launchedSpotId() async {
    try {
      return spotIdFrom(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (_) {
      return null;
    }
  }

  /// アプリを開いたままウィジェットをタップしたとき
  static Stream<String> get clickedSpotIds =>
      HomeWidget.widgetClicked.map(spotIdFrom).where((id) => id != null).cast<String>();
}
