/**
 * 利用者から見た雲の方角・距離・見上げる高さ
 *
 * - 方角は本当の北から時計回りの角度（0〜360°）。8方位の名前（北・北東…）も返す
 * - 見上げる高さは、雲のてっぺんを 12,000m と仮定して距離から求める（42km 先なら約16°）
 * - 腕を伸ばしたこぶし1つ ≒ 10° として、こぶしの数（0.5 刻み）で表す
 */

const EARTH_RADIUS_KM = 6371;
const CLOUD_TOP_KM = 12;
const DEGREES_PER_FIST = 10;

const DIRECTION_NAMES = ['北', '北東', '東', '南東', '南', '南西', '西', '北西'];

const toRad = (deg) => (deg * Math.PI) / 180;
const toDeg = (rad) => (rad * 180) / Math.PI;

/**
 * 2点間の距離 (km)
 */
function distanceKm(from, to) {
  const dLat = toRad(to.latitude - from.latitude);
  const dLon = toRad(to.longitude - from.longitude);
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(from.latitude)) * Math.cos(toRad(to.latitude)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(h));
}

/**
 * 雲のいちばん近い所（ふちの点）までの距離 (km)。ふちの点がなければ中心までの距離
 *
 * @param {{latitude:number,longitude:number}} from
 * @param {{latitude:number,longitude:number,edgePoints?:Array<{latitude:number,longitude:number}>}} cloud
 */
function nearestDistanceKm(from, cloud) {
  const points = cloud.edgePoints && cloud.edgePoints.length > 0 ? cloud.edgePoints : [cloud];
  return Math.min(...points.map((p) => distanceKm(from, p)));
}

/**
 * from から見た to の方角（本当の北から時計回り、0〜360°）
 */
function bearingDeg(from, to) {
  const lat1 = toRad(from.latitude);
  const lat2 = toRad(to.latitude);
  const dLon = toRad(to.longitude - from.longitude);
  const y = Math.sin(dLon) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
  return (toDeg(Math.atan2(y, x)) + 360) % 360;
}

/**
 * 角度を8方位の名前にする
 */
function directionName(bearing) {
  return DIRECTION_NAMES[Math.round(bearing / 45) % 8];
}

/**
 * 雲のてっぺんを見上げる角度（°）
 */
function elevationDeg(distance) {
  if (distance <= 0) return 90;
  return toDeg(Math.atan(CLOUD_TOP_KM / distance));
}

/**
 * 見上げる角度をこぶしの数（0.5 刻み、最低 0.5）にする
 */
function fistsFromElevation(elevation) {
  return Math.max(0.5, Math.round((elevation / DEGREES_PER_FIST) * 2) / 2);
}

/**
 * こぶしの数を文章にする（1.5 → 「こぶし1つ半」）
 */
function fistsLabel(fists) {
  const whole = Math.floor(fists);
  const half = fists - whole >= 0.5;
  if (whole === 0) return 'こぶし半分';
  return `こぶし${whole}つ${half ? '半' : ''}`;
}

/**
 * 利用者から見た雲の見え方をまとめて返す
 */
function describeCloud(from, cloud) {
  const distance = distanceKm(from, cloud);
  const bearing = bearingDeg(from, cloud);
  const elevation = elevationDeg(distance);
  const fists = fistsFromElevation(elevation);
  return {
    distanceKm: distance,
    bearingDeg: bearing,
    directionName: directionName(bearing),
    elevationDeg: elevation,
    fists,
    fistsLabel: fistsLabel(fists),
  };
}

module.exports = {
  distanceKm,
  nearestDistanceKm,
  bearingDeg,
  directionName,
  elevationDeg,
  fistsFromElevation,
  fistsLabel,
  describeCloud,
};
