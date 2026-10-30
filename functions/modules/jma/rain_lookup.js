/**
 * ある地点でいま雨が降っているかを、気象庁の降水の解析値から調べる
 *
 * 雨が降っている場所は雲の下か曇り空なので、入道雲の形は見えない。通知の前にこれで確かめる。
 *
 * - まず z4（日本全体、1ピクセル約8km）を見る。z4 は広い範囲のいちばん強い雨を出していて、
 *   z6 で雨のある所は z4 でも必ず同じか強い雨になっている（2026-10-22 に実データで確かめた）。
 *   なので z4 で雨がなければ、その地点に雨はない
 * - z4 で雨があるときだけ、z6（1ピクセル約2km）のタイルで地点そのものを調べる。
 *   雲を探すときに取ったタイルはそのまま使い、足りないタイルだけ取りに行く（1回の見張りで1度だけ）
 */

const { JMA_NOWCAST } = require('../../constants');
const { rainFromColor } = require('./nowcast_parser');

/**
 * 緯度経度を、そのズームの全体のピクセル座標にする
 */
function latLngToPixel(latitude, longitude, zoom) {
  const worldSize = JMA_NOWCAST.TILE_SIZE * 2 ** zoom;
  const x = ((longitude + 180) / 360) * worldSize;
  const lat = (latitude * Math.PI) / 180;
  const y = ((1 - Math.log(Math.tan(lat) + 1 / Math.cos(lat)) / Math.PI) / 2) * worldSize;
  return { x: Math.floor(x), y: Math.floor(y) };
}

class RainLookup {
  /**
   * @param {Object} jmaClient - getAnalysisTiles を持つもの
   * @param {string} basetime - 降水の解析時刻
   * @param {Array<{x:number,y:number,png:Object}>} coarseTiles - z4 のタイル
   * @param {Array<{x:number,y:number,png:Object}>} detailTiles - すでに取った z6 のタイル
   */
  constructor(jmaClient, basetime, coarseTiles, detailTiles = []) {
    this.jma = jmaClient;
    this.basetime = basetime;
    this.tiles = new Map();
    for (const t of coarseTiles) this.tiles.set(`${JMA_NOWCAST.COARSE_ZOOM}/${t.x}/${t.y}`, Promise.resolve(t.png));
    for (const t of detailTiles) this.tiles.set(`${JMA_NOWCAST.DETAIL_ZOOM}/${t.x}/${t.y}`, Promise.resolve(t.png));
  }

  /**
   * その地点の雨の強さの下限 (mm/h)。雨がなければ null
   */
  async rainAt(latitude, longitude) {
    const coarse = await this._read(latitude, longitude, JMA_NOWCAST.COARSE_ZOOM, false);
    if (coarse === null) return null;
    return this._read(latitude, longitude, JMA_NOWCAST.DETAIL_ZOOM, true);
  }

  /**
   * いま雨が降っているか（1時間に1mm以上）
   */
  async isRaining(latitude, longitude) {
    const mm = await this.rainAt(latitude, longitude);
    return mm !== null && mm >= JMA_NOWCAST.RAIN_HERE_MM_PER_HOUR;
  }

  async _read(latitude, longitude, zoom, fetchIfMissing) {
    const pixel = latLngToPixel(latitude, longitude, zoom);
    const tileX = Math.floor(pixel.x / JMA_NOWCAST.TILE_SIZE);
    const tileY = Math.floor(pixel.y / JMA_NOWCAST.TILE_SIZE);
    const key = `${zoom}/${tileX}/${tileY}`;
    if (!this.tiles.has(key)) {
      // 日本の外（z4 のタイルの範囲の外）は雨なしとみなす
      if (!fetchIfMissing) return null;
      this.tiles.set(key, this.jma
        .getAnalysisTiles(this.basetime, JMA_NOWCAST.ELEMENT_RAIN, zoom, [{ x: tileX, y: tileY }])
        .then((results) => results[0].png));
    }
    const png = await this.tiles.get(key);
    const px = pixel.x - tileX * JMA_NOWCAST.TILE_SIZE;
    const py = pixel.y - tileY * JMA_NOWCAST.TILE_SIZE;
    const i = (py * png.width + px) * 4;
    return rainFromColor(png.data[i], png.data[i + 1], png.data[i + 2], png.data[i + 3]);
  }
}

module.exports = { RainLookup, latLngToPixel };
