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

function serviceWith(jma, firestore) {
  const service = new NowcastService(jma);
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
  await serviceWith(jma1, firestore).updateClouds();
  // z4 で当たりを付けた z6 のタイルは1枚だけ
  assert.deepEqual(jma1.requests.filter((r) => r.zoom === 6), [{ element: 'hrpns', zoom: 6, count: 1 }]);

  let clouds = firestore.clouds();
  assert.equal(clouds.length, 1);
  assert.equal(clouds[0].status, 'active');
  assert.equal(clouds[0].isVisible, true);
  assert.equal(clouds[0].maxRainMmPerHour, 30);
  assert.equal(clouds[0].pixelCount, 3);

  const status = (await firestore.doc('system/jma_nowcast').get()).data();
  assert.equal(status.lastRainTime, t1);
  assert.equal(status.consecutiveFailures, 0);
  assert.equal(status.visibleCloudCount, 1);

  // 同じ解析時刻なら何もしない
  const jmaSame = fakeJma(t1);
  await serviceWith(jmaSame, firestore).updateClouds();
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
