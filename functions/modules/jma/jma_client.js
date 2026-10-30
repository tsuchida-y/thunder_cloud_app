/**
 * 気象庁ホームページのナウキャストのデータを取りに行くクラス
 *
 * 気象庁ホームページはアプリ向けの公式な窓口ではなく、URL や形式が予告なく変わることがある。
 * 取りに行く処理はこのファイルにまとめ、形が変わったらここだけ直せばよいようにする。
 *
 * 時刻の一覧: {BASE_URL}/targetTimes_N1.json（降水）, targetTimes_N3.json（雷）
 * タイル画像: {BASE_URL}/{basetime}/none/{validtime}/surf/{要素}/{z}/{x}/{y}.png
 * 時刻はどちらも UTC の "YYYYMMDDhhmmss"。basetime と validtime が同じものが解析値（いまの様子）。
 */

const axios = require('axios');
const { PNG } = require('pngjs');
const { JMA_NOWCAST } = require('../../constants');

class JmaClient {
  constructor(httpClient = axios) {
    this.http = httpClient;
  }

  /**
   * いちばん新しい解析値の時刻を返す
   *
   * @returns {Promise<{rain: string, thunder: string|null}>}
   */
  async getLatestAnalysisTimes() {
    const [rainTimes, thunderTimes] = await Promise.all([
      this._getJson(JMA_NOWCAST.TARGET_TIMES_RAIN),
      this._getJson(JMA_NOWCAST.TARGET_TIMES_THUNDER),
    ]);
    return {
      rain: JmaClient.findLatestAnalysis(rainTimes, JMA_NOWCAST.ELEMENT_RAIN),
      thunder: JmaClient.findLatestAnalysis(thunderTimes, JMA_NOWCAST.ELEMENT_THUNDER),
    };
  }

  /**
   * 時刻の一覧から、指定の要素を含む最新の解析値（basetime と validtime が同じ）の時刻を探す
   */
  static findLatestAnalysis(targetTimes, element) {
    if (!Array.isArray(targetTimes)) {
      throw new Error('気象庁の時刻一覧の形式が想定と違います');
    }
    const analyses = targetTimes
      .filter((t) => t.basetime === t.validtime && Array.isArray(t.elements) && t.elements.includes(element))
      .map((t) => t.basetime)
      .sort();
    return analyses.length > 0 ? analyses[analyses.length - 1] : null;
  }

  /**
   * 解析値のタイルを1枚取得して PNG として読む
   */
  async getAnalysisTile(basetime, element, zoom, x, y) {
    const url = `${JMA_NOWCAST.BASE_URL}/${basetime}/none/${basetime}/surf/${element}/${zoom}/${x}/${y}.png`;
    const response = await this.http.get(url, {
      responseType: 'arraybuffer',
      timeout: JMA_NOWCAST.REQUEST_TIMEOUT_MS,
      headers: { 'User-Agent': JMA_NOWCAST.USER_AGENT },
    });
    return PNG.sync.read(Buffer.from(response.data));
  }

  /**
   * 複数のタイルを、同時に取りに行く数を抑えながら取得する
   *
   * @param {Array<{x:number,y:number}>} tiles
   * @returns {Promise<Array<{x:number,y:number,png:Object}>>}
   */
  async getAnalysisTiles(basetime, element, zoom, tiles) {
    const results = [];
    for (let i = 0; i < tiles.length; i += JMA_NOWCAST.PARALLEL_REQUESTS) {
      const chunk = tiles.slice(i, i + JMA_NOWCAST.PARALLEL_REQUESTS);
      const pngs = await Promise.all(
        chunk.map((t) => this.getAnalysisTile(basetime, element, zoom, t.x, t.y))
      );
      chunk.forEach((t, index) => results.push({ x: t.x, y: t.y, png: pngs[index] }));
    }
    return results;
  }

  async _getJson(fileName) {
    const response = await this.http.get(`${JMA_NOWCAST.BASE_URL}/${fileName}`, {
      timeout: JMA_NOWCAST.REQUEST_TIMEOUT_MS,
      headers: { 'User-Agent': JMA_NOWCAST.USER_AGENT },
    });
    return response.data;
  }

  /**
   * 気象庁の時刻文字列 (UTC の YYYYMMDDhhmmss) を Date に直す
   */
  static parseTime(jmaTime) {
    const m = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/.exec(jmaTime || '');
    if (!m) throw new Error(`気象庁の時刻の形式が想定と違います: ${jmaTime}`);
    return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]));
  }
}

module.exports = JmaClient;
