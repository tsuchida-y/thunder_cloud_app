/**
 * 気象庁ホームページのアメダスの最新の観測値を取りに行くクラス
 *
 * 気象庁ホームページはアプリ向けの公式な窓口ではなく、URL や形式が予告なく変わることがある。
 * 取りに行く処理はこのファイルにまとめ、形が変わったらここだけ直せばよいようにする。
 *
 * 最新の時刻: {BASE_URL}/data/latest_time.txt（"2026-10-22T17:00:00+09:00" のような日本時間、10分ごと）
 * 観測値: {BASE_URL}/data/map/{日本時間の YYYYMMDDhhmm00}.json（地点番号ごとに [値, 品質] の組）
 * 地点の一覧: {BASE_URL}/const/amedastable.json（緯度経度は [度, 分]）
 */

const axios = require('axios');
const { AMEDAS, JMA_NOWCAST, NOTIFY_RULES } = require('../../constants');

/** 品質が「正常」(0) の値だけを使う */
const valueOf = (pair) => (Array.isArray(pair) && pair[1] === 0 && typeof pair[0] === 'number' ? pair[0] : null);

class AmedasClient {
  constructor(httpClient = axios) {
    this.http = httpClient;
    this.table = null;
    this.tableFetchedAt = 0;
  }

  /**
   * 最新の観測値
   *
   * @returns {Promise<{observedAt: Date, stations: Array<{id:string, latitude:number, longitude:number,
   *   tempC:number|null, sun1h:number|null, visibilityM:number|null}>}>}
   *   sun1h は前の1時間の日照時間（時間、0〜1）
   */
  async getLatest() {
    const [latestText, table] = await Promise.all([
      this._get(AMEDAS.LATEST_TIME, 'text'),
      this._getTable(),
    ]);
    const observedAt = new Date(String(latestText).trim());
    if (Number.isNaN(observedAt.getTime())) throw new Error(`アメダスの時刻が読めません: ${latestText}`);
    // "2026-10-22T08:00:00.000Z" → 日本時間の "20261022170000"
    const jst = new Date(observedAt.getTime() + NOTIFY_RULES.JST_OFFSET_MS).toISOString();
    const fileName = `${jst.slice(0, 16).replace(/[-:T]/g, '')}00`;
    const values = await this._get(`data/map/${fileName}.json`, 'json');

    const stations = [];
    for (const [id, v] of Object.entries(values || {})) {
      const place = table[id];
      if (!place) continue;
      stations.push({
        id,
        latitude: place.lat[0] + place.lat[1] / 60,
        longitude: place.lon[0] + place.lon[1] / 60,
        tempC: valueOf(v.temp),
        sun1h: valueOf(v.sun1h),
        visibilityM: valueOf(v.visibility),
      });
    }
    return { observedAt, stations };
  }

  async _getTable() {
    if (!this.table || Date.now() - this.tableFetchedAt > AMEDAS.STATION_TABLE_TTL_MS) {
      this.table = await this._get(AMEDAS.STATION_TABLE, 'json');
      this.tableFetchedAt = Date.now();
    }
    return this.table;
  }

  async _get(path, responseType) {
    const response = await this.http.get(`${AMEDAS.BASE_URL}/${path}`, {
      responseType,
      timeout: JMA_NOWCAST.REQUEST_TIMEOUT_MS,
      headers: { 'User-Agent': JMA_NOWCAST.USER_AGENT },
    });
    return response.data;
  }
}

module.exports = AmedasClient;
