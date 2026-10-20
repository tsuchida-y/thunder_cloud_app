/**
 * 気象庁ナウキャストから「いまある雲の一覧」を作るサービス
 *
 * 5分ごとに全ユーザー分をまとめて1回だけ実行する（気象庁へのアクセスは利用者が増えても増えない）。
 *
 * 処理の流れ:
 * 1. 最新の解析時刻を調べる。前回と同じなら何もしない
 * 2. z4 のタイル（日本全体で数枚）で、強い雨か雷がありそうな場所に当たりを付ける
 * 3. 当たりの場所だけ z6 のタイル（1ピクセル約2km）を取り、強い雨か雷のある塊を取り出す
 * 4. 前回までの雲と結びつけて Firestore の clouds に保存する
 * 5. 結果と失敗の回数を system/jma_nowcast に残す（続けて失敗したらエラーのログを出す）
 */

const admin = require('firebase-admin');
const JmaClient = require('./jma_client');
const { rainFromColor, thunderFromColor, collectPixels, extractClusters } = require('./nowcast_parser');
const { trackClouds } = require('./cloud_tracker');
const { JMA_NOWCAST } = require('../../constants');

class NowcastService {
  constructor(jmaClient = new JmaClient()) {
    this.jma = jmaClient;
  }

  get firestore() {
    return admin.firestore();
  }

  /**
   * 気象庁のデータから雲の塊を取り出す（Firestore には書かない）
   *
   * @returns {Promise<{times:{rain:string,thunder:string|null}, clusters:Array, requestCount:number}>}
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
    if (detailTiles.length > 0) {
      const rainTiles = await this.jma.getAnalysisTiles(
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

    const clusters = extractClusters(rainPixels, thunderPixels, JMA_NOWCAST.DETAIL_ZOOM);
    return { times: latest, clusters, requestCount };
  }

  /**
   * 5分ごとの本処理: 雲の一覧を更新する
   *
   * @returns {Promise<boolean>} 新しい解析値で雲の一覧を書き換えたら true
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
        return false;
      }

      const { clusters, requestCount } = await this.detectClusters(times);
      const result = await this._saveClouds(clusters, observedAt);

      await statusRef.set({
        lastRainTime: times.rain,
        lastThunderTime: times.thunder,
        observedAt: admin.firestore.Timestamp.fromDate(observedAt),
        lastSuccessAt: admin.firestore.FieldValue.serverTimestamp(),
        consecutiveFailures: 0,
        lastError: null,
        visibleCloudCount: clusters.length,
        lastRequestCount: requestCount + 2,
      }, { merge: true });

      console.log(`✅ [JMA_NOWCAST] ${times.rain} の雲: ${clusters.length}個 ` +
        `（続き${result.updated} 新規${result.created} 見えない${result.hidden} 終了${result.ended}、` +
        `気象庁へのリクエスト${requestCount + 2}回）`);
      return true;
    } catch (error) {
      await this._recordFailure(statusRef, status, error);
      return false;
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
