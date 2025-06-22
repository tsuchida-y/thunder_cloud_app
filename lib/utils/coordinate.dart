import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/app_constants.dart';

/// 座標計算に関するユーティリティクラス
class CoordinateUtils {

  /// 指定した方向と距離から新しい座標を計算
  static LatLng calculateDirectionCoordinates(String direction, double lat, double lon, double distance) {
    double bearing;

    switch (direction) {
      case 'north':
        bearing = 0.0;
        break;
      case 'south':
        bearing = 180.0;
        break;
      case 'east':
        bearing = 90.0;
        break;
      case 'west':
        bearing = 270.0;
        break;
      default:
        bearing = 0.0;
    }

    final double bearingRad = bearing * (math.pi / 180.0);
    final double latRad = lat * (math.pi / 180.0);
    final double lonRad = lon * (math.pi / 180.0);

    final double newLatRad = math.asin(
      math.sin(latRad) * math.cos(distance / AppConstants.earthRadiusKm) +
      math.cos(latRad) * math.sin(distance / AppConstants.earthRadiusKm) * math.cos(bearingRad)
    );

    final double newLonRad = lonRad + math.atan2(
      math.sin(bearingRad) * math.sin(distance / AppConstants.earthRadiusKm) * math.cos(latRad),
      math.cos(distance / AppConstants.earthRadiusKm) - math.sin(latRad) * math.sin(newLatRad)
    );

    return LatLng(
      newLatRad * (180.0 / math.pi),
      newLonRad * (180.0 / math.pi),
    );
  }

  /// 2つの座標間の距離を計算（km）
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    final double lat1Rad = lat1 * (math.pi / 180.0);
    final double lat2Rad = lat2 * (math.pi / 180.0);
    final double deltaLatRad = (lat2 - lat1) * (math.pi / 180.0);
    final double deltaLonRad = (lon2 - lon1) * (math.pi / 180.0);

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return AppConstants.earthRadiusKm * c;
  }
}