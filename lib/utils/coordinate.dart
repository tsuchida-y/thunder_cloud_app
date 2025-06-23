import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/app_constants.dart';

/// 座標関連のユーティリティ関数
class Coordinate {
  /// 2点間の距離を計算（ハヴァサイン公式）
  ///
  /// [point1] 地点1の座標
  /// [point2] 地点2の座標
  /// 戻り値: 距離（km）
  static double calculateDistance(LatLng point1, LatLng point2) {
    final double lat1Rad = _degreesToRadians(point1.latitude);
    final double lat2Rad = _degreesToRadians(point2.latitude);
    final double deltaLatRad = _degreesToRadians(point2.latitude - point1.latitude);
    final double deltaLonRad = _degreesToRadians(point2.longitude - point1.longitude);

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return AppConstants.earthRadiusKm * c;
  }

  /// 度をラジアンに変換
  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}