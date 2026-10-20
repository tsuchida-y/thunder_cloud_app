/**
 * 気象庁ナウキャストのタイル画像を読み解く関数群
 *
 * タイルの色を雨の強さ・雷の活動度に戻し、「強い雨か雷のある場所」が
 * つながった塊を取り出す。通信や Firestore には触れない（テストしやすくするため）。
 *
 * 色は気象庁ホームページの凡例とタイルの実際の色で確かめたもの（2026-10-20）。
 * 凡例の黄色は 255,245,0 だが、タイルでは 250,245,0 なので、近い色で判定する。
 */

const { JMA_NOWCAST } = require('../../constants');

// 降水強度の色と、その色が表す強さの下限 (mm/h)
const RAIN_COLORS = [
  { rgb: [242, 242, 255], mmPerHour: 0 },
  { rgb: [160, 210, 255], mmPerHour: 1 },
  { rgb: [33, 140, 255], mmPerHour: 5 },
  { rgb: [0, 65, 255], mmPerHour: 10 },
  { rgb: [250, 245, 0], mmPerHour: 20 },
  { rgb: [255, 153, 0], mmPerHour: 30 },
  { rgb: [255, 40, 0], mmPerHour: 50 },
  { rgb: [180, 0, 104], mmPerHour: 80 },
];

// 雷の活動度（1〜4）の色
const THUNDER_COLORS = [
  { rgb: [250, 245, 0], level: 1 },
  { rgb: [255, 170, 0], level: 2 },
  { rgb: [255, 40, 0], level: 3 },
  { rgb: [200, 0, 255], level: 4 },
];

// 凡例とタイルの色の小さなずれを許す範囲（RGB の差の2乗和）
const COLOR_TOLERANCE = 12 * 12 * 3;

function nearestColor(table, r, g, b) {
  let best = null;
  let bestDistance = Infinity;
  for (const entry of table) {
    const [er, eg, eb] = entry.rgb;
    const distance = (r - er) ** 2 + (g - eg) ** 2 + (b - eb) ** 2;
    if (distance < bestDistance) {
      best = entry;
      bestDistance = distance;
    }
  }
  return bestDistance <= COLOR_TOLERANCE ? best : null;
}

/**
 * タイルの1ピクセルの色から雨の強さの下限 (mm/h) を返す。雨がなければ null。
 */
function rainFromColor(r, g, b, a) {
  if (a === 0) return null;
  const entry = nearestColor(RAIN_COLORS, r, g, b);
  return entry ? entry.mmPerHour : null;
}

/**
 * タイルの1ピクセルの色から雷の活動度 (1〜4) を返す。雷がなければ 0。
 */
function thunderFromColor(r, g, b, a) {
  if (a === 0) return 0;
  const entry = nearestColor(THUNDER_COLORS, r, g, b);
  return entry ? entry.level : 0;
}

/**
 * 全体のピクセル座標（タイル番号×256＋タイル内の位置）の中心を緯度経度に直す
 */
function pixelToLatLng(globalX, globalY, zoom) {
  const worldSize = JMA_NOWCAST.TILE_SIZE * 2 ** zoom;
  const longitude = ((globalX + 0.5) / worldSize) * 360 - 180;
  const mercatorY = Math.PI * (1 - (2 * (globalY + 0.5)) / worldSize);
  const latitude = (Math.atan(Math.sinh(mercatorY)) * 180) / Math.PI;
  return { latitude, longitude };
}

/**
 * その緯度での1ピクセルの面積 (km²)
 */
function pixelAreaKm2(latitude, zoom) {
  const earthCircumferenceKm = 40075.016686;
  const sideKm = (earthCircumferenceKm * Math.cos((latitude * Math.PI) / 180)) /
    (JMA_NOWCAST.TILE_SIZE * 2 ** zoom);
  return sideKm * sideKm;
}

/**
 * 1枚のタイル (pngjs の PNG) を読み、条件に合うピクセルを返す
 *
 * @param {{width:number,height:number,data:Buffer}} png
 * @param {number} tileX
 * @param {number} tileY
 * @param {(r:number,g:number,b:number,a:number)=>(number|null)} readValue - 色から値を読む関数
 * @param {(value:number|null)=>boolean} isTarget - 拾う条件
 * @returns {Array<{x:number,y:number,value:number}>} 全体のピクセル座標と値
 */
function collectPixels(png, tileX, tileY, readValue, isTarget) {
  const pixels = [];
  for (let py = 0; py < png.height; py++) {
    for (let px = 0; px < png.width; px++) {
      const i = (py * png.width + px) * 4;
      const value = readValue(png.data[i], png.data[i + 1], png.data[i + 2], png.data[i + 3]);
      if (isTarget(value)) {
        pixels.push({
          x: tileX * JMA_NOWCAST.TILE_SIZE + px,
          y: tileY * JMA_NOWCAST.TILE_SIZE + py,
          value,
        });
      }
    }
  }
  return pixels;
}

/**
 * 強い雨のピクセルと雷のピクセルを合わせ、8方向につながった塊ごとにまとめる
 *
 * @param {Array<{x:number,y:number,value:number}>} rainPixels - 雨の強さ (mm/h) を持つピクセル
 * @param {Array<{x:number,y:number,value:number}>} thunderPixels - 雷の活動度を持つピクセル
 * @param {number} zoom - ピクセル座標のズーム
 * @returns {Array<Object>} 塊ごとの中心・強さ・広さ
 */
function extractClusters(rainPixels, thunderPixels, zoom) {
  const cells = new Map();
  const cellOf = (x, y) => {
    const key = `${x},${y}`;
    if (!cells.has(key)) cells.set(key, { x, y, rain: 0, thunder: 0 });
    return cells.get(key);
  };
  for (const p of rainPixels) {
    const cell = cellOf(p.x, p.y);
    cell.rain = Math.max(cell.rain, p.value);
  }
  for (const p of thunderPixels) {
    const cell = cellOf(p.x, p.y);
    cell.thunder = Math.max(cell.thunder, p.value);
  }

  const visited = new Set();
  const clusters = [];
  for (const [startKey, startCell] of cells) {
    if (visited.has(startKey)) continue;
    visited.add(startKey);

    const members = [];
    const stack = [startCell];
    while (stack.length > 0) {
      const cell = stack.pop();
      members.push(cell);
      for (let dx = -1; dx <= 1; dx++) {
        for (let dy = -1; dy <= 1; dy++) {
          const key = `${cell.x + dx},${cell.y + dy}`;
          if (!visited.has(key) && cells.has(key)) {
            visited.add(key);
            stack.push(cells.get(key));
          }
        }
      }
    }
    clusters.push(summarizeCluster(members, zoom));
  }

  // 大きい塊から順に並べる
  return clusters.sort((a, b) => b.areaKm2 - a.areaKm2);
}

function summarizeCluster(members, zoom) {
  let sumX = 0;
  let sumY = 0;
  let maxRain = 0;
  let maxThunder = 0;
  let areaKm2 = 0;
  for (const cell of members) {
    sumX += cell.x;
    sumY += cell.y;
    maxRain = Math.max(maxRain, cell.rain);
    maxThunder = Math.max(maxThunder, cell.thunder);
    areaKm2 += pixelAreaKm2(pixelToLatLng(cell.x, cell.y, zoom).latitude, zoom);
  }
  const center = pixelToLatLng(sumX / members.length, sumY / members.length, zoom);
  return {
    latitude: center.latitude,
    longitude: center.longitude,
    maxRainMmPerHour: maxRain,
    maxThunderLevel: maxThunder,
    areaKm2,
    pixelCount: members.length,
  };
}

module.exports = {
  rainFromColor,
  thunderFromColor,
  pixelToLatLng,
  pixelAreaKm2,
  collectPixels,
  extractClusters,
};
