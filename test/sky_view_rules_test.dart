import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_cloud_app/models/lat_lng.dart';
import 'package:thunder_cloud_app/models/sky_cloud.dart';
import 'package:thunder_cloud_app/models/sky_verdict.dart';

/// ホームの「見えています」を、通知のルール（サーバーの notify_rules.js）とそろえる判定のテスト
void main() {
  const me = LatLng(39.735, 141.077);
  final seen = DateTime(2026, 11, 5, 9);

  // me から南東へ約25km・42km・75km（サーバーのテストと同じ位置）
  SkyCloud cloud(LatLng center, {double? topHeightKm, List<LatLng> edgePoints = const []}) => SkyCloud(
        id: 'c',
        center: center,
        firstSeenAt: seen,
        lastSeenAt: seen,
        isVisible: true,
        topHeightKm: topHeightKm,
        edgePoints: edgePoints,
      );
  const near = LatLng(39.576, 141.285);
  const far = LatLng(39.26, 141.70);

  test('見上げる角度が8°未満の雲は見えない雲とする（背の高い雲なら遠くても見える）', () {
    // 75km 先: 高さ7.2km は約5.5°、12km は約9°
    expect(cloud(far, topHeightKm: 7.2).viewFrom(me).isLookable(), isFalse);
    expect(cloud(far, topHeightKm: 12).viewFrom(me).isLookable(), isTrue);
    // 高さが分からない（12km として計算）なら見える
    expect(cloud(far).viewFrom(me).isLookable(), isTrue);
    // 同じ背の低い雲でも、25km 先なら角度が高いので見える
    expect(cloud(near, topHeightKm: 7.2).viewFrom(me).isLookable(), isTrue);
  });

  test('雲のふちが10kmより近い雲は見えない雲とする', () {
    // 中心は25km 先でも、ふちが me から 5km の所にある大きな雲
    final closeEdge = cloud(near, edgePoints: const [LatLng(39.735, 141.14), LatLng(39.57, 141.28)]);
    expect(closeEdge.viewFrom(me).nearestEdgeKm, lessThan(10));
    expect(closeEdge.viewFrom(me).isLookable(), isFalse);
    // ふちの点がなければ、中心までの距離で考える
    expect(cloud(near).viewFrom(me).nearestEdgeKm, closeTo(cloud(near).viewFrom(me).distanceKm, 0.001));
  });

  test('空のようすが一面の曇り・雨なら、雲があっても見えない雲とする。視程より遠い雲も見えない', () {
    final view = cloud(near, topHeightKm: 10).viewFrom(me); // 約25km
    expect(view.isLookable(verdict: const SkyVerdict(overcast: false, raining: false)), isTrue);
    expect(view.isLookable(verdict: const SkyVerdict(overcast: true, raining: false)), isFalse);
    expect(view.isLookable(verdict: const SkyVerdict(overcast: false, raining: true)), isFalse);
    expect(view.isLookable(verdict: const SkyVerdict(overcast: false, raining: false, visibilityKm: 12)), isFalse);
    expect(view.isLookable(verdict: const SkyVerdict(overcast: false, raining: false, visibilityKm: 30)), isTrue);
    // 空のようすが分からなければ、雲だけで決める
    expect(view.isLookable(), isTrue);
  });

  group('サーバーが書いた空のようす（member_server.skyNow）', () {
    final now = DateTime(2026, 11, 5, 9, 30);
    Map<String, dynamic> server(DateTime updatedAt, List<Map<String, dynamic>> points) => {
          'skyNow': {'updatedAt': Timestamp.fromDate(updatedAt), 'points': points},
        };

    test('見張る場所の位置（小数第2位に丸める）で引ける', () {
      final verdicts = SkyVerdicts.fromServer(server(now.subtract(const Duration(minutes: 5)), [
        {'key': '39.74,141.08', 'overcast': true, 'raining': false, 'visibilityKm': null},
        {'key': '35.68,139.76', 'overcast': false, 'raining': true, 'visibilityKm': 8.5},
      ]));
      // 39.735 は ×100 を四捨五入して 39.74（サーバーと同じ丸め方）
      final here = verdicts!.at(me, now)!;
      expect(here.overcast, isTrue);
      expect(here.isOpen, isFalse);
      final tokyo = verdicts.at(const LatLng(35.68, 139.76), now)!;
      expect(tokyo.raining, isTrue);
      expect(tokyo.visibilityKm, 8.5);
      // 結果にない場所は null
      expect(verdicts.at(const LatLng(43.06, 141.35), now), isNull);
    });

    test('45分より古い結果は使わない。ないとき、形が違うときは null', () {
      final points = [
        {'key': '39.74,141.08', 'overcast': true, 'raining': false}
      ];
      expect(SkyVerdicts.fromServer(server(now.subtract(const Duration(minutes: 44)), points))!.at(me, now), isNotNull);
      expect(SkyVerdicts.fromServer(server(now.subtract(const Duration(minutes: 46)), points))!.at(me, now), isNull);
      expect(SkyVerdicts.fromServer(null), isNull);
      expect(SkyVerdicts.fromServer({'isPlus': true}), isNull);
      expect(SkyVerdicts.fromServer({'skyNow': {'updatedAt': 'x', 'points': []}}), isNull);
    });

    test('位置のキーは、サーバーと同じ丸め方', () {
      expect(SkyVerdicts.keyOf(me), '39.74,141.08');
      expect(SkyVerdicts.keyOf(const LatLng(39.7349, 141.0751)), '39.73,141.08');
    });
  });
}
