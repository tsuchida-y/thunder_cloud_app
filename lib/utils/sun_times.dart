import 'dart:math' as math;

/// 日の出・日の入りの時刻
///
/// サーバーの functions/modules/geo/sun_times.js と同じ、米国海洋大気庁 (NOAA) の計算式。
/// 誤差は1〜2分程度。太陽の中心が地平線の下 0.833° になる時刻を求める。
class SunTimes {
  final DateTime? sunrise;
  final DateTime? sunset;

  const SunTimes(this.sunrise, this.sunset);

  static const double _sunAltitudeDeg = -0.833;
  static const int _dayMs = 24 * 60 * 60 * 1000;

  static double _toRad(double deg) => deg * math.pi / 180;
  static double _toDeg(double rad) => rad * 180 / math.pi;

  /// その日（UTC の日付）の日の出・日の入り。白夜・極夜のときは null
  static SunTimes forUtcDate(DateTime date, double latitude, double longitude) {
    final utc = date.toUtc();
    final dayStart = DateTime.utc(utc.year, utc.month, utc.day).millisecondsSinceEpoch;
    final julianDay = dayStart / _dayMs + 2440587.5;
    // その日の正午 (UTC) を指す、2000年1月1日正午からの日数
    final n = (julianDay - 2451545.0 + 0.0008).ceilToDouble();

    final meanSolarNoon = n - longitude / 360;
    final meanAnomaly = (357.5291 + 0.98560028 * meanSolarNoon) % 360;
    final center = 1.9148 * math.sin(_toRad(meanAnomaly)) +
        0.02 * math.sin(_toRad(2 * meanAnomaly)) +
        0.0003 * math.sin(_toRad(3 * meanAnomaly));
    final eclipticLongitude = (meanAnomaly + center + 180 + 102.9372) % 360;
    final solarTransit = 2451545.0 +
        meanSolarNoon +
        0.0053 * math.sin(_toRad(meanAnomaly)) -
        0.0069 * math.sin(_toRad(2 * eclipticLongitude));
    final declination = math.asin(math.sin(_toRad(eclipticLongitude)) * math.sin(_toRad(23.4397)));

    final cosHourAngle = (math.sin(_toRad(_sunAltitudeDeg)) - math.sin(_toRad(latitude)) * math.sin(declination)) /
        (math.cos(_toRad(latitude)) * math.cos(declination));
    if (cosHourAngle < -1 || cosHourAngle > 1) return const SunTimes(null, null);

    final hourAngle = _toDeg(math.acos(cosHourAngle));
    DateTime toDate(double jd) =>
        DateTime.fromMillisecondsSinceEpoch(((jd - 2440587.5) * _dayMs).round(), isUtc: true);
    return SunTimes(toDate(solarTransit - hourAngle / 360), toDate(solarTransit + hourAngle / 360));
  }

  /// いま、その場所が昼（日の出から日の入りまで）かどうか
  static bool isDaytime(DateTime now, double latitude, double longitude) {
    for (final offset in [-1, 0, 1]) {
      final times = forUtcDate(now.add(Duration(days: offset)), latitude, longitude);
      if (times.sunrise != null &&
          times.sunset != null &&
          !times.sunrise!.isAfter(now) &&
          now.isBefore(times.sunset!)) {
        return true;
      }
    }
    return false;
  }

  /// いまより後で、いちばん近い日の出の時刻（夜の画面の「再開時刻」用）
  static DateTime? nextSunrise(DateTime now, double latitude, double longitude) {
    for (final offset in [-1, 0, 1, 2]) {
      final sunrise = forUtcDate(now.add(Duration(days: offset)), latitude, longitude).sunrise;
      if (sunrise != null && sunrise.isAfter(now)) return sunrise;
    }
    return null;
  }

  /// いまを含む日（端末の日付）の日の出と日の入り（夜の画面の「きょう見えた入道雲」用）
  static SunTimes forLocalDay(DateTime now, double latitude, double longitude) {
    final local = now.toLocal();
    DateTime? sunrise;
    DateTime? sunset;
    for (final offset in [-1, 0, 1]) {
      final times = forUtcDate(now.add(Duration(days: offset)), latitude, longitude);
      bool sameDay(DateTime? t) {
        final l = t?.toLocal();
        return l != null && l.year == local.year && l.month == local.month && l.day == local.day;
      }

      if (sameDay(times.sunrise)) sunrise = times.sunrise;
      if (sameDay(times.sunset)) sunset = times.sunset;
    }
    return SunTimes(sunrise, sunset);
  }
}
