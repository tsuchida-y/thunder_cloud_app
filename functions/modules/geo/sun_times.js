/**
 * 日の出・日の入りの時刻と、昼か夜か
 *
 * 米国海洋大気庁 (NOAA) の計算式による。誤差は1〜2分程度。
 * 日の出・日の入りは、太陽の中心が地平線の下 0.833°（大気の屈折と太陽の半径の分）になる時刻。
 *
 * 「夜（見張りを休む）」は、日の入りではなく、空が暗くなる市民薄明の終わり（太陽が地平線の下 6°）からにする。
 * 日の入りのあとも30分ほどは空が明るく、入道雲も見えるため（2026-10-22 tsuchida さん決定）。朝も同じ。
 */

const toRad = (deg) => (deg * Math.PI) / 180;
const toDeg = (rad) => (rad * 180) / Math.PI;
const DAY_MS = 24 * 60 * 60 * 1000;
/** 日の出・日の入り */
const SUNRISE_ALTITUDE_DEG = -0.833;
/** 市民薄明のはじまり・終わり（これより太陽が低いと「夜」） */
const CIVIL_TWILIGHT_DEG = -6;

/**
 * その日（UTC の日付）の日の出・日の入りを返す
 *
 * @param {Date} date - 日付（時刻は使わず、UTC の年月日だけを使う）
 * @param {number} latitude
 * @param {number} longitude
 * @returns {{sunrise: Date|null, sunset: Date|null}} 白夜・極夜のときは null
 */
function sunTimesForUtcDate(date, latitude, longitude, altitudeDeg = SUNRISE_ALTITUDE_DEG) {
  const dayStart = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
  const julianDay = dayStart / DAY_MS + 2440587.5;
  // その日の正午 (UTC) を指す、2000年1月1日正午からの日数
  const n = Math.ceil(julianDay - 2451545.0 + 0.0008);

  const meanSolarNoon = n - longitude / 360;
  const meanAnomaly = (357.5291 + 0.98560028 * meanSolarNoon) % 360;
  const center = 1.9148 * Math.sin(toRad(meanAnomaly)) +
    0.02 * Math.sin(toRad(2 * meanAnomaly)) +
    0.0003 * Math.sin(toRad(3 * meanAnomaly));
  const eclipticLongitude = (meanAnomaly + center + 180 + 102.9372) % 360;
  const solarTransit = 2451545.0 + meanSolarNoon +
    0.0053 * Math.sin(toRad(meanAnomaly)) - 0.0069 * Math.sin(toRad(2 * eclipticLongitude));
  const declination = Math.asin(Math.sin(toRad(eclipticLongitude)) * Math.sin(toRad(23.4397)));

  const cosHourAngle = (Math.sin(toRad(altitudeDeg)) - Math.sin(toRad(latitude)) * Math.sin(declination)) /
    (Math.cos(toRad(latitude)) * Math.cos(declination));
  if (cosHourAngle < -1 || cosHourAngle > 1) {
    return { sunrise: null, sunset: null };
  }
  const hourAngle = toDeg(Math.acos(cosHourAngle));
  const toDate = (jd) => new Date((jd - 2440587.5) * DAY_MS);
  return {
    sunrise: toDate(solarTransit - hourAngle / 360),
    sunset: toDate(solarTransit + hourAngle / 360),
  };
}

/**
 * いま、その場所が昼（市民薄明のはじまりから終わりまで。空が明るいあいだ）かどうか
 *
 * 日本の日の出・日の入りは UTC の同じ日付に収まる（日の出は前日の 19〜22 時 UTC になることもある）ので、
 * 前後の日も含めて「いまを挟む日の出と日の入り」があるかを調べる。
 */
function isDaytime(now, latitude, longitude) {
  for (const offset of [-1, 0, 1]) {
    const day = new Date(now.getTime() + offset * DAY_MS);
    const { sunrise, sunset } = sunTimesForUtcDate(day, latitude, longitude, CIVIL_TWILIGHT_DEG);
    if (sunrise && sunset && sunrise <= now && now < sunset) return true;
  }
  return false;
}

/**
 * いまより後で、いちばん近い「明るくなる時刻」（市民薄明のはじまり。夜の画面の「再開時刻」用）
 * altitudeDeg に SUNRISE_ALTITUDE_DEG を渡すと日の出の時刻
 */
function nextSunrise(now, latitude, longitude, altitudeDeg = CIVIL_TWILIGHT_DEG) {
  for (const offset of [-1, 0, 1, 2]) {
    const day = new Date(now.getTime() + offset * DAY_MS);
    const { sunrise } = sunTimesForUtcDate(day, latitude, longitude, altitudeDeg);
    if (sunrise && sunrise > now) return sunrise;
  }
  return null;
}

module.exports = { sunTimesForUtcDate, isDaytime, nextSunrise, SUNRISE_ALTITUDE_DEG, CIVIL_TWILIGHT_DEG };
