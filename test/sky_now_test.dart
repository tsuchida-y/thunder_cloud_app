import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_cloud_app/models/lat_lng.dart';
import 'package:thunder_cloud_app/models/sky_now.dart';

// サーバーの functions/test/sky_observations.test.js と同じ決まりになることを確かめる
void main() {
  const morioka = LatLng(39.70, 141.15);
  final observedAt = DateTime.utc(2026, 8, 12, 3, 20);
  Map<String, dynamic> doc(List<Map<String, dynamic>> stations) =>
      {'observedAt': Timestamp.fromDate(observedAt), 'stations': stations};

  // 盛岡の夏の昼（太陽は十分高い）と、日の入りの少し前（太陽が低い）
  final summerNoon = DateTime.utc(2026, 8, 12, 3, 30);
  final summerEvening = DateTime.utc(2026, 8, 12, 9, 0);

  test('近くの地点の日照・気温・視程を一行にする', () {
    final sky = SkyNow.near(doc([
      {'la': 39.72, 'lo': 141.14, 't': 28.4, 's': 0.8},
      {'la': 39.70, 'lo': 141.17, 'v': 20000},
    ]), morioka, summerNoon)!;
    expect(sky.parts, ['日が差しています', '気温28℃', '見通し20km以上']);
  });

  test('日照の量で言い方を変え、視程が短いときは距離を出す', () {
    expect(SkyNow.near(doc([{'la': 39.72, 'lo': 141.14, 's': 0.3}]), morioka, summerNoon)!.parts, ['ときどき日が差しています']);
    expect(SkyNow.near(doc([{'la': 39.72, 'lo': 141.14, 's': 0}]), morioka, summerNoon)!.parts, ['日が差していません']);
    expect(SkyNow.near(doc([{'la': 39.72, 'lo': 141.14, 'v': 12300}]), morioka, summerNoon)!.parts, ['見通し約12km']);
  });

  test('太陽が低い時間は日照を出さず、遠い地点しかなければ何も出さない', () {
    expect(SkyNow.near(doc([{'la': 39.72, 'lo': 141.14, 's': 0, 't': 25.0}]), morioka, summerEvening)!.parts, ['気温25℃']);
    expect(SkyNow.near(doc([{'la': 35.0, 'lo': 139.0, 't': 20.0}]), morioka, summerNoon), isNull);
    expect(SkyNow.near(null, morioka, summerNoon), isNull);
  });
}
