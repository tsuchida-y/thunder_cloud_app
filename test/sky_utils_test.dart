import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_cloud_app/models/finder_target.dart';
import 'package:thunder_cloud_app/models/lat_lng.dart';
import 'package:thunder_cloud_app/screens/finder/widgets/finder_drawings.dart';
import 'package:thunder_cloud_app/utils/sky_geometry.dart';
import 'package:thunder_cloud_app/utils/sun_times.dart';
import 'package:thunder_cloud_app/utils/time_text.dart';

// サーバー（functions/test）と同じ値になることを確かめる
void main() {
  group('SkyGeometry', () {
    const morioka = LatLng(39.70, 141.15);

    test('真東に約42km先の雲は、東・こぶし1つ半', () {
      const cloud = LatLng(39.70, 141.64);
      final d = SkyGeometry.distanceKm(morioka, cloud);
      expect(d, closeTo(42, 1));
      expect(SkyGeometry.directionName(SkyGeometry.bearingDeg(morioka, cloud)), '東');
      final fists = SkyGeometry.fistsFromElevation(SkyGeometry.elevationDeg(d));
      expect(fists, 1.5);
      expect(SkyGeometry.fistsLabel(fists), 'こぶし1つ半');
    });

    test('8方位とこぶしの数の書き方', () {
      expect(SkyGeometry.directionName(135), '南東');
      expect(SkyGeometry.directionName(350), '北');
      expect(SkyGeometry.fistsLabel(0.5), 'こぶし半分');
      expect(SkyGeometry.fistsLabel(2), 'こぶし2つ');
      expect(SkyGeometry.fistsFromElevation(1), 0.5);
    });

    test('ひまわりで見積もった高さがあればそれで見上げる高さを出す（サーバーと同じ約13.4°）', () {
      expect(SkyGeometry.elevationDeg(25.24, topKm: 6), closeTo(13.4, 0.1));
      expect(SkyGeometry.elevationDeg(25.24), SkyGeometry.elevationDeg(25.24, topKm: 12));
    });
  });

  group('SunTimes', () {
    // 国立天文台の東京 2026-10-20: 日の出 5:51、日の入り 17:00
    const lat = 35.6895, lng = 139.6917;
    final day = DateTime.utc(2026, 10, 20, 3);

    test('東京の日の出・日の入りが国立天文台の値と2分以内', () {
      final jst = DateTime.utc(2026, 10, 20).subtract(const Duration(hours: 9));
      final times = SunTimes.forUtcDate(day, lat, lng);
      expect(times.sunrise!.difference(jst.add(const Duration(hours: 5, minutes: 51))).inMinutes.abs(), lessThanOrEqualTo(2));
      expect(times.sunset!.difference(jst.add(const Duration(hours: 17))).inMinutes.abs(), lessThanOrEqualTo(2));
    });

    test('昼と夜、次の日の出', () {
      expect(SunTimes.isDaytime(DateTime.utc(2026, 10, 20, 3), lat, lng), isTrue); // 12時
      expect(SunTimes.isDaytime(DateTime.utc(2026, 10, 20, 12), lat, lng), isFalse); // 21時
      // 夜は市民薄明の終わりから（日の入り 17:00 のあとも 17:26 ごろまでは明るい）
      expect(SunTimes.isDaytime(DateTime.utc(2026, 10, 20, 8, 10), lat, lng), isTrue); // 17:10
      expect(SunTimes.isDaytime(DateTime.utc(2026, 10, 20, 8, 40), lat, lng), isFalse); // 17:40
      final next = SunTimes.nextSunrise(DateTime.utc(2026, 10, 20, 12), lat, lng)!;
      expect(next.isAfter(DateTime.utc(2026, 10, 20, 20)), isTrue);
      expect(next.isBefore(DateTime.utc(2026, 10, 20, 21)), isTrue);
    });
  });

  group('TimeText', () {
    test('何分前', () {
      final now = DateTime(2026, 10, 20, 15, 0);
      expect(TimeText.ago(now.subtract(const Duration(seconds: 20)), now), '1分前');
      expect(TimeText.ago(now.subtract(const Duration(minutes: 3)), now), '3分前');
      expect(TimeText.ago(now.subtract(const Duration(minutes: 125)), now), '2時間前');
    });

    test('再開の時刻', () {
      final sunrise = DateTime(2026, 10, 21, 5, 10);
      expect(TimeText.morning(sunrise, DateTime(2026, 10, 20, 21)), 'あすの朝 5:10 ごろ');
      expect(TimeText.morning(sunrise, DateTime(2026, 10, 21, 1)), '朝 5:10 ごろ');
    });
  });

  group('方角ガイド', () {
    test('回る角度は -180〜180（正なら右）', () {
      expect(angleDiff(100, 135), 35);
      expect(angleDiff(350, 10), 20);
      expect(angleDiff(10, 350), -20);
      expect(angleDiff(0, 180).abs(), 180);
    });

    test('通知のデータから案内する雲を作る', () {
      final target = FinderTarget.fromNotification({
        'type': 'cloud_appeared',
        'cloudId': 'c1',
        'bearingDeg': '135.0',
        'distanceKm': '42.0',
        'elevationDeg': '15.9',
        'fists': '1.5',
      })!;
      expect(target.cloudId, 'c1');
      expect(target.directionName, '南東');
      expect(target.fistsLabel, 'こぶし1つ半');
      expect(target.source, FinderSource.notification);
      expect(FinderTarget.fromNotification({'type': 'other'}), isNull);
    });
  });
}
