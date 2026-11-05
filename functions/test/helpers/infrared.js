/**
 * テスト用の、ひまわりの赤外画像（z6）
 */
const { latLngToPixel } = require('../../modules/jma/rain_lookup');

/** 気温 8℃ のとき、赤外の温度が 8℃ になる明るさ（晴れ）と、-30℃ になる明るさ（厚い雲） */
const GRAY_CLEAR = Math.round((45 - 8) * 1.9);
const GRAY_CLOUD = Math.round((45 + 30) * 1.9);

/**
 * 見張る場所のまわりのタイルを、grayAt(全体のx, 全体のy, 見張る場所のピクセル) の明るさで埋めたものを作る
 *
 * @returns {Map<string, {width:number,height:number,data:Uint8Array}>}
 */
function infraredAround(point, grayAt) {
  const center = latLngToPixel(point.latitude, point.longitude, 6);
  const images = new Map();
  const tx = Math.floor(center.x / 256);
  const ty = Math.floor(center.y / 256);
  for (const x of [tx - 1, tx, tx + 1]) {
    for (const y of [ty - 1, ty, ty + 1]) {
      const data = new Uint8Array(256 * 256 * 4);
      for (let py = 0; py < 256; py++) {
        for (let px = 0; px < 256; px++) {
          const gray = grayAt(x * 256 + px, y * 256 + py, center);
          data.fill(gray, (py * 256 + px) * 4, (py * 256 + px) * 4 + 3);
          data[(py * 256 + px) * 4 + 3] = 255;
        }
      }
      images.set(`${x},${y}`, { width: 256, height: 256, data });
    }
  }
  return images;
}

/** nowcast_service の infrared と同じ形のもの（ensureAround は何もしない） */
function fakeInfrared(images, validtime = '20260812062000') {
  return { validtime, images, ensureAround: async () => {} };
}

module.exports = { GRAY_CLEAR, GRAY_CLOUD, infraredAround, fakeInfrared };
