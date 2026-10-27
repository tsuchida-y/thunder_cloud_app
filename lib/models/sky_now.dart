import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/sky_geometry.dart';
import '../utils/sun_times.dart';
import 'lat_lng.dart';

/// ホームの「いまの空」: 近くのアメダスのいまの観測（予想ではない）
///
/// サーバーが10分ごとに system/amedas_latest に置く観測から、見張っている場所にいちばん近い地点の値を選ぶ
/// （functions/modules/jma/nowcast_service.js の _saveAmedasLatest）。アプリは気象庁に直接行かない。
class SkyNow {
  /// 気温と日照は、この距離までの地点を使う（サーバーの AMEDAS.SUNSHINE_RADIUS_KM と同じ）
  static const double nearRadiusKm = 20;

  /// 視程は約150の気象台などだけなので、この距離までの地点を使う（サーバーの AMEDAS.VISIBILITY_RADIUS_KM と同じ）
  static const double visibilityRadiusKm = 40;

  /// 視程計はこれ以上を同じ値で出す
  static const double visibilityMaxKm = 20;

  final DateTime observedAt;
  final double? tempC;

  /// 前の1時間の日照時間（時間、0〜1）。太陽が低くて日照計が使えない時間は null
  final double? sun1h;

  /// 見通せる距離 (km)。近くに視程の地点がなければ null
  final double? visibilityKm;

  const SkyNow({required this.observedAt, this.tempC, this.sun1h, this.visibilityKm});

  /// 観測の中から、その場所の「いまの空」を作る。使える値が1つもなければ null
  static SkyNow? near(Map<String, dynamic>? data, LatLng point, DateTime now) {
    final observedAt = data?['observedAt'];
    final stations = data?['stations'];
    if (observedAt is! Timestamp || stations is! List) return null;

    double? nearest(String key, double radiusKm) {
      double? best;
      var bestKm = double.infinity;
      for (final s in stations) {
        if (s is! Map || s[key] is! num || s['la'] is! num || s['lo'] is! num) continue;
        final km = SkyGeometry.distanceKm(point, LatLng((s['la'] as num).toDouble(), (s['lo'] as num).toDouble()));
        if (km <= radiusKm && km < bestKm) {
          best = (s[key] as num).toDouble();
          bestKm = km;
        }
      }
      return best;
    }

    // 太陽が低いと、晴れていても日照なしになるので、前の1時間ずっと太陽が高かったときだけ日照を使う
    final hourAgo = now.subtract(const Duration(hours: 1));
    final sunHigh = SunTimes.isDaytime(now, point.latitude, point.longitude, altitudeDeg: SunTimes.sunshineMinDeg) &&
        SunTimes.isDaytime(hourAgo, point.latitude, point.longitude, altitudeDeg: SunTimes.sunshineMinDeg);
    final visibilityM = nearest('v', visibilityRadiusKm);
    final sky = SkyNow(
      observedAt: observedAt.toDate(),
      tempC: nearest('t', nearRadiusKm),
      sun1h: sunHigh ? nearest('s', nearRadiusKm) : null,
      visibilityKm: visibilityM == null ? null : visibilityM / 1000,
    );
    return sky.parts.isEmpty ? null : sky;
  }

  /// 「日が差しています」「気温18℃」「見通し20km以上」
  List<String> get parts => [
        if (sun1h != null)
          sun1h! >= 0.7
              ? '日が差しています'
              : sun1h! > 0
                  ? 'ときどき日が差しています'
                  : '日が差していません',
        if (tempC != null) '気温${tempC!.round()}℃',
        if (visibilityKm != null)
          visibilityKm! >= visibilityMaxKm ? '見通し20km以上' : '見通し約${visibilityKm!.round()}km',
      ];
}

/// ホームの「いちばん近い入道雲」（見える範囲の外。全国で見えている入道雲のうち、見張っている場所にいちばん近いもの）
class NationwideCloud {
  final String id;
  final LatLng center;
  final String directionName;
  final int distanceKm;

  /// 「那覇市」など。海の上などで分からなければ null
  final String? placeName;

  const NationwideCloud({
    required this.id,
    required this.center,
    required this.directionName,
    required this.distanceKm,
    this.placeName,
  });
}
