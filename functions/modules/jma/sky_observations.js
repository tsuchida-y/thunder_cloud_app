/**
 * ひまわりの赤外画像とアメダスの観測値から、雲と空のようすを読み取る関数群
 *
 * - 雲のてっぺんの温度（ひまわり）: 冷たいほど背が高い。入道雲かどうかと、てっぺんの高さに使う
 * - 見張る場所の空が一面の曇りか（アメダスの日照時間）
 * - 見張る場所から遠くまで見通せるか（アメダスの視程）
 *
 * どれも予想ではなく、いまの観測から読み取るだけ。通信や Firestore には触れない（テストしやすくするため）。
 */

const { HIMAWARI, AMEDAS, JMA_NOWCAST } = require('../../constants');
const { distanceKm } = require('../geo/sky_geometry');
const { isDaytime } = require('../geo/sun_times');

/**
 * 赤外画像の明るさ（0〜255）を温度（℃）に直す（見積もりの式。constants.js の HIMAWARI を参照）
 */
function grayToTempC(gray) {
  return HIMAWARI.GRAY_TO_TEMP_OFFSET - gray / HIMAWARI.GRAY_TO_TEMP_SCALE;
}

/**
 * 塊のまわりでいちばん冷たい雲のてっぺんの温度（℃）。画像がなければ null
 *
 * @param {{minX:number,maxX:number,minY:number,maxY:number}} bounds - 塊を囲む四角（z6 の全体のピクセル座標）
 * @param {Map<string, {width:number,height:number,data:Uint8Array}>} images - "x,y" をキーにした z6 の赤外画像
 */
function coldestTopTempC(bounds, images) {
  const margin = HIMAWARI.SEARCH_MARGIN_PIXELS;
  const size = JMA_NOWCAST.TILE_SIZE;
  let maxGray = -1;
  for (let y = bounds.minY - margin; y <= bounds.maxY + margin; y++) {
    for (let x = bounds.minX - margin; x <= bounds.maxX + margin; x++) {
      const image = images.get(`${Math.floor(x / size)},${Math.floor(y / size)}`);
      if (!image) continue;
      const px = ((x % size) + size) % size;
      const py = ((y % size) + size) % size;
      // 白黒なので赤の値だけ見ればよい
      maxGray = Math.max(maxGray, image.data[(py * image.width + px) * 4]);
    }
  }
  return maxGray < 0 ? null : grayToTempC(maxGray);
}

/**
 * てっぺんの温度と地上の気温から、てっぺんの高さ (km) を見積もる
 */
function topHeightKm(topTempC, surfaceTempC) {
  const height = (surfaceTempC - topTempC) / HIMAWARI.LAPSE_RATE_C_PER_KM;
  return Math.min(HIMAWARI.MAX_TOP_KM, Math.max(HIMAWARI.MIN_TOP_KM, height));
}

/**
 * 入道雲と言えるほど背が高いか（てっぺんの温度が分からなければ、ナウキャストだけで決めた今までどおり true）
 */
function isTallEnough(topTempC) {
  return topTempC === null || topTempC <= HIMAWARI.MAX_TOP_TEMP_C;
}

/**
 * 地点から半径内で、pick の値を持ついちばん近いアメダス地点の値
 */
function nearestValue(stations, point, radiusKm, pick) {
  let best = null;
  let bestDistance = Infinity;
  for (const station of stations) {
    const value = pick(station);
    if (value === null || value === undefined) continue;
    const distance = distanceKm(point, station);
    if (distance <= radiusKm && distance < bestDistance) {
      best = value;
      bestDistance = distance;
    }
  }
  return best;
}

/**
 * 雲のあたりの地上の気温（℃）。近くに地点がなければ決めておいた値
 */
function surfaceTempNear(stations, point) {
  const temp = nearestValue(stations || [], point, AMEDAS.TEMP_RADIUS_KM, (s) => s.tempC);
  return temp === null ? HIMAWARI.DEFAULT_SURFACE_TEMP_C : temp;
}

/**
 * 見張る場所の空が一面の曇りか
 *
 * 半径20km のアメダス地点がどこも、前の1時間ずっと日が差していなければ曇りとする。
 * 太陽が低いと晴れていても日照なしになるので、前の1時間ずっと太陽が15°より高かったときだけ判定する。
 * 1地点だけだと、入道雲そのものの影に入っただけのこともあるので、近くの地点をすべて見る。
 */
function isOvercast(stations, point, now) {
  const hourAgo = new Date(now.getTime() - 60 * 60 * 1000);
  const altitude = AMEDAS.SUNSHINE_MIN_SUN_ALTITUDE_DEG;
  if (!isDaytime(now, point.latitude, point.longitude, altitude) ||
    !isDaytime(hourAgo, point.latitude, point.longitude, altitude)) {
    return false;
  }
  const nearby = (stations || []).filter((s) =>
    s.sun1h !== null && s.sun1h !== undefined && distanceKm(point, s) <= AMEDAS.SUNSHINE_RADIUS_KM);
  return nearby.length > 0 && nearby.every((s) => s.sun1h === 0);
}

/**
 * 見張る場所から見通せる距離 (km)。20km 以上見通せるときと、近くに視程の地点がないときは null（制限なし）
 */
function visibilityKmNear(stations, point) {
  const meters = nearestValue(stations || [], point, AMEDAS.VISIBILITY_RADIUS_KM, (s) => s.visibilityM);
  if (meters === null || meters >= AMEDAS.VISIBILITY_MAX_M) return null;
  return meters / 1000;
}

module.exports = {
  grayToTempC,
  coldestTopTempC,
  topHeightKm,
  isTallEnough,
  surfaceTempNear,
  isOvercast,
  visibilityKmNear,
};
