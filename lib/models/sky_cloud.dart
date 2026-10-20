import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/sky_geometry.dart';
import 'lat_lng.dart';

/// 見える範囲の決まり（サーバーの NOTIFY_RULES と同じ値）
class SkyRules {
  SkyRules._();

  static const double freeRangeKm = 30;
  static const double plusRangeKm = 90;

  /// これより遠い雲は「見えるかもしれません」
  static const double maybeVisibleKm = 60;

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

  const SkyCloud({
    required this.id,
    required this.center,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.isVisible,
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
    );
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
  final double fists;

  CloudView(this.cloud, LatLng point)
      : distanceKm = SkyGeometry.distanceKm(point, cloud.center),
        bearingDeg = SkyGeometry.bearingDeg(point, cloud.center),
        directionName = SkyGeometry.directionName(SkyGeometry.bearingDeg(point, cloud.center)),
        fists = SkyGeometry.fistsFromElevation(SkyGeometry.elevationDeg(SkyGeometry.distanceKm(point, cloud.center)));

  String get fistsLabel => SkyGeometry.fistsLabel(fists);

  /// 60km より遠いので「見えるかもしれません」
  bool get maybeVisible => distanceKm > SkyRules.maybeVisibleKm;

  int get roundedKm => distanceKm.round();
}
