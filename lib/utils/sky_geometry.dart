import 'dart:math' as math;

import '../models/lat_lng.dart';

/// 利用者から見た雲の方角・距離・見上げる高さ
///
/// サーバーの functions/modules/geo/sky_geometry.js と同じ計算。通知の文とホームの表示がずれないよう、
/// どちらかを変えるときはもう一方も変える。
///
/// - 方角は本当の北から時計回りの角度（0〜360°）。8方位の名前（北・北東…）も返す
/// - 見上げる高さは、雲のてっぺんを 12,000m と仮定して距離から求める（42km 先なら約16°）
/// - 腕を伸ばしたこぶし1つ ≒ 10° として、こぶしの数（0.5 刻み）で表す
class SkyGeometry {
  SkyGeometry._();

  static const double earthRadiusKm = 6371;
  static const double cloudTopKm = 12;
  static const double degreesPerFist = 10;
  static const List<String> directionNames = ['北', '北東', '東', '南東', '南', '南西', '西', '北西'];

  static double _toRad(double deg) => deg * math.pi / 180;
  static double _toDeg(double rad) => rad * 180 / math.pi;

  /// 2点間の距離 (km)
  static double distanceKm(LatLng from, LatLng to) {
    final dLat = _toRad(to.latitude - from.latitude);
    final dLon = _toRad(to.longitude - from.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(from.latitude)) * math.cos(_toRad(to.latitude)) * math.pow(math.sin(dLon / 2), 2);
    return 2 * earthRadiusKm * math.asin(math.sqrt(h));
  }

  /// from から見た to の方角（本当の北から時計回り、0〜360°）
  static double bearingDeg(LatLng from, LatLng to) {
    final lat1 = _toRad(from.latitude);
    final lat2 = _toRad(to.latitude);
    final dLon = _toRad(to.longitude - from.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (_toDeg(math.atan2(y, x)) + 360) % 360;
  }

  /// 角度を8方位の名前にする
  static String directionName(double bearing) => directionNames[(bearing / 45).round() % 8];

  /// 雲のてっぺんを見上げる角度（°）
  static double elevationDeg(double distance) {
    if (distance <= 0) return 90;
    return _toDeg(math.atan(cloudTopKm / distance));
  }

  /// 見上げる角度をこぶしの数（0.5 刻み、最低 0.5）にする
  static double fistsFromElevation(double elevation) =>
      math.max(0.5, ((elevation / degreesPerFist) * 2).round() / 2);

  /// こぶしの数を文章にする（1.5 → 「こぶし1つ半」）
  static String fistsLabel(double fists) {
    final whole = fists.floor();
    final half = fists - whole >= 0.5;
    if (whole == 0) return 'こぶし半分';
    return 'こぶし$wholeつ${half ? '半' : ''}';
  }
}
