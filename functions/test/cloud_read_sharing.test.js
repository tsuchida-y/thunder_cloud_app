const { test } = require('node:test');
const assert = require('node:assert/strict');
const NowcastService = require('../modules/jma/nowcast_service');
const { CloudWatchService } = require('../modules/watch/cloud_watch_service');
const FakeFirestore = require('./helpers/fake_firestore');

// 費用を減らすための変更（2026-11-25）のテスト:
// 5分ごとの処理で、雲の一覧を書いた直後に「見えている雲」をもう一度読まずに済ませる。
// 読み直した結果と同じになること、すでに見えなくした雲を書き直さないことを確かめる。

// 1枚 256×256 の PNG を作り、指定のピクセルに色を塗る
function png(paint = []) {
  const data = Buffer.alloc(256 * 256 * 4);
  for (const [x, y, rgb] of paint) {
    const i = (y * 256 + x) * 4;
    data[i] = rgb[0];
    data[i + 1] = rgb[1];
    data[i + 2] = rgb[2];
    data[i + 3] = 255;
  }
  return { width: 256, height: 256, data };
}

const ORANGE = [255, 153, 0];

/** 気象庁の代わり。withCloud が false なら、雲が1つもない */
function jmaAt(rainTime, { withCloud = true, offset = 0 } = {}) {
  return {
    async getLatestAnalysisTimes() {
      return { rain: rainTime, thunder: null };
    },
    async getAnalysisTiles(basetime, element, zoom, tiles) {
      return tiles.map((t) => {
        if (withCloud && zoom === 4 && t.x === 14 && t.y === 6) return { ...t, png: png([[40, 50, ORANGE]]) };
        if (withCloud && zoom === 6 && t.x === 56 && t.y === 24) {
          return { ...t, png: png([[160 + offset, 200], [161 + offset, 200], [161 + offset, 201]].map(([x, y]) => [x, y, ORANGE])) };
        }
        return { ...t, png: png() };
      });
    },
  };
}

function fakeSky() {
  const image = { width: 256, height: 256, data: new Uint8Array(256 * 256 * 4).fill(200) };
  return {
    himawari: {
      async getTimeAtOrBefore(time) {
        return { basetime: time, validtime: time };
      },
      async getInfraredTiles(time, tiles) {
        return tiles.map((t) => ({ ...t, image }));
      },
    },
    amedas: {
      async getLatest() {
        return { observedAt: new Date(), stations: [] };
      },
    },
  };
}

function serviceWith(jma, firestore) {
  const service = new NowcastService(jma, fakeSky());
  Object.defineProperty(service, 'firestore', { get: () => firestore });
  return service;
}

const jmaTime = (minutesAgo) => new Date(Date.now() - minutesAgo * 60 * 1000).toISOString().replace(/[-:T]/g, '').slice(0, 14);

// 通知の判定が雲の記録から取り出す項目
const watchFields = (c) => ({
  id: c.id,
  center: c.center,
  edgePoints: c.edgePoints,
  topHeightKm: c.topHeightKm,
  topTempC: c.topTempC,
  areaKm2: c.areaKm2,
  pixelCount: c.pixelCount,
  maxRainMmPerHour: c.maxRainMmPerHour,
  maxThunderLevel: c.maxThunderLevel,
  isVisible: c.isVisible,
});
const byId = (a, b) => a.id.localeCompare(b.id);

test('書いた直後の「見えている雲」は、Firestore から読み直した見えている雲と同じ', async () => {
  const firestore = new FakeFirestore();
  const readBack = () => [...firestore.docs.entries()]
    .filter(([path, c]) => path.startsWith('clouds/') && c.status === 'active' && c.isVisible)
    .map(([path, c]) => watchFields({ id: path.split('/')[1], ...c }))
    .sort(byId);

  // 新しい雲
  const first = await serviceWith(jmaAt(jmaTime(10)), firestore).updateClouds();
  assert.equal(first.visibleClouds.length, 1);
  assert.deepEqual(first.visibleClouds.map(watchFields).sort(byId), readBack());

  // 動いても続く雲（同じ id のまま、動いた先の中身になる）
  const second = await serviceWith(jmaAt(jmaTime(5), { offset: 2 }), firestore).updateClouds();
  assert.equal(second.visibleClouds.length, 1);
  assert.equal(second.visibleClouds[0].id, first.visibleClouds[0].id);
  assert.deepEqual(second.visibleClouds.map(watchFields).sort(byId), readBack());

  // 雲がなくなったら、見えている雲は空
  const third = await serviceWith(jmaAt(jmaTime(0), { withCloud: false }), firestore).updateClouds();
  assert.deepEqual(third.visibleClouds, []);
  assert.deepEqual(readBack(), []);
});

test('すでに見えなくした雲は、次の回で書き直さない（書き直しても変わるのは updatedAt だけ）', async () => {
  const firestore = new FakeFirestore();
  await serviceWith(jmaAt(jmaTime(10)), firestore).updateClouds();
  const path = [...firestore.docs.keys()].find((p) => p.startsWith('clouds/'));

  // 雲が消えた最初の回: 見えなくする
  await serviceWith(jmaAt(jmaTime(5), { withCloud: false }), firestore).updateClouds();
  const hidden = firestore.docs.get(path);
  assert.equal(hidden.isVisible, false);
  assert.equal(hidden.status, 'active');

  // 続けて雲がなかった回: 記録を作り直していない（同じ記録のまま）
  await serviceWith(jmaAt(jmaTime(0), { withCloud: false }), firestore).updateClouds();
  assert.equal(firestore.docs.get(path), hidden);
});

// ---- CloudWatchService.run ----

const home = { latitude: 39.735, longitude: 141.077 };
const nearCloud = { center: { latitude: 39.576, longitude: 141.285 } };
const now = new Date('2026-08-12T15:24:00+09:00');

function watchSetup({ clouds = {} } = {}) {
  const firestore = new FakeFirestore();
  for (const [id, cloud] of Object.entries(clouds)) {
    firestore.docs.set(`clouds/${id}`, { status: 'active', isVisible: true, ...cloud });
  }
  firestore.docs.set('members/u1', { fcmToken: 'token-a', location: home, settings: {} });
  const sent = [];
  const notifications = {
    async sendCloudNotification(token, message, data, cloudId) {
      sent.push({ token, cloudId });
      return { ok: true };
    },
  };
  const service = new CloudWatchService(notifications);
  Object.defineProperty(service, 'firestore', { get: () => firestore });
  return { service, sent };
}

test('見えている雲が渡されたら、雲の一覧を読み直さずに、その雲で通知する', async () => {
  // Firestore には雲がない。渡された雲だけで判定する
  const { service, sent } = watchSetup({ clouds: {} });
  const summary = await service.run(now, { visibleClouds: [{ id: 'c9', ...nearCloud, isVisible: true }] });

  assert.equal(summary.sent, 1);
  assert.equal(sent[0].cloudId, 'c9');
});

test('見えている雲が渡されたら、Firestore に残っている雲は見ない', async () => {
  // Firestore には見えている雲があるが、渡された一覧は空（見えなくなったばかり）
  const { service, sent } = watchSetup({ clouds: { c1: nearCloud } });
  const summary = await service.run(now, { visibleClouds: [] });

  assert.equal(summary.sent, 0);
  assert.equal(sent.length, 0);
});

test('見えている雲が渡されなければ、今までどおり Firestore から読む', async () => {
  const { service, sent } = watchSetup({ clouds: { c1: nearCloud } });
  const summary = await service.run(now);

  assert.equal(summary.sent, 1);
  assert.equal(sent[0].cloudId, 'c1');
});
