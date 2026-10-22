/**
 * 気象庁ホームページのひまわりの赤外画像（バンド13）を取りに行くクラス
 *
 * 気象庁ホームページはアプリ向けの公式な窓口ではなく、URL や形式が予告なく変わることがある。
 * 取りに行く処理はこのファイルにまとめ、形が変わったらここだけ直せばよいようにする。
 *
 * 時刻の一覧: {BASE_URL}/targetTimes_jp.json（日本域、2.5分ごと）
 * タイル画像: {BASE_URL}/{basetime}/jp/{validtime}/B13/TBB/{z}/{x}/{y}.jpg（白黒の JPEG、冷たいほど白い）
 * タイルの並びはナウキャストと同じ（同じ z・x・y が同じ場所）。時刻は UTC の "YYYYMMDDhhmmss"。
 */

const axios = require('axios');
const jpeg = require('jpeg-js');
const { HIMAWARI, JMA_NOWCAST } = require('../../constants');

class HimawariClient {
  constructor(httpClient = axios) {
    this.http = httpClient;
  }

  /**
   * 指定の時刻（ナウキャストの解析時刻）か、それより前でいちばん新しい画像の時刻
   *
   * @param {string} atOrBefore - UTC の "YYYYMMDDhhmmss"
   * @returns {Promise<{basetime:string, validtime:string}|null>}
   */
  async getTimeAtOrBefore(atOrBefore) {
    const response = await this.http.get(`${HIMAWARI.BASE_URL}/${HIMAWARI.TARGET_TIMES}`, {
      timeout: JMA_NOWCAST.REQUEST_TIMEOUT_MS,
      headers: { 'User-Agent': JMA_NOWCAST.USER_AGENT },
    });
    const times = (response.data || []).filter((t) => t.validtime <= atOrBefore);
    if (times.length === 0) return null;
    return times.reduce((a, b) => (a.validtime >= b.validtime ? a : b));
  }

  /**
   * 赤外画像のタイルを取得する（日本域の外などで取れないタイルは飛ばす）
   *
   * @param {{basetime:string, validtime:string}} time
   * @param {Array<{x:number,y:number}>} tiles - z6 のタイル
   * @returns {Promise<Array<{x:number,y:number,image:{width:number,height:number,data:Uint8Array}}>>}
   */
  async getInfraredTiles(time, tiles) {
    const results = [];
    for (let i = 0; i < tiles.length; i += JMA_NOWCAST.PARALLEL_REQUESTS) {
      const chunk = tiles.slice(i, i + JMA_NOWCAST.PARALLEL_REQUESTS);
      const images = await Promise.all(chunk.map((t) => this._getTile(time, t.x, t.y)));
      chunk.forEach((t, index) => {
        if (images[index]) results.push({ x: t.x, y: t.y, image: images[index] });
      });
    }
    return results;
  }

  async _getTile(time, x, y) {
    const url = `${HIMAWARI.BASE_URL}/${time.basetime}/${HIMAWARI.AREA}/${time.validtime}/` +
      `${HIMAWARI.BAND}/${HIMAWARI.PRODUCT}/${HIMAWARI.ZOOM}/${x}/${y}.jpg`;
    try {
      const response = await this.http.get(url, {
        responseType: 'arraybuffer',
        timeout: JMA_NOWCAST.REQUEST_TIMEOUT_MS,
        headers: { 'User-Agent': JMA_NOWCAST.USER_AGENT },
      });
      return jpeg.decode(Buffer.from(response.data), { useTArray: true });
    } catch (error) {
      // 日本域の外のタイルは 404 になる。それ以外の失敗は呼んだ側でまとめて扱う
      if (error.response && error.response.status === 404) return null;
      throw error;
    }
  }
}

module.exports = HimawariClient;
