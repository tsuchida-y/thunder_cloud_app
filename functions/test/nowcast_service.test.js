const { test } = require('node:test');
const assert = require('node:assert/strict');
const NowcastService = require('../modules/jma/nowcast_service');
const FakeFirestore = require('./helpers/fake_firestore');

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

const ORANGE = [255, 153, 0]; // 雨 30mm/h 以上

/**
 * 気象庁の代わり。z4 タイル (14,6) の (40,50) と、それに当たる z6 タイルに強い雨を置く。
 * offset で z6 の位置をずらし、雲が動いた様子を作る。
 */
function fakeJma(rainTime, offset = 0) {
  return {
    requests: [],
    async getLatestAnalysisTimes() {
      return { rain: rainTime, thunder: null };
    },
    async getAnalysisTiles(basetime, element, zoom, tiles) {
      this.requests.push({ element, zoom, count: tiles.length });
      return tiles.map((t) => {
        if (zoom === 4 && t.x === 14 && t.y === 6) return { ...t, png: png([[40, 50, ORANGE]]) };
        // z4 の (14*256+40, 6*256+50) は z6 のタイル (56, 24) の (160+α, 200+α)
        if (zoom === 6 && t.x === 56 && t.y === 24) {
          return { ...t, png: png([[160 + offset, 200], [161 + offset, 200], [161 + offset, 201]]
            .map(([x, y]) => [x, y, ORANGE])) };
        }
        return { ...t, png: png() };
      });
    },
  };
}

// ひまわりとアメダスの代わり。topGray で雲のてっぺんの明るさ（白いほど冷たい）を決める
function fakeSky({ topGray = 200, fail = false } = {}) {
  const image = { width: 256, height: 256, data: new Uint8Array(256 * 256 * 4).fill(topGray) };
  return {
    himawari: {
      async getTimeAtOrBefore(time) {
        if (fail) throw new Error('テスト用のひまわりの失敗');
        return { basetime: time, validtime: time };
      },
      async getInfraredTiles(time, tiles) {
        return tiles.map((t) => ({ ...t, image }));
      },
    },
    amedas: {
      async getLatest() {
        if (fail) throw new Error('テスト用のアメダスの失敗');
        return { observedAt: new Date(), stations: [] };
      },
    },
  };
}

function serviceWith(jma, firestore, sky = fakeSky()) {
  const service = new NowcastService(jma, sky);
  Object.defineProperty(service, 'firestore', { get: () => firestore });
  return service;
}

function jmaTime(date) {
  return date.toISOString().replace(/[-:T]/g, '').slice(0, 14);
}

test('雲の塊を見つけて clouds に保存し、次の回は同じ雲として続ける', async () => {
  const firestore = new FakeFirestore();
  const t1 = jmaTime(new Date(Date.now() - 5 * 60 * 1000));
  const t2 = jmaTime(new Date());

  const jma1 = fakeJma(t1);
  const result = await serviceWith(jma1, firestore).updateClouds();
  // 見張りで雨を調べる道具を返す
  assert.equal(typeof result.rainLookup.isRaining, 'function');
  // z4 で当たりを付けた z6 のタイルは1枚だけ
  assert.deepEqual(jma1.requests.filter((r) => r.zoom === 6), [{ element: 'hrpns', zoom: 6, count: 1 }]);

  let clouds = firestore.clouds();
  assert.equal(clouds.length, 1);
  assert.equal(clouds[0].status, 'active');
  assert.equal(clouds[0].isVisible, true);
  assert.equal(clouds[0].maxRainMmPerHour, 30);
  assert.equal(clouds[0].pixelCount, 3);
  // 3ピクセルの塊は全部がふち
  assert.equal(clouds[0].edgePoints.length, 3);

  const status = (await firestore.doc('system/jma_nowcast').get()).data();
  assert.equal(status.lastRainTime, t1);
  assert.equal(status.consecutiveFailures, 0);
  assert.equal(status.visibleCloudCount, 1);

  // 同じ解析時刻なら何もしない
  const jmaSame = fakeJma(t1);
  assert.equal(await serviceWith(jmaSame, firestore).updateClouds(), null);
  assert.equal(jmaSame.requests.length, 0);

  // 少し動いても（数km）同じ雲として続く
  await serviceWith(fakeJma(t2, 2), firestore).updateClouds();
  clouds = firestore.clouds();
  assert.equal(clouds.length, 1);
  assert.equal(clouds[0].firstSeenAt.toDate().getTime() < clouds[0].lastSeenAt.toDate().getTime(), true);
});

test('取得に続けて失敗したら回数を数え、成功したら0に戻す', async () => {
  const firestore = new FakeFirestore();
  const broken = { getLatestAnalysisTimes: async () => { throw new Error('テスト用の失敗'); } };
  const originalError = console.error;
  const originalWarn = console.warn;
  const errors = [];
  console.error = (...args) => errors.push(args.join(' '));
  console.warn = () => {};
  try {
    for (let i = 0; i < 3; i++) await serviceWith(broken, firestore).updateClouds();
  } finally {
    console.error = originalError;
    console.warn = originalWarn;
  }
  const status = (await firestore.doc('system/jma_nowcast').get()).data();
  assert.equal(status.consecutiveFailures, 3);
  assert.equal(status.lastError, 'テスト用の失敗');
  assert.equal(errors.length, 1);
  assert.match(errors[0], /JMA_NOWCAST_FAILING/);

  await serviceWith(fakeJma(jmaTime(new Date())), firestore).updateClouds();
  assert.equal((await firestore.doc('system/jma_nowcast').get()).data().consecutiveFailures, 0);
});

test('気象庁のデータが30分以上更新されていなければ失敗として数える', async () => {
  const firestore = new FakeFirestore();
  const old = jmaTime(new Date(Date.now() - 40 * 60 * 1000));
  const originalWarn = console.warn;
  console.warn = () => {};
  try {
    await serviceWith(fakeJma(old), firestore).updateClouds();
  } finally {
    console.warn = originalWarn;
  }
  const status = (await firestore.doc('system/jma_nowcast').get()).data();
  assert.equal(status.consecutiveFailures, 1);
  assert.match(status.lastError, /更新されていません/);
});

test('ひまわりで雲のてっぺんが冷たくない塊は入道雲にしない', async () => {
  const firestore = new FakeFirestore();
  // 明るさ 60 は約 +13℃（低い雲）
  await serviceWith(fakeJma(jmaTime(new Date())), firestore, fakeSky({ topGray: 60 })).updateClouds();
  assert.equal(firestore.clouds().length, 0);
  assert.equal((await firestore.doc('system/jma_nowcast').get()).data().lowCloudCount, 1);
});

test('てっぺんが冷たい塊は、温度と見積もった高さを保存する', async () => {
  const firestore = new FakeFirestore();
  // 明るさ 200 は約 -60℃。地上の気温が分からないので 25℃ として (25+60)/6.5 ≒ 13.1km
  await serviceWith(fakeJma(jmaTime(new Date())), firestore, fakeSky({ topGray: 200 })).updateClouds();
  const [cloud] = firestore.clouds();
  assert.equal(cloud.topTempC, -60.3);
  assert.equal(cloud.topHeightKm, 13.1);
});

test('ひまわりとアメダスが取れなくても、ナウキャストだけで続ける', async () => {
  const firestore = new FakeFirestore();
  const originalWarn = console.warn;
  console.warn = () => {};
  let result;
  try {
    result = await serviceWith(fakeJma(jmaTime(new Date())), firestore, fakeSky({ fail: true })).updateClouds();
  } finally {
    console.warn = originalWarn;
  }
  const [cloud] = firestore.clouds();
  assert.equal(cloud.topTempC, null);
  assert.equal(cloud.topHeightKm, null);
  assert.equal(result.amedasStations, null);
  const status = (await firestore.doc('system/jma_nowcast').get()).data();
  assert.equal(status.consecutiveFailures, 0);
  assert.equal(status.himawariFailures, 1);
  assert.equal(status.amedasFailures, 1);
});

test('アメダスが新しい時刻になったときだけ、ホームの「いまの空」用に観測を置く', async () => {
  const firestore = new FakeFirestore();
  const observedAt = new Date('2026-08-12T06:20:00Z');
  const sky = fakeSky();
  let calls = 0;
  sky.amedas.getLatest = async () => {
    calls++;
    return {
      observedAt,
      stations: [
        { latitude: 39.6833, longitude: 141.1667, tempC: 28.43, sun1h: 0.8, visibilityM: null },
        { latitude: 39.7, longitude: 141.2, tempC: null, sun1h: null, visibilityM: null },
      ],
    };
  };
  await serviceWith(fakeJma(jmaTime(new Date(Date.now() - 5 * 60 * 1000))), firestore, sky).updateClouds();
  const doc = (await firestore.doc('system/amedas_latest').get()).data();
  assert.equal(doc.observedAt.toDate().getTime(), observedAt.getTime());
  // 値のない地点は置かない。数字は丸める
  assert.deepEqual(doc.stations, [{ la: 39.683, lo: 141.167, t: 28.4, s: 0.8 }]);

  // 同じ時刻なら書き直さない
  firestore.docs.delete('system/amedas_latest');
  await serviceWith(fakeJma(jmaTime(new Date())), firestore, sky).updateClouds();
  assert.equal(calls, 2);
  assert.equal(firestore.docs.has('system/amedas_latest'), false);
});
