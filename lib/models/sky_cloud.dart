import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/sky_geometry.dart';
import 'lat_lng.dart';
import 'sky_verdict.dart';

/// 見える範囲の決まり（サーバーの NOTIFY_RULES と同じ値）
class SkyRules {
  SkyRules._();

  static const double freeRangeKm = 30;
  static const double plusRangeKm = 90;

  /// これより遠い雲は「見えるかもしれません」
  static const double maybeVisibleKm = 60;

  /// 雲のてっぺんを見上げる角度がこれより低い雲は、水平線のすぐ上の小さなふくらみで、山やもやに隠れて見えない
  /// （サーバーの MIN_ELEVATION_DEG と同じ。2026-11-02）
  static const double minElevationDeg = 8;

  /// 雲のふち（いちばん近い所）がこれより近いと、真下か近すぎて形が見えない（サーバーの MIN_DISTANCE_KM と同じ）
  static const double minEdgeKm = 10;

  /// 見張れる登録済みの場所の数（いまいる場所は別）。無料でも1か所（2026-10-27）
  static const int freeMaxPlaces = 1;
  static const int plusMaxPlaces = 3;

  static int maxPlaces({required bool isPlus}) => isPlus ? plusMaxPlaces : freeMaxPlaces;

  /// Plus なら設定の範囲（90km まで）、そうでなければ 30km
  static double rangeKm({required bool isPlus, num? settingKm}) {
    if (!isPlus) return freeRangeKm;
    final km = settingKm?.toDouble() ?? plusRangeKm;
    return km.clamp(freeRangeKm, plusRangeKm);
  }
}

/// サーバーが気象庁のナウキャストから作った雲（Firestore の clouds）
class SkyCloud {
  final String id;
  final LatLng center;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final bool isVisible;

  /// ひまわりで見積もったてっぺんの高さ (km)。分からなければ null（12km として計算する）
  final double? topHeightKm;

  /// 雲のふちの点（いちばん近い所までの距離に使う）。なければ空（中心だけで考える）
  final List<LatLng> edgePoints;

  const SkyCloud({
    required this.id,
    required this.center,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.isVisible,
    this.topHeightKm,
    this.edgePoints = const [],
  });

  static SkyCloud? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final center = data?['center'];
    final first = data?['firstSeenAt'];
    final last = data?['lastSeenAt'];
    if (center is! Map || first is! Timestamp || last is! Timestamp) return null;
    final lat = center['latitude'];
    final lng = center['longitude'];
    if (lat is! num || lng is! num) return null;
    return SkyCloud(
      id: doc.id,
      center: LatLng(lat.toDouble(), lng.toDouble()),
      firstSeenAt: first.toDate(),
      lastSeenAt: last.toDate(),
      isVisible: data?['isVisible'] == true,
      topHeightKm: (data?['topHeightKm'] as num?)?.toDouble(),
      edgePoints: _edgePointsOf(data?['edgePoints']),
    );
  }

  static List<LatLng> _edgePointsOf(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final p in raw)
        if (p is Map && p['latitude'] is num && p['longitude'] is num)
          LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()),
    ];
  }

  /// ある場所から見たときの見え方
  CloudView viewFrom(LatLng point) => CloudView(this, point);
}

/// ある場所から見た雲（方角・距離・見上げる高さ）
class CloudView {
  final SkyCloud cloud;
  final double distanceKm;
  final double bearingDeg;
  final String directionName;
  final double elevationDeg;
  final double fists;

  /// 雲のふち（いちばん近い所）までの距離。ふちの点がなければ中心までの距離
  final double nearestEdgeKm;

  CloudView(this.cloud, LatLng point)
      : nearestEdgeKm = cloud.edgePoints.isEmpty
            ? SkyGeometry.distanceKm(point, cloud.center)
            : cloud.edgePoints.map((e) => SkyGeometry.distanceKm(point, e)).reduce((a, b) => a < b ? a : b),
        distanceKm = SkyGeometry.distanceKm(point, cloud.center),
        bearingDeg = SkyGeometry.bearingDeg(point, cloud.center),
        directionName = SkyGeometry.directionName(SkyGeometry.bearingDeg(point, cloud.center)),
        elevationDeg = SkyGeometry.elevationDeg(SkyGeometry.distanceKm(point, cloud.center),
            topKm: cloud.topHeightKm ?? SkyGeometry.cloudTopKm),
        fists = SkyGeometry.fistsFromElevation(SkyGeometry.elevationDeg(SkyGeometry.distanceKm(point, cloud.center),
            topKm: cloud.topHeightKm ?? SkyGeometry.cloudTopKm));

  String get fistsLabel => SkyGeometry.fistsLabel(fists);

  /// 60km より遠いので「見えるかもしれません」
  bool get maybeVisible => distanceKm > SkyRules.maybeVisibleKm;

  /// 通知のルールと同じ、見える雲か（サーバーの notify_rules.js の雲ごとの条件と、見張る場所の空のようす）
  ///
  /// - 一面の曇り・雨の場所では、入道雲は見えない
  /// - 視程より遠い雲は見えない
  /// - ふちが10kmより近い雲は、近すぎて形が見えない
  /// - てっぺんを見上げる角度が8°より低い雲は、山やもやに隠れて見えない
  /// 空のようす（[verdict]）が分からないときは、雲だけで決める。
  bool isLookable({SkyVerdict? verdict}) {
    if (verdict != null) {
      if (!verdict.isOpen) return false;
      final visibility = verdict.visibilityKm;
      if (visibility != null && distanceKm > visibility) return false;
    }
    if (nearestEdgeKm < SkyRules.minEdgeKm) return false;
    return elevationDeg >= SkyRules.minElevationDeg;
  }

  int get roundedKm => distanceKm.round();
}
