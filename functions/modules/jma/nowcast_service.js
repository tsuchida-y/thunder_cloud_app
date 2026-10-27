/**
 * 気象庁ナウキャストから「いまある雲の一覧」を作るサービス
 *
 * 5分ごとに全ユーザー分をまとめて1回だけ実行する（気象庁へのアクセスは利用者が増えても増えない）。
 *
 * 処理の流れ:
 * 1. 最新の解析時刻を調べる。前回と同じなら何もしない
 * 2. z4 のタイル（日本全体で数枚）で、強い雨か雷がありそうな場所に当たりを付ける
 * 3. 当たりの場所だけ z6 のタイル（1ピクセル約2km）を取り、強い雨か雷のある塊を取り出す
 * 3'. ひまわりの赤外画像で塊のてっぺんの温度を調べ、背の高い（冷たい）塊だけを入道雲とする。
 *     アメダスの地上の気温との差から、てっぺんの高さも見積もる。
 *     ひまわりかアメダスが取れないときは、ナウキャストだけで今までどおり続ける（入道雲を知らせられなくなるよりよいため）
 * 4. 前回までの雲と結びつけて Firestore の clouds に保存する
 * 5. 結果と失敗の回数を system/jma_nowcast に残す（続けて失敗したらエラーのログを出す）
 * 6. 見張りで使うもの（雨を調べる RainLookup と、アメダスの観測値）を返す
 * 7. アメダスが新しい時刻になったら、アプリのホームの「いまの空」用に system/amedas_latest へ置く
 */

const admin = require('firebase-admin');
const JmaClient = require('./jma_client');
const { rainFromColor, thunderFromColor, collectPixels, extractClusters } = require('./nowcast_parser');
const { trackClouds } = require('./cloud_tracker');
const { RainLookup } = require('./rain_lookup');
const HimawariClient = require('./himawari_client');
const AmedasClient = require('./amedas_client');
const { coldestTopTempC, topHeightKm, isTallEnough, surfaceTempNear } = require('./sky_observations');
const { JMA_NOWCAST, HIMAWARI, AMEDAS } = require('../../constants');

class NowcastService {
  constructor(jmaClient = new JmaClient(), { himawari = new HimawariClient(), amedas = new AmedasClient() } = {}) {
    this.jma = jmaClient;
    this.himawari = himawari;
    this.amedas = amedas;
  }

  get firestore() {
    return admin.firestore();
  }

  /**
   * 気象庁のデータから雲の塊を取り出す（Firestore には書かない）
   *
   * @returns {Promise<{times:{rain:string,thunder:string|null}, clusters:Array, requestCount:number,
   *   rainLookup:RainLookup, lowClusterCount:number, amedasStations:Array|null,
   *   errors:{himawari:Error|null, amedas:Error|null}}>}
   *   clusters は背の高い塊だけ。lowClusterCount は背が低いので外した塊の数
   */
  async detectClusters(times = null) {
    const latest = times || await this.jma.getLatestAnalysisTimes();
    if (!latest.rain) {
      throw new Error('気象庁の時刻一覧に降水の解析値がありません');
    }
    let requestCount = times ? 0 : 2;

    // 1. z4 で当たりを付ける
    const coarseTiles = [];
    for (let x = JMA_NOWCAST.COARSE_TILE_X[0]; x <= JMA_NOWCAST.COARSE_TILE_X[1]; x++) {
      for (let y = JMA_NOWCAST.COARSE_TILE_Y[0]; y <= JMA_NOWCAST.COARSE_TILE_Y[1]; y++) {
        coarseTiles.push({ x, y });
      }
    }
    const coarseRain = await this.jma.getAnalysisTiles(
      latest.rain, JMA_NOWCAST.ELEMENT_RAIN, JMA_NOWCAST.COARSE_ZOOM, coarseTiles);
    requestCount += coarseTiles.length;

    const isCoarseRain = (mm) => mm !== null && mm >= JMA_NOWCAST.COARSE_MIN_RAIN_MM_PER_HOUR;
    const isRain = (mm) => mm !== null && mm >= JMA_NOWCAST.MIN_RAIN_MM_PER_HOUR;
    const isThunder = (level) => level >= JMA_NOWCAST.MIN_THUNDER_LEVEL;

    const detailTileKeys = new Set();
    const addDetailTiles = (pixels) => {
      const scale = 2 ** (JMA_NOWCAST.DETAIL_ZOOM - JMA_NOWCAST.COARSE_ZOOM);
      for (const p of pixels) {
        detailTileKeys.add(`${Math.floor((p.x * scale) / JMA_NOWCAST.TILE_SIZE)},` +
          `${Math.floor((p.y * scale) / JMA_NOWCAST.TILE_SIZE)}`);
      }
    };
    for (const t of coarseRain) {
      addDetailTiles(collectPixels(t.png, t.x, t.y, rainFromColor, isCoarseRain));
    }

    let coarseThunder = [];
    if (latest.thunder) {
      coarseThunder = await this.jma.getAnalysisTiles(
        latest.thunder, JMA_NOWCAST.ELEMENT_THUNDER, JMA_NOWCAST.COARSE_ZOOM, coarseTiles);
      requestCount += coarseTiles.length;
      for (const t of coarseThunder) {
        addDetailTiles(collectPixels(t.png, t.x, t.y, thunderFromColor, isThunder));
      }
    } else {
      console.warn('⚠️ [JMA_NOWCAST] 雷の解析値が見つからないため、雨だけで判定します');
    }

    // 2. 当たりの場所だけ z6 で調べる
    const detailTiles = [...detailTileKeys].map((key) => {
      const [x, y] = key.split(',').map(Number);
      return { x, y };
    });
    const rainPixels = [];
    const thunderPixels = [];
    let rainTiles = [];
    if (detailTiles.length > 0) {
      rainTiles = await this.jma.getAnalysisTiles(
        latest.rain, JMA_NOWCAST.ELEMENT_RAIN, JMA_NOWCAST.DETAIL_ZOOM, detailTiles);
      requestCount += detailTiles.length;
      for (const t of rainTiles) {
        rainPixels.push(...collectPixels(t.png, t.x, t.y, rainFromColor, isRain));
      }
      if (latest.thunder) {
        const thunderTiles = await this.jma.getAnalysisTiles(
          latest.thunder, JMA_NOWCAST.ELEMENT_THUNDER, JMA_NOWCAST.DETAIL_ZOOM, detailTiles);
        requestCount += detailTiles.length;
        for (const t of thunderTiles) {
          thunderPixels.push(...collectPixels(t.png, t.x, t.y, thunderFromColor, isThunder));
        }
      }
    }

    const allClusters = extractClusters(rainPixels, thunderPixels, JMA_NOWCAST.DETAIL_ZOOM);
    const rainLookup = new RainLookup(this.jma, latest.rain, coarseRain, rainTiles);
    const sky = await this._observeSky(latest.rain, allClusters);
    return {
      times: latest,
      clusters: sky.clusters,
      lowClusterCount: allClusters.length - sky.clusters.length,
      requestCount: requestCount + sky.requestCount,
      rainLookup,
      amedasStations: sky.amedasStations,
      amedasObservedAt: sky.amedasObservedAt,
      errors: sky.errors,
    };
  }

  /**
   * ひまわりで塊のてっぺんの温度を調べ、背の高い塊だけに高さを付けて返す
   */
  async _observeSky(rainTime, clusters) {
    const errors = { himawari: null, amedas: null };
    let requestCount = 0;

    let amedasStations = null;
    let amedasObservedAt = null;
    try {
      const latest = await this.amedas.getLatest();
      amedasStations = latest.stations;
      amedasObservedAt = latest.observedAt;
      requestCount += 2;
    } catch (error) {
      errors.amedas = error;
    }
    if (clusters.length === 0) return { clusters, amedasStations, amedasObservedAt, errors, requestCount };

    const images = new Map();
    try {
      const time = await this.himawari.getTimeAtOrBefore(rainTime);
      requestCount += 1;
      if (!time) throw new Error(`ひまわりの画像に ${rainTime} より前の時刻がありません`);
      const lagMs = JmaClient.parseTime(rainTime).getTime() - JmaClient.parseTime(time.validtime).getTime();
      if (lagMs > JMA_NOWCAST.STALE_DATA_MS) {
        throw new Error(`ひまわりの画像が更新されていません（最新 ${time.validtime}）`);
      }
      // 塊を囲む四角（まわりも含む）にかかるタイル
      const size = JMA_NOWCAST.TILE_SIZE;
      const margin = HIMAWARI.SEARCH_MARGIN_PIXELS;
      const keys = new Set();
      for (const { bounds } of clusters) {
        for (let x = Math.floor((bounds.minX - margin) / size); x <= Math.floor((bounds.maxX + margin) / size); x++) {
          for (let y = Math.floor((bounds.minY - margin) / size); y <= Math.floor((bounds.maxY + margin) / size); y++) {
            keys.add(`${x},${y}`);
          }
        }
      }
      const tiles = [...keys].map((key) => {
        const [x, y] = key.split(',').map(Number);
        return { x, y };
      });
      for (const t of await this.himawari.getInfraredTiles(time, tiles)) images.set(`${t.x},${t.y}`, t.image);
      requestCount += tiles.length;
    } catch (error) {
      errors.himawari = error;
    }

    const result = [];
    for (const cluster of clusters) {
      const topTempC = images.size > 0 ? coldestTopTempC(cluster.bounds, images) : null;
      if (!isTallEnough(topTempC)) continue;
      result.push({
        ...cluster,
        topTempC,
        topHeightKm: topTempC === null ? null : topHeightKm(topTempC, surfaceTempNear(amedasStations, cluster)),
      });
    }
    return { clusters: result, amedasStations, amedasObservedAt, errors, requestCount };
  }

  /**
   * 5分ごとの本処理: 雲の一覧を更新する
   *
   * @returns {Promise<{rainLookup:RainLookup, amedasStations:Array|null}|null>}
   *   新しい解析値で雲の一覧を書き換えたら、見張りで使うもの。書き換えなかったら null
   */
  async updateClouds() {
    const statusRef = this.firestore.doc(JMA_NOWCAST.STATUS_DOC_PATH);
    const statusSnap = await statusRef.get();
    const status = statusSnap.exists ? statusSnap.data() : {};

    try {
      const times = await this.jma.getLatestAnalysisTimes();
      if (!times.rain) {
        throw new Error('気象庁の時刻一覧に降水の解析値がありません');
      }
      const observedAt = JmaClient.parseTime(times.rain);
      if (Date.now() - observedAt.getTime() > JMA_NOWCAST.STALE_DATA_MS) {
        throw new Error(`気象庁のデータが更新されていません（最新の解析時刻 ${times.rain}）`);
      }
      if (status.lastRainTime === times.rain) {
        console.log(`⏭️ [JMA_NOWCAST] 新しい解析値なし（${times.rain}）`);
        return null;
      }

      const detected = await this.detectClusters(times);
      const { clusters, requestCount, rainLookup, amedasStations } = detected;
      const result = await this._saveClouds(clusters, observedAt);
      const himawariFailures = this._countSubFailure('HIMAWARI', status.himawariFailures, detected.errors.himawari);
      const amedasFailures = this._countSubFailure('AMEDAS', status.amedasFailures, detected.errors.amedas);
      const amedasTime = detected.amedasObservedAt ? detected.amedasObservedAt.toISOString() : null;
      if (amedasTime && amedasTime !== status.lastAmedasTime) {
        await this._saveAmedasLatest(detected.amedasObservedAt, amedasStations);
      }

      await statusRef.set({
        lastRainTime: times.rain,
        lastThunderTime: times.thunder,
        observedAt: admin.firestore.Timestamp.fromDate(observedAt),
        lastSuccessAt: admin.firestore.FieldValue.serverTimestamp(),
        consecutiveFailures: 0,
        lastError: null,
        visibleCloudCount: clusters.length,
        lowCloudCount: detected.lowClusterCount,
        lastRequestCount: requestCount + 2,
        himawariFailures,
        amedasFailures,
        lastAmedasTime: amedasTime || status.lastAmedasTime || null,
      }, { merge: true });

      console.log(`✅ [JMA_NOWCAST] ${times.rain} の雲: ${clusters.length}個、背が低いので外した塊${detected.lowClusterCount}個 ` +
        `（続き${result.updated} 新規${result.created} 見えない${result.hidden} 終了${result.ended}、` +
        `気象庁へのリクエスト${requestCount + 2}回）`);
      return { rainLookup, amedasStations };
    } catch (error) {
      await this._recordFailure(statusRef, status, error);
      return null;
    }
  }

  async _saveClouds(clusters, observedAt) {
    const collection = this.firestore.collection(JMA_NOWCAST.CLOUDS_COLLECTION);
    const activeSnap = await collection.where('status', '==', 'active').get();
    const activeClouds = activeSnap.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        latitude: data.center.latitude,
        longitude: data.center.longitude,
        lastSeenAt: data.lastSeenAt.toDate(),
      };
    });

    const { updated, created, hidden, ended } = trackClouds(activeClouds, clusters, observedAt);
    const seenAt = admin.firestore.Timestamp.fromDate(observedAt);
    const now = admin.firestore.FieldValue.serverTimestamp();
    const fieldsOf = (cluster) => ({
      center: { latitude: cluster.latitude, longitude: cluster.longitude },
      maxRainMmPerHour: cluster.maxRainMmPerHour,
      maxThunderLevel: cluster.maxThunderLevel,
      areaKm2: Math.round(cluster.areaKm2 * 10) / 10,
      pixelCount: cluster.pixelCount,
      // ひまわりで見たてっぺんの温度（℃）と、見積もった高さ (km)。ひまわりが取れなかったときは null
      topTempC: typeof cluster.topTempC === 'number' ? Math.round(cluster.topTempC * 10) / 10 : null,
      topHeightKm: typeof cluster.topHeightKm === 'number' ? Math.round(cluster.topHeightKm * 10) / 10 : null,
      // 雲のふち。Firestore は配列の入れ子を持てないので {latitude, longitude} の並びにする
      edgePoints: (cluster.edgePoints || []).map((p) => ({
        latitude: Math.round(p.latitude * 1000) / 1000,
        longitude: Math.round(p.longitude * 1000) / 1000,
      })),
      lastSeenAt: seenAt,
      isVisible: true,
      updatedAt: now,
    });

    const writes = [
      ...updated.map((u) => (batch) => batch.update(collection.doc(u.id), fieldsOf(u.cluster))),
      ...created.map((c) => (batch) => batch.set(collection.doc(), {
        ...fieldsOf(c.cluster),
        firstSeenAt: seenAt,
        status: 'active',
      })),
      ...hidden.map((h) => (batch) => batch.update(collection.doc(h.id), { isVisible: false, updatedAt: now })),
      ...ended.map((e) => (batch) => batch.update(collection.doc(e.id), {
        isVisible: false,
        status: 'ended',
        updatedAt: now,
      })),
    ];
    // Firestore の1回のまとめ書きは500件まで
    for (let i = 0; i < writes.length; i += 450) {
      const batch = this.firestore.batch();
      writes.slice(i, i + 450).forEach((write) => write(batch));
      await batch.commit();
    }

    return { updated: updated.length, created: created.length, hidden: hidden.length, ended: ended.length };
  }

  /**
   * アプリのホームの「いまの空」用に、アメダスの最新の観測をまとめて1件に置く（10分ごと、約1,300地点で80KB ほど）
   *
   * 名前を短くして大きさを抑える: la 緯度、lo 経度、t 気温（℃）、s 前の1時間の日照（時間）、v 視程（m）
   */
  async _saveAmedasLatest(observedAt, stations) {
    const round = (value, digits) => (typeof value === 'number' ? Number(value.toFixed(digits)) : null);
    const compact = [];
    for (const s of stations || []) {
      const entry = { la: round(s.latitude, 3), lo: round(s.longitude, 3) };
      if (typeof s.tempC === 'number') entry.t = round(s.tempC, 1);
      if (typeof s.sun1h === 'number') entry.s = round(s.sun1h, 1);
      if (typeof s.visibilityM === 'number') entry.v = Math.round(s.visibilityM);
      if (entry.t !== undefined || entry.s !== undefined || entry.v !== undefined) compact.push(entry);
    }
    await this.firestore.doc(AMEDAS.LATEST_DOC_PATH).set({
      observedAt: admin.firestore.Timestamp.fromDate(observedAt),
      stations: compact,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  /**
   * ひまわり・アメダスの続けての失敗を数える。ナウキャストだけで続けられるので、失敗としては数えない。
   * 続けて失敗したらエラーのログを出す（Cloud Logging でこの文字列を条件にすれば、止まったことに気づける）
   */
  _countSubFailure(name, previous, error) {
    if (!error) return 0;
    const failures = (previous || 0) + 1;
    if (failures >= JMA_NOWCAST.FAILURE_ALERT_COUNT) {
      console.error(`🚨 [${name}_FAILING] ${name} の取得が${failures}回続けて失敗しています（ナウキャストだけで続けます）:`,
        error);
    } else {
      console.warn(`⚠️ [${name}] ${name} の取得に失敗しました（${failures}回目、ナウキャストだけで続けます）:`, error);
    }
    return failures;
  }

  async _recordFailure(statusRef, status, error) {
    const failures = (status.consecutiveFailures || 0) + 1;
    try {
      await statusRef.set({
        consecutiveFailures: failures,
        lastError: String(error && error.message ? error.message : error),
        lastFailureAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    } catch (saveError) {
      console.error('❌ [JMA_NOWCAST] 失敗の記録に失敗しました:', saveError);
    }

    if (failures >= JMA_NOWCAST.FAILURE_ALERT_COUNT) {
      // Cloud Logging でこの文字列を条件にした通知を作れば、止まったことに気づける
      console.error(`🚨 [JMA_NOWCAST_FAILING] 気象庁のデータ取得が${failures}回続けて失敗しています:`, error);
    } else {
      console.warn(`⚠️ [JMA_NOWCAST] 気象庁のデータ取得に失敗しました（${failures}回目）:`, error);
    }
  }
}

module.exports = NowcastService;
