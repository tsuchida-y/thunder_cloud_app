const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  AirportObserver, summarizeMetar, evaluateAgreement, bucketId,
} = require('../modules/validation/airport_observer');
const FakeFirestore = require('./helpers/fake_firestore');
const { GRAY_CLEAR, GRAY_CLOUD, infraredAround } = require('./helpers/infrared');
const admin = require('firebase-admin');

const obsSeconds = Date.parse('2026-11-04T23:30:00Z') / 1000; // 日本時間 11/05 08:30
const now = new Date('2026-11-04T23:37:00Z');

const metar = (extra = {}) => ({
  icaoId: 'RJSI', name: 'Hanamaki', lat: 39.43, lon: 141.13, temp: 8, obsTime: obsSeconds, visib: '6+',
  clouds: [{ cover: 'FEW', base: 100 }, { cover: 'BKN', base: 1500 }],
  rawOb: 'METAR RJSI 042330Z VRB01KT 9999 FEW001 BKN015 08/08 Q1022', ...extra,
});

test('METAR を記録する形にする（曇り・ほぼ晴れ・積乱雲の記号）', () => {
  const cloudy = summarizeMetar(metar());
  assert.equal(cloudy.icao, 'RJSI');
  assert.equal(cloudy.covered, true);
  assert.equal(cloudy.clearish, false);
  assert.equal(cloudy.lowestBaseFt, 100);
  assert.equal(cloudy.hasConvective, false);

  const clear = summarizeMetar(metar({ clouds: [{ cover: 'FEW', base: 4000 }], rawOb: 'METAR RJSI 042330Z FEW040' }));
  assert.equal(clear.covered, false);
  assert.equal(clear.clearish, true);
  // SCT だけは、曇りでも晴れでもない
  const scattered = summarizeMetar(metar({ clouds: [{ cover: 'SCT', base: 3000 }], rawOb: 'METAR RJSI SCT030' }));
  assert.equal(scattered.covered, false);
  assert.equal(scattered.clearish, false);

  const tcu = summarizeMetar(metar({ clouds: [{ cover: 'BKN', base: 3000 }], rawOb: 'METAR RJSI 081230Z 20010KT 9999 FEW020 BKN030TCU 30/24' }));
  assert.equal(tcu.hasConvective, true);
  assert.deepEqual(tcu.convective, [{ type: 'TCU', baseFt: 3000 }]);

  // 日本の空港でない、位置や気温がない
  assert.equal(summarizeMetar(metar({ icaoId: 'KSFO' })), null);
  assert.equal(summarizeMetar(metar({ temp: undefined })), null);
  assert.equal(summarizeMetar(metar({ lat: undefined })), null);
});

test('30分ごとの枠の名前（日本時間）', () => {
  assert.equal(bucketId(Date.parse('2026-11-04T23:30:00Z')), '202611050830');
  assert.equal(bucketId(Date.parse('2026-11-04T23:59:00Z')), '202611050830');
  assert.equal(bucketId(Date.parse('2026-11-05T00:00:00Z')), '202611050900');
});

test('空港の観測と赤外の雲の量が合っているかを数える', () => {
  const station = (flags, fraction) => ({ ...flags, ir: { fractions: { 8: fraction } } });
  const stations = [
    station({ covered: true }, 1), station({ covered: true }, 0.9), station({ covered: true }, 0.3),
    station({ clearish: true }, 0.1), station({ clearish: true }, 0.85),
    { covered: true, ir: null },
  ];
  assert.deepEqual(evaluateAgreement(stations, { delta: 8, fraction: 0.8 }),
    { coveredTotal: 3, coveredFound: 2, clearTotal: 2, clearWrong: 1 });
  assert.deepEqual(evaluateAgreement(stations, { delta: 8, fraction: 0.5 }),
    { coveredTotal: 3, coveredFound: 2, clearTotal: 2, clearWrong: 1 });
});

function setup({ metars, images }) {
  const firestore = new FakeFirestore();
  const http = { async get() { return { data: metars }; } };
  const himawari = {
    async getTimeAtOrBefore() { return images ? { basetime: '20261104233000', validtime: '20261104233000' } : null; },
    async getInfraredTiles() { return images ? [...images.entries()].map(([key, image]) => {
      const [x, y] = key.split(',').map(Number);
      return { x, y, image };
    }) : []; },
  };
  const observer = new AirportObserver({ http, himawari });
  Object.defineProperty(observer, 'firestore', { get: () => firestore });
  return { firestore, observer };
}

test('空港の観測と雲の量を、30分に1件まとめて記録する', async () => {
  const point = { latitude: 39.43, longitude: 141.13 };
  const { firestore, observer } = setup({
    metars: [
      metar(),
      metar({ icaoId: 'RJSS', lat: 38.14, lon: 140.92, clouds: [{ cover: 'FEW', base: 4000 }], rawOb: 'METAR RJSS FEW040' }),
      // 画像を用意していない遠い空港（那覇）は、雲の量が付かない
      metar({ icaoId: 'ROAH', lat: 26.2, lon: 127.65, clouds: [{ cover: 'SCT', base: 2000 }], rawOb: 'METAR ROAH SCT020' }),
      // 同じ空港の古い観測は使わない
      metar({ obsTime: obsSeconds - 1800 }),
      // 古すぎる空港は除く（3時間前、40分前。観測ごとに1回だけ記録するため、直近25分より古い観測は使わない）
      metar({ icaoId: 'RJOT', obsTime: obsSeconds - 3 * 3600 }),
      metar({ icaoId: 'RJTT', obsTime: obsSeconds - 40 * 60 }),
      { icaoId: 'KSFO', lat: 37, lon: -122, temp: 12, obsTime: obsSeconds },
    ],
    images: infraredAround(point, () => GRAY_CLOUD),
  });
  const result = await observer.run(now);
  assert.deepEqual(result, { id: '202611050830', airports: 3, withInfrared: 2 });

  const doc = firestore.docs.get('sky_validation/202611050830');
  assert.equal(doc.himawariTime, '20261104233000');
  assert.equal(doc.stations.length, 3);
  const hanamaki = doc.stations.find((s) => s.icao === 'RJSI');
  assert.equal(hanamaki.covered, true);
  assert.equal(hanamaki.ir.fractions['8'], 1);
  assert.equal(hanamaki.ir.pixels > 100, true);
  assert.equal(hanamaki.obsTime, '2026-11-04T23:30:00.000Z');
  assert.ok(typeof hanamaki.sunAltitudeDeg === 'number');
  assert.ok(doc.expiresAt && doc.recordedAt && doc.observedAt);
  // 同じタイルに入る仙台には付く。画像を用意していない那覇には付かない
  assert.equal(doc.stations.find((s) => s.icao === 'RJSS').ir.fractions['8'], 1);
  assert.equal(doc.stations.find((s) => s.icao === 'ROAH').ir, null);

  // 同じ枠をもう一度記録しても、1件のまま
  await observer.run(new Date(now.getTime() + 60000));
  assert.equal([...firestore.docs.keys()].filter((k) => k.startsWith('sky_validation/')).length, 1);
});

test('ひまわりが取れなくても、METAR だけ記録する。METAR が空なら何も書かない', async () => {
  const a = setup({ metars: [metar()], images: null });
  const result = await a.observer.run(now);
  assert.equal(result.withInfrared, 0);
  assert.equal(a.firestore.docs.get('sky_validation/202611050830').stations[0].ir, null);

  const b = setup({ metars: [], images: null });
  assert.equal(await b.observer.run(now), null);
  assert.equal([...b.firestore.docs.keys()].length, 0);

  const broken = new AirportObserver({ http: { async get() { return { data: 'error' }; } } });
  await assert.rejects(() => broken.run(now), /形が想定と違います/);
});

test('保存期間が過ぎた空港の観測の記録だけを消す', async () => {
  const CleanupService = require('../modules/cleanup/cleanup_service');
  const firestore = new FakeFirestore();
  const service = new CleanupService();
  Object.defineProperty(service, 'firestore', { get: () => firestore });
  const ts = (iso) => admin.firestore.Timestamp.fromDate(new Date(iso));
  firestore.docs.set('sky_validation/old', { expiresAt: ts('2026-10-01T00:00:00Z') });
  firestore.docs.set('sky_validation/new', { expiresAt: ts('2027-10-01T00:00:00Z') });
  assert.equal(await service.cleanupOldSkyValidation(new Date('2026-11-05T00:00:00Z')), 1);
  assert.equal(firestore.docs.has('sky_validation/old'), false);
  assert.equal(firestore.docs.has('sky_validation/new'), true);
});
