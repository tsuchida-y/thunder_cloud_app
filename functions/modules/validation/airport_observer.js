/**
 * 空港の気象実況（METAR）と、同じ場所のひまわりの雲の量を並べて記録する（しきい値の検証用）
 *
 * 通知の判断には使わない。空港の観測が「曇り（BKN/OVC）」「ほぼ晴れ（FEW 以下）」のところで、
 * ひまわりの雲の量（見張る場所のまわり半径20kmで、気温より8℃以上冷たいピクセルの割合）が合うかを、
 * 毎日たくさん確かめて、しきい値（CLOUD_COVER）を調整するための記録。夏に積乱雲（CB）や雄大積雲（TCU）の
 * 記号が入ったら、検知した雲が本物かを確かめる答えにもなる。
 *
 * 毎時15分と45分に取り、直近25分の観測を、観測の時刻（0分か30分）の枠ごとに1件
 * （sky_validation/{日本時間の YYYYMMDDhhmm}）にまとめて書く。
 * 利用者の情報は含まない。
 */

const axios = require('axios');
const admin = require('firebase-admin');
const { JMA_NOWCAST, VALIDATION, CLOUD_COVER } = require('../../constants');
const HimawariClient = require('../jma/himawari_client');
const { cloudCover, infraredTilesAround } = require('../jma/sky_observations');
const { sunAltitudeDeg } = require('../geo/sun_times');

const round = (value, digits = 1) => {
  if (typeof value !== 'number' || Number.isNaN(value)) return null;
  return Math.round(value * 10 ** digits) / 10 ** digits;
};

/** 雲の層の記号: 曇りとみなす（空の5/8以上）と、晴れに近い（2/8以下） */
const COVERED = new Set(['BKN', 'OVC', 'OVX', 'VV']);
const CLEARISH = new Set(['CLR', 'SKC', 'NSC', 'NCD', 'CAVOK', 'FEW']);

/**
 * METAR の1件を、記録する形にする
 *
 * @param {Object} metar - aviationweather.gov の JSON の1件
 * @returns {Object|null} 日本の空港でなければ、位置や気温がなければ null
 */
function summarizeMetar(metar) {
  if (!metar || typeof metar.icaoId !== 'string') return null;
  if (!(metar.icaoId.startsWith('RJ') || metar.icaoId.startsWith('RO'))) return null;
  if (typeof metar.lat !== 'number' || typeof metar.lon !== 'number' || typeof metar.temp !== 'number') return null;
  if (typeof metar.obsTime !== 'number') return null;

  const layers = (metar.clouds || []).map((c) => ({
    cover: c.cover,
    baseFt: typeof c.base === 'number' ? c.base : null,
  }));
  const covers = layers.map((l) => l.cover);
  const raw = typeof metar.rawOb === 'string' ? metar.rawOb : '';
  // 積乱雲（CB）・雄大積雲（TCU）の記号は、層のあとに付く（例: BKN030TCU）
  const convective = [...raw.matchAll(/\b(?:FEW|SCT|BKN|OVC)(\d{3})(CB|TCU)\b/g)]
    .map((m) => ({ type: m[2], baseFt: Number(m[1]) * 100 }));
  const bases = layers.map((l) => l.baseFt).filter((b) => b !== null);
  return {
    icao: metar.icaoId,
    name: metar.name || null,
    latitude: round(metar.lat, 3),
    longitude: round(metar.lon, 3),
    obsTimeMs: metar.obsTime * 1000,
    tempC: metar.temp,
    visibility: metar.visib === undefined ? null : String(metar.visib),
    layers,
    lowestBaseFt: bases.length > 0 ? Math.min(...bases) : null,
    // 空の5/8以上が雲におおわれていた層があるか。FEW 以下だけ（または層なし）なら「ほぼ晴れ」。それ以外（SCT だけ）は、どちらでもない
    covered: covers.some((c) => COVERED.has(c)),
    clearish: covers.length === 0 || covers.every((c) => CLEARISH.has(c)),
    hasConvective: convective.length > 0,
    convective,
    raw: raw.slice(0, 200),
  };
}

/**
 * 空港ごとの METAR と赤外の雲の量が合っているかを数える（検証用の集計）
 *
 * @param {Array<{covered:boolean, clearish:boolean, ir:{fractions:Object<string,number>}|null}>} stations
 * @param {{delta:number, fraction:number}} threshold - 気温より delta ℃以上冷たいピクセルが fraction 以上なら曇りとする
 * @returns {{coveredTotal:number, coveredFound:number, clearTotal:number, clearWrong:number}}
 */
function evaluateAgreement(stations, { delta, fraction }) {
  const result = { coveredTotal: 0, coveredFound: 0, clearTotal: 0, clearWrong: 0 };
  for (const s of stations) {
    const value = s.ir && s.ir.fractions ? s.ir.fractions[String(delta)] : undefined;
    if (typeof value !== 'number') continue;
    if (s.covered) {
      result.coveredTotal++;
      if (value >= fraction) result.coveredFound++;
    } else if (s.clearish) {
      result.clearTotal++;
      if (value >= fraction) result.clearWrong++;
    }
  }
  return result;
}

/** 30分ごとの時刻の枠（日本時間の YYYYMMDDhhmm）にする */
function bucketId(ms) {
  const jst = new Date(ms + 9 * 60 * 60 * 1000);
  const minutes = jst.getUTCMinutes() < 30 ? '00' : '30';
  return `${jst.toISOString().slice(0, 13).replace(/[-T]/g, '')}${minutes}`;
}

class AirportObserver {
  constructor({ http = axios, himawari = new HimawariClient() } = {}) {
    this.http = http;
    this.himawari = himawari;
  }

  get firestore() {
    return admin.firestore();
  }

  /**
   * 日本の空港の、いちばん新しい METAR（古すぎるものは除く）
   */
  async fetchMetars(now) {
    const url = `${VALIDATION.METAR_URL}?bbox=${VALIDATION.METAR_BBOX}&format=json&hours=2`;
    const response = await this.http.get(url, {
      timeout: JMA_NOWCAST.REQUEST_TIMEOUT_MS * 2,
      headers: { 'User-Agent': JMA_NOWCAST.USER_AGENT },
    });
    if (!Array.isArray(response.data)) throw new Error('METAR の形が想定と違います');
    const latest = new Map();
    for (const metar of response.data) {
      const summary = summarizeMetar(metar);
      if (!summary) continue;
      const old = latest.get(summary.icao);
      if (!old || summary.obsTimeMs > old.obsTimeMs) latest.set(summary.icao, summary);
    }
    return [...latest.values()].filter((s) => now.getTime() - s.obsTimeMs <= VALIDATION.METAR_MAX_AGE_MS);
  }

  /**
   * 空港の観測と雲の量を並べて、Firestore に1件書く
   *
   * @returns {Promise<{id:string, airports:number, withInfrared:number}|null>} 書かなかったときは null
   */
  async run(now = new Date()) {
    const metars = await this.fetchMetars(now);
    if (metars.length === 0) {
      console.log('✈️ [AIRPORT_OBS] 新しい METAR がありません');
      return null;
    }
    const latestMs = Math.max(...metars.map((m) => m.obsTimeMs));

    // 観測の時刻に近いひまわりの画像（取れなければ、METAR だけ記録する）
    let images = null;
    let himawariTime = null;
    try {
      const wanted = new Date(latestMs).toISOString().replace(/[-:T]/g, '').slice(0, 14);
      const time = await this.himawari.getTimeAtOrBefore(wanted);
      if (time) {
        const tiles = await this.himawari.getInfraredTiles(
          time, infraredTilesAround(metars.map((m) => ({ latitude: m.latitude, longitude: m.longitude }))));
        images = new Map(tiles.map((t) => [`${t.x},${t.y}`, t.image]));
        himawariTime = time.validtime;
      }
    } catch (error) {
      console.warn('⚠️ [AIRPORT_OBS] ひまわりの画像を取れませんでした（METAR だけ記録します）:', error.message);
    }

    const stations = metars.map((m) => {
      const point = { latitude: m.latitude, longitude: m.longitude };
      const cover = images ? cloudCover(point, images, m.tempC) : null;
      const { obsTimeMs, ...rest } = m;
      return {
        ...rest,
        obsTime: new Date(obsTimeMs).toISOString(),
        sunAltitudeDeg: round(sunAltitudeDeg(new Date(obsTimeMs), m.latitude, m.longitude)),
        ir: cover ? { fractions: cover.fractions, medianDeltaC: cover.medianDeltaC, pixels: cover.pixels } : null,
      };
    });

    const id = bucketId(latestMs);
    const retentionMs = VALIDATION.RETENTION_DAYS * 24 * 60 * 60 * 1000;
    const coldDeltas = [CLOUD_COVER.COLD_DELTA_C, ...CLOUD_COVER.EXTRA_DELTAS_C];
    await this.firestore.collection(VALIDATION.COLLECTION).doc(id).set({
      observedAt: admin.firestore.Timestamp.fromDate(new Date(latestMs)),
      recordedAt: admin.firestore.Timestamp.fromDate(now),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + retentionMs)),
      himawariTime,
      // 雲の量を測った条件（調整したら変わるので、記録に残す）
      cover: { radiusPixels: CLOUD_COVER.RADIUS_PIXELS, coldDeltasC: coldDeltas },
      stations,
    });
    const withInfrared = stations.filter((s) => s.ir).length;
    console.log(`✈️ [AIRPORT_OBS] ${id}: 空港${stations.length}か所、雲の量つき${withInfrared}か所、` +
      `積乱雲・雄大積雲の記号 ${stations.filter((s) => s.hasConvective).length}か所`);
    return { id, airports: stations.length, withInfrared };
  }
}

module.exports = { AirportObserver, summarizeMetar, evaluateAgreement, bucketId };
