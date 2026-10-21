import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../../utils/logger.dart';
import '../../utils/time_text.dart';

/// ホーム画面のウィジェット（docs/design/Widget.html、Plus の機能）に渡す中身
///
/// ホームが空を計算するたびに書き、ウィジェットを描き直してもらう。
/// - Android: android/app/src/main/kotlin/.../CloudWidget.kt
/// - iOS: ios/CloudWidget/（Xcode で Widget Extension のターゲットを足して使う。docs/残りの作業と確認事項.md）
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

  /// [mode] は clouds / empty / night / offline / none
  static Future<void> update({
    required bool isPlus,
    required String mode,
    String? direction,
    int? km,
    String? fists,
    String? place,
    DateTime? observedAt,
  }) async {
    final time = observedAt == null ? '' : TimeText.clock(observedAt);
    final values = <String, String>{
      'plus': isPlus ? '1' : '0',
      'mode': mode,
      'direction': direction ?? '',
      'km': km?.toString() ?? '',
      'fists': fists ?? '',
      'place': place ?? '',
      'time': time,
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
}
