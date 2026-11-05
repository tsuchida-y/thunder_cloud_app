/**
 * ひまわりの赤外画像とアメダスの観測値から、雲と空のようすを読み取る関数群
 *
 * - 雲のてっぺんの温度（ひまわり）: 冷たいほど背が高い。入道雲かどうかと、てっぺんの高さに使う
 * - 見張る場所の空が一面の曇りか（アメダスの日照時間）
 * - 見張る場所から遠くまで見通せるか（アメダスの視程）
 *
 * どれも予想ではなく、いまの観測から読み取るだけ。通信や Firestore には触れない（テストしやすくするため）。
 */

const { HIMAWARI, AMEDAS, JMA_NOWCAST, CLOUD_COVER } = require('../../constants');
const { distanceKm } = require('../geo/sky_geometry');
const { isDaytime, sunAltitudeDeg } = require('../geo/sun_times');
const { latLngToPixel } = require('./rain_lookup');

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
 * 前の1時間のうち、太陽が altitudeDeg 以上の高さだった時間（分。5分きざみ）
 */
function sunMinutesAbove(now, point, altitudeDeg, windowMinutes = 60, stepMinutes = 5) {
  let minutes = 0;
  for (let ago = 0; ago < windowMinutes; ago += stepMinutes) {
    const at = new Date(now.getTime() - ago * 60 * 1000);
    if (isDaytime(at, point.latitude, point.longitude, altitudeDeg)) minutes += stepMinutes;
  }
  return minutes;
}

/**
 * 見張る場所から半径20km のアメダス地点の、前の1時間の日照
 *
 * @returns {{stations:number, anyPositive:boolean, allZero:boolean}} 日照が取れた地点の数と、日差しがあった地点があるか、
 *   どこも日差しがなかったか（地点がなければ allZero は false）
 */
function nearbySunshine(stations, point) {
  const nearby = (stations || []).filter((s) =>
    s.sun1h !== null && s.sun1h !== undefined && distanceKm(point, s) <= AMEDAS.SUNSHINE_RADIUS_KM);
  return {
    stations: nearby.length,
    anyPositive: nearby.some((s) => s.sun1h > 0),
    allZero: nearby.length > 0 && nearby.every((s) => s.sun1h === 0),
  };
}

/**
 * 日照（アメダス）を使えるか
 *
 * 太陽が低いと、晴れていても日照が0になる。前の1時間のうち、太陽が10°以上だった時間が30分以上あるときだけ使う。
 */
function isSunshineUsable(now, point) {
  return sunMinutesAbove(now, point, AMEDAS.SUNSHINE_MIN_SUN_ALTITUDE_DEG) >= AMEDAS.SUNSHINE_MIN_MINUTES;
}

/**
 * 見張る場所の空が一面の曇りか（日照だけで見る。ひまわりが取れなかったときの代わり）
 *
 * 半径20km のアメダス地点がどこも、前の1時間ずっと日が差していなければ曇りとする。
 * 1地点だけだと、入道雲そのものの影に入っただけのこともあるので、近くの地点をすべて見る。
 */
function isOvercast(stations, point, now) {
  if (!isSunshineUsable(now, point)) return false;
  return nearbySunshine(stations, point).allZero;
}

/**
 * 見張る場所のまわり（半径20km）の雲の量
 *
 * ひまわりの赤外画像で、温度が地上の気温より COLD_DELTA_C 以上低いピクセルの割合。
 * 地上の気温が分からないとき（近くにアメダスがない）や、画像が足りないときは null（分からない）。
 *
 * @param {{latitude:number,longitude:number}} point
 * @param {Map<string, {width:number,height:number,data:Uint8Array}>} images - "x,y" をキーにした z6 の赤外画像
 * @param {number|null} surfaceTempC - 見張る場所の近くの地上の気温（アメダス）
 * @returns {{fraction:number, fractions:Object<string,number>, medianDeltaC:number, pixels:number}|null}
 */
function cloudCover(point, images, surfaceTempC) {
  if (!images || images.size === 0 || typeof surfaceTempC !== 'number') return null;
  const size = JMA_NOWCAST.TILE_SIZE;
  const radius = CLOUD_COVER.RADIUS_PIXELS;
  const center = latLngToPixel(point.latitude, point.longitude, HIMAWARI.ZOOM);
  const deltas = [];
  let total = 0;
  for (let dy = -radius; dy <= radius; dy++) {
    for (let dx = -radius; dx <= radius; dx++) {
      if (dx * dx + dy * dy > radius * radius) continue;
      total++;
      const x = center.x + dx;
      const y = center.y + dy;
      const image = images.get(`${Math.floor(x / size)},${Math.floor(y / size)}`);
      if (!image) continue;
      const px = ((x % size) + size) % size;
      const py = ((y % size) + size) % size;
      deltas.push(grayToTempC(image.data[(py * image.width + px) * 4]) - surfaceTempC);
    }
  }
  // 画像が半分以上足りないときは、判断しない
  if (deltas.length < total / 2) return null;
  deltas.sort((a, b) => a - b);
  const shareBelow = (delta) => deltas.filter((d) => d <= -delta).length / deltas.length;
  const fractions = {};
  [CLOUD_COVER.COLD_DELTA_C, ...CLOUD_COVER.EXTRA_DELTAS_C].forEach((delta) => {
    fractions[delta] = Math.round(shareBelow(delta) * 100) / 100;
  });
  return {
    fraction: fractions[CLOUD_COVER.COLD_DELTA_C],
    fractions,
    medianDeltaC: Math.round(deltas[Math.floor(deltas.length / 2)] * 10) / 10,
    pixels: deltas.length,
  };
}

/**
 * 見張る場所のまわり（雲の量を測る範囲）にかかる、z6 のタイルの一覧
 *
 * @param {Array<{latitude:number,longitude:number}>} points
 * @returns {Array<{x:number,y:number}>}
 */
function infraredTilesAround(points) {
  const size = JMA_NOWCAST.TILE_SIZE;
  const radius = CLOUD_COVER.RADIUS_PIXELS;
  const keys = new Set();
  for (const point of points) {
    const c = latLngToPixel(point.latitude, point.longitude, HIMAWARI.ZOOM);
    for (let x = Math.floor((c.x - radius) / size); x <= Math.floor((c.x + radius) / size); x++) {
      for (let y = Math.floor((c.y - radius) / size); y <= Math.floor((c.y + radius) / size); y++) {
        keys.add(`${x},${y}`);
      }
    }
  }
  return [...keys].map((key) => {
    const [x, y] = key.split(',').map(Number);
    return { x, y };
  });
}

/**
 * 見張る場所の空のようす（一面の曇りか）と、判断に使った数字
 *
 * - 日照（アメダス）を使える時間（太陽が10°以上の時間が前の1時間に30分以上）に、近くの地点がどこも日照0なら、曇り。
 * - ひまわりの雲の量が80%以上でも、曇り。ただし日照を使える時間に、近くで日差しがあった地点があれば、雲に切れ間が
 *   あるので曇りとしない（薄い雲やまばらな雲）。
 * - ひまわりが取れなかったとき（cover が null）は、日照だけで決める。
 * どちらも予想ではなく、いまの観測から読み取るだけ。
 *
 * @returns {{overcast:boolean, cover:Object|null, sun:{altitudeDeg:number, usable:boolean, stations:number,
 *   anyPositive:boolean, allZero:boolean}, surfaceTempC:number|null}}
 */
function assessSky({ stations, point, now, images }) {
  const usable = isSunshineUsable(now, point);
  const sunshine = nearbySunshine(stations, point);
  const surfaceTempC = nearestValue(stations || [], point, AMEDAS.TEMP_RADIUS_KM, (s) => s.tempC);
  const cover = cloudCover(point, images, surfaceTempC);

  const darkBySunshine = usable && sunshine.allZero;
  const coveredByInfrared = cover !== null && cover.fraction >= CLOUD_COVER.OVERCAST_FRACTION &&
    !(usable && sunshine.anyPositive);
  return {
    overcast: darkBySunshine || coveredByInfrared,
    cover,
    sun: {
      altitudeDeg: Math.round(sunAltitudeDeg(now, point.latitude, point.longitude) * 10) / 10,
      usable,
      ...sunshine,
    },
    surfaceTempC,
  };
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
  sunMinutesAbove,
  nearbySunshine,
  isSunshineUsable,
  cloudCover,
  infraredTilesAround,
  assessSky,
  visibilityKmNear,
};
