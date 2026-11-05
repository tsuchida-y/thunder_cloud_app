import 'package:cloud_firestore/cloud_firestore.dart';

import 'lat_lng.dart';

/// 見張る場所の空のようす（サーバーが判定した結果。member_server/{uid}.skyNow の1か所分）
///
/// サーバーの notify_rules.js と同じ判定の、見張る場所で決まる部分（一面の曇り、雨、視程）。
/// ホームの「見えています」を、通知のルールとそろえるために使う。
class SkyVerdict {
  /// 見張る場所のまわりが、一面の曇り
  final bool overcast;

  /// 見張る場所でいま雨が降っている
  final bool raining;

  /// 見通せる距離（km）。制限がなければ null
  final double? visibilityKm;

  const SkyVerdict({required this.overcast, required this.raining, this.visibilityKm});

  /// 入道雲が見える空か（曇りでも雨でもない）
  bool get isOpen => !overcast && !raining;
}

/// サーバーが書いた、見張る場所ごとの空のようす（member_server/{uid}.skyNow）
///
/// ホームの「いまの空」（アメダスの観測。sky_now.dart の SkyNow）とは別のもの。
class SkyVerdicts {
  /// サーバーはこの間隔（30分）で書き直す。これより古い結果は使わない（余裕を見て45分）
  static const Duration maxAge = Duration(minutes: 45);

  final DateTime updatedAt;
  final Map<String, SkyVerdict> _points;

  const SkyVerdicts(this.updatedAt, this._points);

  /// 見張る場所の位置を小数第2位に丸めた文字列（サーバーの key と同じ丸め方: ×100 を四捨五入して÷100）
  static String keyOf(LatLng point) {
    String round2(double v) => ((v * 100).roundToDouble() / 100).toStringAsFixed(2);
    return '${round2(point.latitude)},${round2(point.longitude)}';
  }

  /// member_server のドキュメントから読む。ないとき、形が違うときは null
  static SkyVerdicts? fromServer(Map<String, dynamic>? server) {
    final raw = server?['skyNow'];
    if (raw is! Map) return null;
    final updatedAt = raw['updatedAt'];
    final points = raw['points'];
    if (updatedAt is! Timestamp || points is! List) return null;
    final map = <String, SkyVerdict>{};
    for (final p in points) {
      if (p is! Map || p['key'] is! String) continue;
      map[p['key'] as String] = SkyVerdict(
        overcast: p['overcast'] == true,
        raining: p['raining'] == true,
        visibilityKm: (p['visibilityKm'] as num?)?.toDouble(),
      );
    }
    return SkyVerdicts(updatedAt.toDate(), map);
  }

  /// その場所の空のようす。結果が古いとき、その場所の結果がないときは null（そのときは、雲だけで決める）
  SkyVerdict? at(LatLng point, DateTime now) {
    if (now.difference(updatedAt) > maxAge) return null;
    return _points[keyOf(point)];
  }
}
