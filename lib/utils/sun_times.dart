import 'dart:math' as math;

/// 日の出・日の入りの時刻と、昼か夜か
///
/// サーバーの functions/modules/geo/sun_times.js と同じ、米国海洋大気庁 (NOAA) の計算式。誤差は1〜2分程度。
/// 日の出・日の入りは、太陽の中心が地平線の下 0.833° になる時刻。
///
/// 「夜（見張りを休む）」は、日の入りではなく、空が暗くなる市民薄明の終わり（太陽が地平線の下 6°）からにする。
/// 日の入りのあとも30分ほどは空が明るく、入道雲も見えるため（2026-10-22 tsuchida さん決定）。朝も同じ。
class SunTimes {
  final DateTime? sunrise;
  final DateTime? sunset;

  const SunTimes(this.sunrise, this.sunset);

  /// 日の出・日の入り
  static const double sunriseAltitudeDeg = -0.833;

  /// 市民薄明のはじまり・終わり（これより太陽が低いと「夜」）
  static const double civilTwilightDeg = -6;
  static const int _dayMs = 24 * 60 * 60 * 1000;

  static double _toRad(double deg) => deg * math.pi / 180;
  static double _toDeg(double rad) => rad * 180 / math.pi;

  /// その日（UTC の日付）の日の出・日の入り。白夜・極夜のときは null
  static SunTimes forUtcDate(DateTime date, double latitude, double longitude, {double altitudeDeg = sunriseAltitudeDeg}) {
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

    final cosHourAngle = (math.sin(_toRad(altitudeDeg)) - math.sin(_toRad(latitude)) * math.sin(declination)) /
        (math.cos(_toRad(latitude)) * math.cos(declination));
    if (cosHourAngle < -1 || cosHourAngle > 1) return const SunTimes(null, null);

    final hourAngle = _toDeg(math.acos(cosHourAngle));
    DateTime toDate(double jd) =>
        DateTime.fromMillisecondsSinceEpoch(((jd - 2440587.5) * _dayMs).round(), isUtc: true);
    return SunTimes(toDate(solarTransit - hourAngle / 360), toDate(solarTransit + hourAngle / 360));
  }

  /// 太陽がこれより低いと、朝や夕方の空として背景の色を変える（ホームの空の色）
  static const double lowSunDeg = 10;

  /// 太陽がこれより低いと、晴れていても日照計が日照なしになる（サーバーの AMEDAS.SUNSHINE_MIN_SUN_ALTITUDE_DEG と同じ）
  static const double sunshineMinDeg = 15;

  /// いま、その場所が昼（市民薄明のはじまりから終わりまで。空が明るいあいだ）かどうか
  ///
  /// altitudeDeg を渡すと、太陽がその高さより上にあるかを返す。
  static bool isDaytime(DateTime now, double latitude, double longitude, {double altitudeDeg = civilTwilightDeg}) {
    for (final offset in [-1, 0, 1]) {
      final times = forUtcDate(now.add(Duration(days: offset)), latitude, longitude, altitudeDeg: altitudeDeg);
      if (times.sunrise != null &&
          times.sunset != null &&
          !times.sunrise!.isAfter(now) &&
          now.isBefore(times.sunset!)) {
        return true;
      }
    }
    return false;
  }

  /// いまより後で、いちばん近い「明るくなる時刻」（市民薄明のはじまり。夜の画面の「再開時刻」用）
  static DateTime? nextSunrise(DateTime now, double latitude, double longitude) {
    for (final offset in [-1, 0, 1, 2]) {
      final sunrise = forUtcDate(now.add(Duration(days: offset)), latitude, longitude, altitudeDeg: civilTwilightDeg).sunrise;
      if (sunrise != null && sunrise.isAfter(now)) return sunrise;
    }
    return null;
  }

  /// いまを含む日（端末の日付）の、空が明るくなる時刻と暗くなる時刻（夜の画面の「きょう見えた入道雲」用）
  static SunTimes forLocalDay(DateTime now, double latitude, double longitude) {
    final local = now.toLocal();
    DateTime? sunrise;
    DateTime? sunset;
    for (final offset in [-1, 0, 1]) {
      final times = forUtcDate(now.add(Duration(days: offset)), latitude, longitude, altitudeDeg: civilTwilightDeg);
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
